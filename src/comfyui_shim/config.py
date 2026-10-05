"""Env-driven config for the ComfyUI shim."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _default_repo_root() -> Path:
    # services/comfyui-shim/src/comfyui_shim/ → up 4 → repo root
    return Path(__file__).resolve().parents[4]


def _default_loras_dir() -> Path:
    return _default_repo_root() / "services" / "ComfyUI" / "models" / "loras"


def _default_models_yaml() -> Path:
    return _default_repo_root() / "models.yaml"


@dataclass(frozen=True)
class Config:
    comfyui_base: str = os.getenv("COMFYUI_BASE", "http://127.0.0.1:8188")
    pipelines_dir: Path = Path(
        os.getenv("PIPELINES_DIR", str(Path(__file__).resolve().parents[2] / "pipelines"))
    )
    loras_dir: Path = Path(os.getenv("LORAS_DIR", str(_default_loras_dir())))
    # Root of ComfyUI's model tree, used to answer "can this pipeline actually render?".
    # Empty or missing means "cannot tell", and the catalogue is NOT filtered in that
    # case — hiding models because we failed to find the directory would be worse than
    # listing one that fails.
    model_root: Path = Path(os.getenv("MODEL_ROOT", "/workspace/models"))
    models_yaml: Path = Path(os.getenv("MODELS_YAML", str(_default_models_yaml())))
    shim_port: int = int(os.getenv("SHIM_PORT", "8012"))
    shim_host: str = os.getenv("SHIM_HOST", "0.0.0.0")
    request_timeout: float = float(os.getenv("REQUEST_TIMEOUT", "300"))
    api_key: str = os.getenv("SHIM_API_KEY", "")  # empty => no auth check


CONFIG = Config()
