"""Env-driven config for the ComfyUI shim.

TWO PATHS ARE REQUIRED, NOT DEFAULTED, AND THAT IS DELIBERATE.

This module used to guess MODELS_YAML and LORAS_DIR by walking
``Path(__file__).parents[4]`` to find a repo root. That walk encoded one
specific source layout (``services/comfyui-shim/src/comfyui_shim/``) which the
installed wheel never reproduces — pyproject packages only ``src/comfyui_shim``
— and which this repo's layout does not match either. After the move to
``gpu/shim/`` it resolves to the catalyst-images root in a checkout and to ``/``
inside the image; ``models.yaml`` exists at neither. Measured both.

Every one of those failures was SILENT in its own way, which is why they are
now hard errors instead of guesses:

* ``PIPELINES_DIR`` — ``Path.glob`` on a missing directory returns empty without
  raising, so ``/v1/models`` answered ``{"data":[]}`` with HTTP 200: a container
  that boots, serves, and looks healthy while offering nothing.
* ``MODELS_YAML`` — ``registry.py`` catches the read failure and degrades to an
  empty registry, so every ``friendly_name`` and ``excels_at`` silently fell back
  to the pipeline JSON.
* ``LORAS_DIR`` — ``/v1/loras`` returned ``{"data": []}`` with HTTP 200.
* ``MODEL_ROOT`` — defaulted to ``/workspace/models``, the AWS path. Off-rig that
  directory does not exist, so the staged-weight filter in ``pipelines.py``
  degrades open and the catalogue is unfiltered. On the Mac the answer happened
  to be right anyway (all weights are present), which is exactly what let the
  wrong default survive.

PIPELINES_DIR KEEPS ITS DEFAULT, because unlike the others it is correct in both
places: ``parents[2]`` is ``gpu/shim`` in a checkout and ``/opt/comfyui-shim`` in
the image, and ``pipelines/`` sits inside the tree that gets copied wholesale.

LORAS_DIR DERIVES FROM MODEL_ROOT rather than being separately required, so the
two cannot disagree about where the model tree is. Override it only if the LoRAs
genuinely live outside the model root.
"""
from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field
from pathlib import Path

log = logging.getLogger(__name__)


class ConfigError(RuntimeError):
    """A required path is unset. Raised at import, on purpose: a shim that
    cannot find its catalogue must not start and answer 200 with an empty one."""


def _required_path(var: str, why: str) -> Path:
    raw = os.getenv(var, "").strip()
    if not raw:
        raise ConfigError(
            f"{var} is required and unset. {why}\n"
            f"  Set it in the launchd plist (Mac) or the docker run -e flags (rig).\n"
            f"  It is required rather than guessed because every previous default "
            f"resolved to a path that did not exist, and the shim answered HTTP 200 "
            f"with an empty catalogue instead of failing."
        )
    return Path(raw)


def _default_pipelines_dir() -> Path:
    # parents[2] == the shim tree root: `gpu/shim` in a checkout,
    # `/opt/comfyui-shim` in the image. Correct in both; see the module docstring.
    return Path(__file__).resolve().parents[2] / "pipelines"


@dataclass(frozen=True)
class Config:
    comfyui_base: str = os.getenv("COMFYUI_BASE", "http://127.0.0.1:8188")
    pipelines_dir: Path = field(
        default_factory=lambda: Path(
            os.getenv("PIPELINES_DIR") or str(_default_pipelines_dir())
        )
    )
    # Root of ComfyUI's model tree. Used to answer "can this pipeline actually
    # render?" — see pipelines.py. Required: see the module docstring.
    model_root: Path = field(
        default_factory=lambda: _required_path(
            "MODEL_ROOT",
            "It is the root of ComfyUI's model tree (the directory holding "
            "unet/, vae/, clip/, checkpoints/, loras/, upscale_models/).",
        )
    )
    models_yaml: Path = field(
        default_factory=lambda: _required_path(
            "MODELS_YAML",
            "It is the catalogue supplying friendly_name, excels_at and the LoRA "
            "metadata that /v1/models and /v1/loras join onto each pipeline.",
        )
    )
    # Sentinel is the EMPTY STRING, not an empty Path: Path("") == Path(".") and
    # str(Path("")) is ".", which is truthy — so testing the Path cannot tell
    # "unset" from "set to the cwd". Caught exactly that way: loras_dir resolved
    # to "." and reported [ok], because "." exists.
    loras_dir_raw: str = os.getenv("LORAS_DIR", "").strip()
    loras_dir: Path = field(default_factory=lambda: Path("."))
    shim_port: int = int(os.getenv("SHIM_PORT", "8012"))
    shim_host: str = os.getenv("SHIM_HOST", "0.0.0.0")
    request_timeout: float = float(os.getenv("REQUEST_TIMEOUT", "300"))
    api_key: str = os.getenv("SHIM_API_KEY", "")  # empty => no auth check

    def __post_init__(self) -> None:
        # Derive loras_dir from model_root so the two cannot disagree.
        object.__setattr__(
            self,
            "loras_dir",
            Path(self.loras_dir_raw) if self.loras_dir_raw else self.model_root / "loras",
        )

    def log_resolved_paths(self) -> None:
        """Print every resolved path AND whether it exists.

        The cheapest possible antidote to this whole bug class: every silent
        failure above would have been obvious from one line of startup output.
        """
        for name in ("pipelines_dir", "models_yaml", "model_root", "loras_dir"):
            p = getattr(self, name)
            log.info(
                "config: %-14s %s  [%s]",
                name,
                p,
                "ok" if p.exists() else "MISSING",
            )


CONFIG = Config()
