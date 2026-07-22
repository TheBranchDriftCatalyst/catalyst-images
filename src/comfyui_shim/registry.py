"""Friendly metadata loader for ``models.yaml``.

The shim is intentionally narrow about *running* workflows, but its
``/v1/models`` + ``/v1/loras`` endpoints have to surface enough copy for
the operator UI to render a useful picker (friendly name, "use this
when…", recommended LoRA strength, etc.). Rather than make the UI parse
``models.yaml`` over a separate wire, we join here once and serve the
enriched shape directly.

We cache the YAML at module load and offer an explicit ``reload()`` so
operator restarts pick up edits cleanly. The cache is mtime-aware: any
caller may call ``reload_if_stale()`` on a hot path and we'll re-parse
only when the file actually changed — cheap enough to call on every
``/v1/models`` request.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .config import CONFIG

log = logging.getLogger("comfyui_shim.registry")


@dataclass(frozen=True)
class PipelineMeta:
    """Friendly fields for a pipeline, joined from models.yaml.

    ``name`` matches the pipeline's ``_meta.name`` in its JSON template;
    everything else degrades to an empty default when models.yaml is
    missing or out of sync with the pipelines on disk.
    """
    name: str
    friendly_name: str = ""
    excels_at: str = ""
    description: str = ""
    tags: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class LoraMeta:
    """Friendly fields for a LoRA file, joined from models.yaml.

    ``filename`` matches the on-disk filename in LORAS_DIR (i.e. the
    ``hf_file`` field in models.yaml — which is what the shim's filename
    scanner returns).
    """
    filename: str
    friendly_name: str = ""
    when_to_use: str = ""
    recommended_strength: float = 1.0
    trigger_words: list[str] = field(default_factory=list)
    compatible_with: list[str] = field(default_factory=list)


_pipelines_by_name: dict[str, PipelineMeta] = {}
_loras_by_filename: dict[str, LoraMeta] = {}
_loaded_mtime: float = 0.0


def _empty_registry() -> None:
    global _pipelines_by_name, _loras_by_filename
    _pipelines_by_name = {}
    _loras_by_filename = {}


def _load(path: Path) -> None:
    """Parse models.yaml in-place — overwrites the module-level cache.

    Failures are logged and result in an empty registry; callers degrade
    to filename-only responses, which the operator UI can render in a
    less-pretty fallback state.
    """
    global _pipelines_by_name, _loras_by_filename, _loaded_mtime
    try:
        import yaml  # local import — keeps yaml off the cold path

        data: Any = yaml.safe_load(path.read_text()) or {}
    except FileNotFoundError:
        log.info("models.yaml not found at %s — friendly metadata disabled", path)
        _empty_registry()
        _loaded_mtime = 0.0
        return
    except Exception as exc:  # pragma: no cover - defensive
        log.warning("models.yaml parse failed (%s): %s", path, exc)
        _empty_registry()
        return

    pipelines: dict[str, PipelineMeta] = {}
    for p in (data.get("image_gen", {}) or {}).get("pipelines", []) or []:
        if not isinstance(p, dict):
            continue
        name = p.get("name")
        if not isinstance(name, str):
            continue
        pipelines[name] = PipelineMeta(
            name=name,
            friendly_name=str(p.get("friendly_name") or ""),
            excels_at=str(p.get("excels_at") or ""),
            description=str(p.get("description") or ""),
            tags=[str(t) for t in (p.get("tags") or []) if isinstance(t, str)],
        )

    loras: dict[str, LoraMeta] = {}
    for f in (data.get("image_models", {}) or {}).get("files", []) or []:
        if not isinstance(f, dict):
            continue
        if f.get("dest") != "loras":
            continue
        filename = f.get("hf_file")
        if not isinstance(filename, str):
            continue
        # filename in models.yaml is the HF path; the on-disk file is the
        # basename (the downloader strips the path). Use the basename so
        # the join key matches what /v1/loras emits.
        basename = filename.rsplit("/", 1)[-1]
        loras[basename] = LoraMeta(
            filename=basename,
            friendly_name=str(f.get("friendly_name") or ""),
            when_to_use=str(f.get("when_to_use") or ""),
            recommended_strength=float(f.get("recommended_strength") or 1.0),
            trigger_words=[str(t) for t in (f.get("trigger_words") or []) if isinstance(t, str)],
            compatible_with=[str(t) for t in (f.get("compatible_with") or []) if isinstance(t, str)],
        )

    _pipelines_by_name = pipelines
    _loras_by_filename = loras
    try:
        _loaded_mtime = path.stat().st_mtime
    except OSError:
        _loaded_mtime = 0.0
    log.info(
        "registry loaded from %s — %d pipelines, %d loras",
        path, len(pipelines), len(loras),
    )


def reload_if_stale(path: Path | None = None) -> None:
    """Re-parse models.yaml if its mtime changed since the last load."""
    p = path or CONFIG.models_yaml
    try:
        mtime = p.stat().st_mtime
    except OSError:
        # File missing — only act if we had previously loaded one.
        if _loaded_mtime != 0.0:
            _load(p)
        return
    if mtime != _loaded_mtime:
        _load(p)


def reload(path: Path | None = None) -> None:
    """Force a re-parse regardless of mtime."""
    _load(path or CONFIG.models_yaml)


def pipeline_meta(name: str) -> PipelineMeta | None:
    return _pipelines_by_name.get(name)


def lora_meta(filename: str) -> LoraMeta | None:
    return _loras_by_filename.get(filename)


# Eager load at import so the first request sees a populated registry.
_load(CONFIG.models_yaml)
