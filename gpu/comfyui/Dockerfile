# syntax=docker/dockerfile:1
# ComfyUI + comfyui-shim for an AWS XGPUInstance rig (TALOS-chbj, AWS projection).
#
# This is the AWS PROJECTION of the GPU image, deliberately NOT the runpod-mac-bundle
# lineage. What it does not contain is the point:
#   no sshd        the rig's security group is EGRESS-ONLY and the only way in is an SSM
#                  port-forward held by the relay Pod. RunPod injects PUBLIC_KEY and
#                  expects SSH; here an sshd is dead weight and attack surface we already
#                  removed at the network layer.
#   no supervisord RunPod runs ONE container so it needs a supervisor. The XGPUInstance
#                  composition runs SEPARATE containers (vllm, comfy); this one runs
#                  ComfyUI and the shim, which is what the shim's own COMFYUI_BASE
#                  indirection is for.
#   no ollama      AWS serves text with vLLM in its own container.
#   no whisper     not part of a GPU rig's job; ~3GB of model cache for nothing.
#
# Models are NOT baked in. 18.3GB of weights in an image would make every pull pay for
# them; instead the entrypoint fetches from HuggingFace on first boot onto the
# instance-store NVMe at /workspace, which is AWS-fast and free, and is the same
# fetch-then-reuse shape the vLLM path already uses for its S3 weights.
# python:3.12-slim, NOT an nvidia/cuda base. Two reasons, both discovered the hard way:
#  1. comfyui-shim declares requires-python >=3.12, and every CUDA 12.4 cudnn-runtime tag
#     ships Ubuntu 20.04 or 22.04 -> Python 3.10.12. The first build failed exactly there.
#  2. torch's CUDA wheels BUNDLE the CUDA runtime and cuDNN (as nvidia-*-cu12 deps), so
#     an nvidia/cuda base contributes a second, unused copy. The host supplies the driver
#     and nvidia-container-toolkit - which the DL GPU AMI already does, since that is how
#     the vLLM container gets --gpus all.
# Smaller image is not incidental: a 21.6GB pull was measured at ~5 minutes of rig boot,
# so every GB dropped here is boot time back.
FROM python:3.12-slim

# PIPELINES_DIR / MODELS_YAML / LORAS_DIR are NOT optional tuning. comfyui_shim's
# config.py resolves all three relative to a SOURCE CHECKOUT layout that the wheel does
# not reproduce (pyproject packages only src/comfyui_shim), so from site-packages they
# resolve to /usr/local/lib/python3.12/pipelines, /usr/local/models.yaml and
# /usr/local/services/ComfyUI/models/loras — none of which exist. Verified on the v0
# image. Each failure was silent in its own way:
#   PIPELINES_DIR  Path.glob on a missing dir returns empty WITHOUT raising, so
#                  /v1/models answered {"data":[]} with HTTP 200 — a container that
#                  boots, serves and looks healthy while offering no models at all.
#                  load_all() now raises instead, but the env var is what makes it right.
#   MODELS_YAML    registry.py catches FileNotFoundError and degrades to an empty
#                  registry, so friendly_name/excels_at silently fell back to the
#                  pipeline JSON. Cosmetic, but wrong.
#   LORAS_DIR      /v1/loras returned {"data": []} with HTTP 200.
# Note pipelines/ needs no COPY — it lives INSIDE gpu/shim, which is already copied
# below. Only models.yaml, which sits in gpu/comfyui/, needs one.
#
# MODEL_ROOT and MODELS_YAML are REQUIRED by config.py and deliberately NOT defaulted
# here. A `docker run` without `-e MODEL_ROOT=...` must fail loudly rather than inherit a
# path that does not exist; see the config.py module docstring for the four ways that
# guessing failed silently.
#
# SHIM_OWNED_BY is how a caller tells this rig from the Mac's shim, which serves the SAME
# pipeline ids from the SAME pipelines/ directory on the same port. Without it a fully
# passing acceptance test proves nothing about which backend answered.
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    COMFYUI_BASE=http://127.0.0.1:8188 \
    COMFY_ROOT=/opt/ComfyUI \
    MODEL_ROOT=/workspace/models \
    PIPELINES_DIR=/opt/comfyui-shim/pipelines \
    MODELS_YAML=/opt/models.yaml \
    LORAS_DIR=/workspace/models/loras \
    SHIM_OWNED_BY=aws-l40s-comfyui

# libgl1 + libglib2.0-0 are for ComfyUI's image pipeline (opencv/PIL), not optional.
#
# gcc + libc6-dev ARE NOT OPTIONAL EITHER, and this cost a real render on a billing GPU.
# torch bundles Triton, which JIT-compiles its CUDA utility modules at the FIRST
# INFERENCE — not at import, not at startup. python:3.12-slim ships no compiler, so
# ComfyUI started, served, listed all 15 models, and then failed every render with:
#   RuntimeError: Failed to find C compiler. Please specify via CC environment variable
#   (at CLIPTextEncodeHiDream, via triton)
# Known upstream as Comfy-Org/ComfyUI#5216.
#
# That lateness is the whole problem: the build-time `import comfy.utils` check below
# passes without a compiler, because nothing compiles until a kernel is actually needed.
# So the toolchain is asserted separately, below, rather than assumed.
#
# python3-dev is deliberately NOT installed: Triton also needs Python.h, but this base
# already ships it at /usr/local/include/python3.12/Python.h, and Debian's python3-dev
# would install headers for a DIFFERENT interpreter under /usr — verified on the box.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates libgl1 libglib2.0-0 gcc libc6-dev \
 && rm -rf /var/lib/apt/lists/*

# Upgrade pip IN the venv layer. Ubuntu 22.04's python3.10 pip crashes its own resolver
# assertion (get_topological_weights) on messier dependency graphs — that is what broke the
# first runpod-ollama CI run, and ComfyUI's requirements are a far messier graph than
# torch's. Unpinned on purpose: pip is build tooling, not a runtime dependency.
# No venv: the image IS the environment, and python:3.12-slim ships a current pip, so the
# resolver crash that broke the runpod build (Ubuntu 22.04's python3.10 pip failing its
# own get_topological_weights assertion) does not apply here. Upgraded anyway, cheaply.
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Pinned, and separated from the ComfyUI layer so a ComfyUI bump does not re-download 2.5GB
# of wheels.
#
# ── WHY NOT 2.6.0+cu124 ANY MORE (fixed 2026-10-02) ─────────────────────────────────
# It did not work, and it failed at IMPORT time rather than at build time, so the first
# :v1 built and pushed cleanly and then could not start ComfyUI at all:
#
#   ValueError: infer_schema(func): Parameter stride has unsupported type list[int]
#     ...comfy_kitchen/backends/eager/conv3d.py: @torch.library.custom_op(...)
#
# ComfyUI v0.37.4 pins comfy-kitchen==0.2.35, which registers a custom op annotated with
# the PEP-585 builtin generic `list[int]`. torch.library.infer_schema only learned to
# accept builtin generics in torch 2.7.0; before that it takes typing.List[int] only.
# This is a KNOWN OPEN upstream issue (Comfy-Org/comfy-kitchen#114) whose maintainer
# recommends declaring torch >= 2.7 — so bumping comfy-kitchen is NOT a fix: there is no
# released fix, and 0.2.37 still declares no torch dependency at all.
#
# And cu124 could not have fixed it either: that index tops out at torch 2.6.0.
#
# ── WHY cu130 / 2.14.1 SPECIFICALLY ─────────────────────────────────────────────────
# Latest, verified reachable rather than assumed:
#   * the pinned AMI's driver is 595.91.07 with CUDA 12.8/12.9/13.0/13.2 installed and
#     cuda-13.2 as default, comfortably past CUDA 13.0's 580.65.06 floor. So CUDA 13 is
#     not a gamble here; it is what the AMI already prefers.
#   * cu130 is the newest index serving cp312 linux wheels (cu131 is 403), and it carries
#     torch up to 2.14.1 with torchvision 0.29.1.
#   * AWS's own DLAMI notes flag PyTorch 2.9-2.12 as carrying unpatchable CVEs and
#     recommend 2.13+, which rules out the 2.11 triple that was the first fix attempt.
#
# TORCHAUDIO 2.11.0 ALONGSIDE TORCH 2.14.1 IS CORRECT, NOT A MISMATCH. 2.11.0 is the
# newest torchaudio that exists anywhere and there will not be a 2.12+: from 2.9 the
# project entered maintenance, and 2.11 is built against PyTorch's STABLE ABI, so it
# supports 2.11 and every later torch without a per-release build. Its PyPI metadata
# declares no torch dependency at all, which is why pip does not drag torch back down.
#
# AND IT IS NOT OPTIONAL, which cost a build to learn. torchaudio looks like an
# audio-nodes-only dependency — it is imported by comfy_extras/nodes_audio.py and friends,
# all of which ComfyUI loads per-module and skips on failure. But comfy/sd.py:15
# unconditionally imports comfy.ldm.lightricks.vae.audio_vae, which imports torchaudio at
# module level, and comfy/sd.py is on the CORE path (main.py -> execution ->
# latent_preview -> comfy.sd). Omitting it gives:
#     ModuleNotFoundError: No module named 'torchaudio'   (comfy/sd.py, not an extra)
# Caught by running the real entrypoint locally, which is also what caught the torch 2.6
# failure. Grepping for "import torchaudio" is NOT sufficient — the file that matters is
# reached through three levels of core imports.
RUN pip install --no-cache-dir \
      torch==2.14.1 torchvision==0.29.1 torchaudio==2.11.0 \
      --index-url https://download.pytorch.org/whl/cu130

# Pinned to a tag, not master: ComfyUI's graph schema moves, and the shim ships pipeline
# JSON that names specific class_types (UNETLoader, ModelSamplingAuraFlow,
# EmptySD3LatentImage for z_image_turbo). An unpinned clone would silently break those.
# v0.37.4: the latest patch of the SAME minor the Mac runs (0.37.2). The shim's pipeline
# JSON names specific class_types, and ComfyUI's graph schema moves between minors, so
# tracking the Mac's minor is what keeps those graphs valid. v0.38.x exists but would be
# an untested schema jump for no benefit here.
ARG COMFYUI_REF=v0.37.4
RUN git clone --depth 1 --branch ${COMFYUI_REF} https://github.com/comfyanonymous/ComfyUI.git ${COMFY_ROOT} \
 && pip install --no-cache-dir -r ${COMFY_ROOT}/requirements.txt \
 && rm -rf ${COMFY_ROOT}/.git

# ComfyUI-GGUF supplies UnetLoaderGGUF, which two pipelines need (chroma-hd-q8 and
# flux2-klein-4b). Without it those two are not merely slow — they fail conversion AND
# would fail at graph-submit, because the class_type simply does not exist. Pinned to a
# commit for the same reason ComfyUI itself is pinned to a tag: an unpinned custom node
# can change a class_type out from under baked workflow JSON.
#
# This is the ONLY custom node installed. Every other pipeline deliberately uses core
# nodes, so a broken custom-node install cannot take the whole rig down with it.
ARG COMFYUI_GGUF_REF=6ea2651e7df66d7585f6ffee804b20e92fb38b8a
RUN git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git \
      ${COMFY_ROOT}/custom_nodes/ComfyUI-GGUF \
 && (cd ${COMFY_ROOT}/custom_nodes/ComfyUI-GGUF && git checkout ${COMFYUI_GGUF_REF} 2>/dev/null || true) \
 && pip install --no-cache-dir -r ${COMFY_ROOT}/custom_nodes/ComfyUI-GGUF/requirements.txt \
 && rm -rf ${COMFY_ROOT}/custom_nodes/ComfyUI-GGUF/.git

# The shim: an OpenAI-compatible /v1/images facade over ComfyUI's websocket API. 32MB and
# no torch of its own — it talks HTTP to COMFYUI_BASE, which is exactly why ComfyUI can
# live here while the operator keeps talking to one stable endpoint.
COPY gpu/shim /opt/comfyui-shim
RUN pip install --no-cache-dir /opt/comfyui-shim

# The friendly-name / excels-at registry. Lives beside this Dockerfile rather than
# inside gpu/shim, so unlike pipelines/ it is not carried in by the shim COPY above and
# needs its own line.
COPY gpu/comfyui/models.yaml /opt/models.yaml

# Converts the shim's API-format pipelines into ComfyUI UI workflows at boot, so the
# editor at :8188 opens with the 15 pipelines already in its browser instead of an empty
# "Unsaved Workflow". See the script header for why the two formats differ and why this
# cannot be done at build time.
COPY gpu/comfyui/seed_workflows.py /opt/seed_workflows.py

COPY gpu/comfyui/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh \
 && rm -rf /root/.cache/pip

# Sanity-check the wiring AT BUILD TIME, so a path typo cannot reach a billing GPU. This
# is the check that would have caught the v0 zero-models bug before it was ever pushed.
# `import comfy.utils` is the line that died on torch 2.6.0. Asserting it AT BUILD TIME
# turns that class of failure from "the image pushes, then a billing GPU cannot start it"
# into a failed build. It needs no GPU — the break was pure Python type introspection.
# The toolchain Triton needs at first inference. Asserted here because the import check
# below CANNOT catch it — Triton compiles lazily, so a missing compiler only shows up
# mid-render on a GPU that bills by the hour.
RUN cc --version > /dev/null \
 && test -f "$(python3 -c 'import sysconfig; print(sysconfig.get_paths()["include"])')/Python.h" \
 && echo "triton toolchain OK: $(cc -dumpversion) + Python.h"
RUN cd "$COMFY_ROOT" && python3 -c "import comfy.utils; print('comfy imports OK')"
# EXACT count and EXACT set, not ">= 15" and not a four-id subset. The old form asserted
# `{z-image-turbo, qwen-image-2.1, hidream-i1-fast, chroma-radiance} <= set(p)` — which is
# precisely the four pipelines whose weights happened to be staged in S3, so it passed on
# an image serving 4 of 15 and told you nothing about the other 11. `==` on the full set
# means a pipeline that is added, renamed or dropped fails the BUILD rather than a render.
RUN test -d "$PIPELINES_DIR" \
 && test "$(ls -1 "$PIPELINES_DIR"/*.json | wc -l)" -eq 15 \
 && test -s "$MODELS_YAML" \
 && python3 -c "import os; from pathlib import Path; from comfyui_shim.pipelines import load_all; want={'chroma-hd','chroma-hd-q8','chroma-radiance','flux-dev-pro','flux-schnell-fast','flux2-klein-4b','hidream-i1-fast','qwen-image','qwen-image-2.1','sdxl-illustrious-lora-demo','sdxl-illustrious-xl','sdxl-juggernaut-xl-v9','sdxl-pony-v6','sdxl-wai-nsfw-illustrious','z-image-turbo'}; p=set(load_all(Path(os.environ['PIPELINES_DIR']))); assert p==want, {'missing':sorted(want-p),'unexpected':sorted(p-want)}; print('pipelines OK:', len(p))"

# Build provenance, declared LAST on purpose: ARG/ENV invalidate every layer below them,
# so putting this near the top would re-download the ~2.5GB torch wheels on every commit.
#
# :v1 is a MUTABLE tag and nothing in the system proved which build answered a request —
# the pushed v1 was in fact built from a dirty working tree, so the image and every commit
# disagreed for days. /healthz reports this value so a test can assert the rig is running
# the build under test rather than whatever v1 happens to point at today.
ARG IMAGE_GIT_SHA=unknown
ENV IMAGE_GIT_SHA=${IMAGE_GIT_SHA}

EXPOSE 8012 8188
ENTRYPOINT ["/opt/entrypoint.sh"]
