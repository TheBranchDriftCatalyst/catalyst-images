"""FastAPI shim — translates OpenAI-compatible image_generation requests
into ComfyUI workflow submissions and back.

Surface (subset of the OpenAI API + LoRA extensions):

  POST /v1/images/generations
       {model, prompt, n, size, response_format, [seed], [guidance], [loras]}
       -> {created, data: [{b64_json | url}]}
       loras: optional [{name, strength_model?, strength_clip?}] — only
         honoured when the pipeline declares lora_injection in its _meta.

  GET  /v1/models
       -> {data: [{id, object: "model", owned_by, description,
                   supports_loras}]}

  GET  /v1/loras
       -> {data: [{name, size_bytes}]}  # scans LORAS_DIR for *.safetensors

  GET  /healthz
       -> {ok, comfyui_reachable, pipelines: [...]}

The shim is intentionally thin: every concern that isn't the OpenAI shape
contract lives in pipelines.py / comfyui_client.py. Friendly LoRA names /
"when to use" copy lives in models.yaml — the operator UI joins on `name`.
"""
from __future__ import annotations

import asyncio
import base64
import time
from typing import Annotated, Literal

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from .comfyui_client import ComfyClient, ComfyError
from .config import CONFIG
from .pipelines import LoraRef, Pipeline, PipelineError, load_all
from . import registry


PIPELINES: dict[str, Pipeline] = {}


def _load_pipelines() -> None:
    global PIPELINES
    PIPELINES = load_all(CONFIG.pipelines_dir)


_load_pipelines()


app = FastAPI(
    title="comfyui-shim",
    version="0.1.0",
    description="OpenAI-compatible image_generation surface in front of ComfyUI",
)


# --- Request / response models -------------------------------------------


class LoraRequest(BaseModel):
    """One LoRA in a render-time stack — mirrored to ``pipelines.LoraRef``."""
    name: str = Field(..., min_length=1, description="LoRA filename in LORAS_DIR")
    strength_model: float = Field(1.0, ge=-3.0, le=3.0)
    strength_clip: float = Field(1.0, ge=-3.0, le=3.0)


class ImageRequest(BaseModel):
    model: str = Field(..., description="Pipeline name, e.g. 'flux-dev-pro'")
    prompt: str = Field(..., min_length=1, max_length=4000)
    n: int = Field(1, ge=1, le=4)
    size: str = Field("1024x1024", pattern=r"^\d{3,4}x\d{3,4}$")
    response_format: Literal["b64_json", "url"] = "b64_json"
    seed: int | None = Field(None, ge=0, le=2**32 - 1)
    guidance: float | None = Field(None, ge=0.0, le=10.0)
    loras: list[LoraRequest] | None = Field(
        None,
        description=(
            "Optional LoRA stack. Only honoured when the target pipeline "
            "declares _meta.lora_injection."
        ),
        max_length=8,
    )


class ImageData(BaseModel):
    b64_json: str | None = None
    url: str | None = None


class ImageResponse(BaseModel):
    created: int
    data: list[ImageData]


class ModelEntry(BaseModel):
    id: str
    object: Literal["model"] = "model"
    created: int
    owned_by: str = "mac-sdlc-node-comfyui"
    description: str | None = None
    supports_loras: bool = False
    # Joined from models.yaml — empty strings when no entry matches.
    friendly_name: str = ""
    excels_at: str = ""


class ModelList(BaseModel):
    object: Literal["list"] = "list"
    data: list[ModelEntry]


class LoraEntry(BaseModel):
    name: str
    size_bytes: int
    # Joined from models.yaml — empty / defaults when no entry matches.
    friendly_name: str = ""
    when_to_use: str = ""
    recommended_strength: float = 1.0
    trigger_words: list[str] = Field(default_factory=list)
    compatible_with: list[str] = Field(default_factory=list)


class LoraList(BaseModel):
    object: Literal["list"] = "list"
    data: list[LoraEntry]


# --- Auth ---------------------------------------------------------------


def _require_key(authorization: Annotated[str | None, Header()] = None) -> None:
    if not CONFIG.api_key:
        return  # auth disabled
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    if authorization.removeprefix("Bearer ").strip() != CONFIG.api_key:
        raise HTTPException(status_code=401, detail="invalid api key")


# --- Routes -------------------------------------------------------------


@app.get("/healthz")
async def healthz() -> dict[str, object]:
    client = ComfyClient(CONFIG.comfyui_base, timeout=5.0)
    return {
        "ok": True,
        "comfyui_reachable": await client.health(),
        "pipelines": sorted(PIPELINES.keys()),
    }


@app.get("/v1/models", response_model=ModelList)
async def list_models(_: None = Depends(_require_key)) -> ModelList:
    """List loaded pipelines + friendly metadata joined from models.yaml.

    Reloads metadata when the YAML's mtime changed since last serve so
    edits land without a shim restart.
    """
    registry.reload_if_stale()
    now = int(time.time())
    out: list[ModelEntry] = []
    for name, p in sorted(PIPELINES.items()):
        meta = registry.pipeline_meta(name)
        out.append(
            ModelEntry(
                id=name,
                created=now,
                description=(meta.description if meta else None) or p.description,
                supports_loras=p.supports_loras,
                friendly_name=(meta.friendly_name if meta else "") or p.friendly_name,
                excels_at=(meta.excels_at if meta else "") or p.excels_at,
            )
        )
    return ModelList(data=out)


@app.get("/v1/loras", response_model=LoraList)
async def list_loras(_: None = Depends(_require_key)) -> LoraList:
    """List .safetensors files in LORAS_DIR with friendly metadata joined
    from models.yaml. Files without a metadata match get returned anyway
    so a user-dropped LoRA still appears in the picker — just without a
    friendly label.
    """
    registry.reload_if_stale()
    entries: list[LoraEntry] = []
    if CONFIG.loras_dir.is_dir():
        for path in sorted(CONFIG.loras_dir.glob("*.safetensors")):
            try:
                size = path.stat().st_size
            except OSError:
                continue
            meta = registry.lora_meta(path.name)
            entries.append(
                LoraEntry(
                    name=path.name,
                    size_bytes=size,
                    friendly_name=meta.friendly_name if meta else "",
                    when_to_use=meta.when_to_use if meta else "",
                    recommended_strength=meta.recommended_strength if meta else 1.0,
                    trigger_words=list(meta.trigger_words) if meta else [],
                    compatible_with=list(meta.compatible_with) if meta else [],
                )
            )
    return LoraList(data=entries)


@app.post("/v1/images/generations", response_model=ImageResponse)
async def generate(
    req: ImageRequest, _: None = Depends(_require_key)
) -> ImageResponse:
    pipeline = PIPELINES.get(req.model)
    if pipeline is None:
        raise HTTPException(
            status_code=404,
            detail=f"unknown model {req.model!r}; available: {sorted(PIPELINES.keys())}",
        )

    try:
        width, height = (int(x) for x in req.size.split("x", 1))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"invalid size {req.size!r}") from e
    if width % 16 or height % 16:
        raise HTTPException(status_code=400, detail="size must be a multiple of 16")

    if req.loras and not pipeline.supports_loras:
        raise HTTPException(
            status_code=400,
            detail=(
                f"pipeline {req.model!r} doesn't support runtime LoRAs "
                "(no _meta.lora_injection); use a SDXL/Flux/Chroma pipeline"
            ),
        )

    lora_refs: list[LoraRef] = [
        LoraRef(
            name=lr.name,
            strength_model=lr.strength_model,
            strength_clip=lr.strength_clip,
        )
        for lr in (req.loras or [])
    ]

    client = ComfyClient(CONFIG.comfyui_base, timeout=CONFIG.request_timeout)
    if not await client.health():
        raise HTTPException(
            status_code=503,
            detail=f"ComfyUI unreachable at {CONFIG.comfyui_base}",
        )

    images: list[bytes] = []
    for i in range(req.n):
        try:
            workflow = pipeline.render(
                prompt=req.prompt,
                width=width,
                height=height,
                seed=(req.seed + i) if req.seed is not None else None,
                guidance=req.guidance,
                loras=lora_refs or None,
            )
        except PipelineError as e:
            raise HTTPException(status_code=500, detail=f"pipeline error: {e}") from e

        try:
            batch = await client.run(workflow)
        except ComfyError as e:
            raise HTTPException(status_code=502, detail=f"ComfyUI: {e}") from e
        images.extend(batch)

    if req.response_format == "url":
        # We don't operate object storage; degrade by returning b64 with a
        # data: URL prefix so any reasonable client still gets pixels.
        data = [
            ImageData(url=f"data:image/png;base64,{base64.b64encode(b).decode()}")
            for b in images
        ]
    else:
        data = [ImageData(b64_json=base64.b64encode(b).decode()) for b in images]

    return ImageResponse(created=int(time.time()), data=data)


# --- Entry point --------------------------------------------------------


def main() -> None:
    import uvicorn

    uvicorn.run(
        "comfyui_shim.server:app",
        host=CONFIG.shim_host,
        port=CONFIG.shim_port,
        log_level="info",
    )


if __name__ == "__main__":
    main()
