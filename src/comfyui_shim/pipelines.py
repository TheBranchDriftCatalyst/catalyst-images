"""Load pipeline JSON templates and substitute runtime parameters.

Each pipeline file is a ComfyUI API-format workflow with an extra ``_meta``
block describing how runtime params (prompt, dimensions, seed) map onto node
inputs. We swap those values in before submission and strip ``_meta`` so the
ComfyUI server sees a clean workflow.

LoRA injection
--------------
A pipeline opts in to runtime LoRA stacking by declaring ``_meta.lora_injection``::

    "lora_injection": {
      "model": {
        "source":    "1",          # node providing the MODEL output
        "output":    0,            # which output slot is MODEL
        "consumers": ["30"]        # nodes whose `model` input must be rewritten
      },
      "clip": {
        "source":    "1",          # node providing the CLIP output
        "output":    1,            # may differ from model.source for split loaders
        "consumers": ["10", "11"]  # nodes whose `clip` input must be rewritten
      }
    }

For SDXL (``CheckpointLoaderSimple`` → MODEL+CLIP+VAE from one node) the model
and clip sources are the same node with different output slots. For modern
split-loader pipelines (Flux/Chroma/Qwen/HiDream) MODEL and CLIP come from
different loader nodes, hence the separate ``model``/``clip`` keys.

At render time, ``Pipeline.render(loras=[...])`` synthesises one ``LoraLoader``
node per requested LoRA, chains them MODEL→MODEL and CLIP→CLIP, then rewrites
each consumer to read from the last LoRA in the stack. Pipelines without the
block reject ``loras`` requests outright — opt-in keeps surprises away.
"""
from __future__ import annotations

import copy
import json
import secrets
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class PipelineError(Exception):
    """Raised for unknown pipeline names or invalid templates."""


_REPLACEMENT_TOKEN = "REPLACED_AT_RUNTIME"
_LORA_NODE_PREFIX = "lora_"


@dataclass(frozen=True)
class LoraRef:
    """One LoRA in a render-time stack."""
    name: str
    strength_model: float = 1.0
    strength_clip: float = 1.0


class Pipeline:
    """Compiled, parameter-aware view of a single workflow JSON."""

    def __init__(self, name: str, raw: dict[str, Any]):
        self.name = name
        self.raw = raw
        meta = raw.get("_meta", {})
        if not meta:
            raise PipelineError(f"pipeline {name!r} is missing _meta block")
        self.meta = meta
        self.description = meta.get("description", "")
        self.friendly_name: str = meta.get("friendly_name", name)
        self.excels_at: str = meta.get("excels_at", "")
        self.default_size: str = meta.get("default_size", "1024x1024")
        self.approx_seconds: float = float(meta.get("approx_seconds_m5_max", 0))
        # parameters: { "prompt": "$nodes.6.inputs.text" }
        # or         { "prompt": ["$nodes.6.inputs.clip_l", "$nodes.6.inputs.t5xxl"] }
        self._param_paths: dict[str, str | list[str]] = meta.get("parameters", {})
        self._lora_injection: dict[str, Any] | None = meta.get("lora_injection")

    @property
    def supports_loras(self) -> bool:
        return self._lora_injection is not None

    def render(
        self,
        *,
        prompt: str,
        width: int,
        height: int,
        seed: int | None = None,
        guidance: float | None = None,
        loras: list[LoraRef] | None = None,
    ) -> dict[str, Any]:
        """Return a workflow ready to POST to ``/prompt``."""
        wf = copy.deepcopy(self.raw)
        wf.pop("_meta", None)

        if seed is None:
            seed = secrets.randbits(32)

        values: dict[str, Any] = {
            "prompt": prompt,
            "width": int(width),
            "height": int(height),
            "seed": int(seed),
        }
        if guidance is not None:
            values["guidance"] = float(guidance)

        for param, paths in self._param_paths.items():
            if param not in values:
                continue
            if isinstance(paths, str):
                paths = [paths]
            for path in paths:
                self._set_path(wf, path, values[param])

        if loras:
            if not self.supports_loras:
                raise PipelineError(
                    f"pipeline {self.name!r} does not declare lora_injection; "
                    "can't stack LoRAs on it"
                )
            self._inject_loras(wf, loras)

        # Defensive: any node still containing the placeholder is misconfigured.
        for node_id, node in wf.items():
            for key, val in (node.get("inputs") or {}).items():
                if val == _REPLACEMENT_TOKEN:
                    raise PipelineError(
                        f"unbound parameter slot at node {node_id} input {key!r} "
                        f"for pipeline {self.name!r}"
                    )
        return wf

    # --- LoRA chain synthesis -----------------------------------------

    def _inject_loras(self, wf: dict[str, Any], loras: list[LoraRef]) -> None:
        """Build a chain of LoraLoader nodes and rewire MODEL/CLIP consumers.

        Each LoraLoader takes MODEL+CLIP from the previous node in the chain
        (or from the declared sources for the first one) and produces patched
        MODEL+CLIP outputs. Consumers (KSampler for MODEL, CLIPTextEncode for
        CLIP) are rewritten to read from the tail of the chain.
        """
        inj = self._lora_injection
        assert inj is not None  # supports_loras was checked
        model_cfg = inj.get("model", {})
        clip_cfg = inj.get("clip", {})
        model_src = (str(model_cfg["source"]), int(model_cfg.get("output", 0)))
        clip_src = (str(clip_cfg["source"]), int(clip_cfg.get("output", 0)))
        model_consumers = [str(x) for x in model_cfg.get("consumers", [])]
        clip_consumers = [str(x) for x in clip_cfg.get("consumers", [])]

        for src, label in [(model_src[0], "model"), (clip_src[0], "clip")]:
            if src not in wf:
                raise PipelineError(
                    f"lora_injection.{label}.source {src!r} not present in {self.name!r}"
                )

        prev_model_ref = [model_src[0], model_src[1]]
        prev_clip_ref = [clip_src[0], clip_src[1]]
        last_lora_id: str | None = None
        for i, lr in enumerate(loras):
            node_id = f"{_LORA_NODE_PREFIX}{i}"
            wf[node_id] = {
                "class_type": "LoraLoader",
                "inputs": {
                    "model": list(prev_model_ref),
                    "clip": list(prev_clip_ref),
                    "lora_name": lr.name,
                    "strength_model": float(lr.strength_model),
                    "strength_clip": float(lr.strength_clip),
                },
            }
            prev_model_ref = [node_id, 0]
            prev_clip_ref = [node_id, 1]
            last_lora_id = node_id

        assert last_lora_id is not None  # loras was non-empty (caller guard)

        # Rewire consumers — point their model/clip inputs at the tail.
        for cid in model_consumers:
            node = wf.get(cid)
            if node is None:
                raise PipelineError(
                    f"lora_injection.model.consumers references missing node {cid!r}"
                )
            node["inputs"]["model"] = [last_lora_id, 0]
        for cid in clip_consumers:
            node = wf.get(cid)
            if node is None:
                raise PipelineError(
                    f"lora_injection.clip.consumers references missing node {cid!r}"
                )
            node["inputs"]["clip"] = [last_lora_id, 1]

    @staticmethod
    def _set_path(wf: dict[str, Any], path: str, value: Any) -> None:
        # path like "$nodes.6.inputs.text" -> wf["6"]["inputs"]["text"] = value
        if not path.startswith("$nodes."):
            raise PipelineError(f"unsupported parameter path: {path!r}")
        parts = path[len("$nodes."):].split(".")
        if len(parts) < 2:
            raise PipelineError(f"parameter path too short: {path!r}")
        node_id, *rest = parts
        node = wf.get(node_id)
        if node is None:
            raise PipelineError(f"path {path!r} references missing node {node_id!r}")
        cursor: Any = node
        for key in rest[:-1]:
            cursor = cursor[key]
        cursor[rest[-1]] = value


def load_all(pipelines_dir: Path) -> dict[str, Pipeline]:
    out: dict[str, Pipeline] = {}
    for path in sorted(pipelines_dir.glob("*.json")):
        raw = json.loads(path.read_text())
        meta = raw.get("_meta", {})
        name = meta.get("name") or path.stem
        out[name] = Pipeline(name, raw)
    return out
