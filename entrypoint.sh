#!/bin/bash
# Stage models if absent, start ComfyUI, wait for it to actually bind, then the shim.
# No supervisor: two processes, and the shim is useless without ComfyUI, so if either dies
# the container should die with it.
set -uo pipefail

MODEL_ROOT="${MODEL_ROOT:-/workspace/models}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFY_EXTRA_ARGS="${COMFY_EXTRA_ARGS:-}"
SHIM_PORT="${SHIM_PORT:-8012}"
mkdir -p "$MODEL_ROOT"/{unet,vae,clip,loras,checkpoints,upscale_models}

# ── THE MODEL SET ────────────────────────────────────────────────────────────────────
# Four SOTA pipelines, selectable at request time: z-image-turbo, qwen-image-2.1,
# hidream-i1-fast, chroma-radiance. 14 destination files from 13 unique sources,
# ~95.8 GiB (~103 GB). ComfyUI swaps models per workflow, so only one resident set
# (18.3-32.4 GB) is in VRAM at a time and any of them fits one L40S.
#
# Every repo here is UNGATED, and that is a deliberate correction rather than a
# coincidence. models.yaml sources HiDream's VAE from black-forest-labs/FLUX.1-schnell,
# which is `gated: true` — it needs an accepted licence and an HF_TOKEN, which an EC2
# instance does not have and should not be given. Comfy-Org/HiDream-I1_ComfyUI publishes
# the same 0.31 GB FLUX VAE itself (verified identical size), so sourcing it from there
# deletes the only HF gate and the entire HF_TOKEN plumbing along with it.
#
# z_image's VAE is fetched to vae/z_image_ae.safetensors because its pipeline graph names
# it that, while HiDream's graph names its copy vae/ae.safetensors. Same bytes, two names,
# 0.31 GB of duplication — cheaper than teaching the graphs to share.
#
# Every path below was verified against the Hub with a HEAD request. A wrong path fails at
# graph-submit time, not here, which is the expensive place to find out.
declare -a WANT=(
  "Comfy-Org/z_image_turbo|split_files/diffusion_models/z_image_turbo_bf16.safetensors|unet/z_image_turbo_bf16.safetensors"
  "Comfy-Org/z_image_turbo|split_files/text_encoders/qwen_3_4b_fp8_mixed.safetensors|clip/qwen_3_4b_fp8_mixed.safetensors"
  "Comfy-Org/z_image_turbo|split_files/vae/ae.safetensors|vae/z_image_ae.safetensors"
  "Comfy-Org/z_image_turbo|split_files/loras/z_image_turbo_distill_patch_lora_bf16.safetensors|loras/z_image_turbo_distill_patch_lora_bf16.safetensors"
  "Comfy-Org/Qwen-Image-2.1|diffusion_models/qwen_image_2.1_bf16.safetensors|unet/qwen_image_2.1_bf16.safetensors"
  "Comfy-Org/Qwen-Image-2.1|text_encoders/qwen3vl_8b_bf16.safetensors|clip/qwen3vl_8b_bf16.safetensors"
  "Comfy-Org/Qwen-Image-2.1|vae/qwen_image_2.1_vae_bf16.safetensors|vae/qwen_image_2.1_vae_bf16.safetensors"
  "Comfy-Org/HiDream-I1_ComfyUI|split_files/diffusion_models/hidream_i1_fast_fp8.safetensors|unet/hidream_i1_fast_fp8.safetensors"
  "Comfy-Org/HiDream-I1_ComfyUI|split_files/text_encoders/clip_l_hidream.safetensors|clip/clip_l_hidream.safetensors"
  "Comfy-Org/HiDream-I1_ComfyUI|split_files/text_encoders/clip_g_hidream.safetensors|clip/clip_g_hidream.safetensors"
  "Comfy-Org/HiDream-I1_ComfyUI|split_files/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors|clip/t5xxl_fp8_e4m3fn_scaled.safetensors"
  "Comfy-Org/HiDream-I1_ComfyUI|split_files/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors|clip/llama_3.1_8b_instruct_fp8_scaled.safetensors"
  "Comfy-Org/HiDream-I1_ComfyUI|split_files/vae/ae.safetensors|vae/ae.safetensors"
  "Comfy-Org/Chroma1-Radiance_Repackaged|split_files/diffusion_models/chroma-radiance-x0.safetensors|unet/chroma-radiance-x0.safetensors"
  # ── the remaining 11 pipelines (added 2026-10-03) ──────────────────────────────────
  # Every path below was HEAD-checked against the Hub before being written here; a wrong
  # path fails at graph-submit time on a billing box, not here.
  #
  # flux1-dev-fp8 comes from Comfy-Org/flux1-dev, NOT the Kijai/flux-fp8 that models.yaml
  # names: Kijai's is GATED, and an EC2 box has no HF_TOKEN. Same story as HiDream's VAE.
  # With this substitution the whole 15-pipeline set needs no HF credentials at all.
  "comfyanonymous/flux_text_encoders|t5xxl_fp8_e4m3fn.safetensors|clip/t5xxl_fp8_e4m3fn.safetensors"
  "comfyanonymous/flux_text_encoders|clip_l.safetensors|clip/clip_l.safetensors"
  "lodestones/Chroma1-HD|Chroma1-HD.safetensors|unet/Chroma1-HD.safetensors"
  "silveroxides/Chroma1-HD-GGUF|Chroma1-HD-Q8_0.gguf|unet/Chroma1-HD-Q8_0.gguf"
  "Comfy-Org/flux1-dev|flux1-dev-fp8.safetensors|unet/flux1-dev-fp8.safetensors"
  "Comfy-Org/flux1-schnell|flux1-schnell-fp8.safetensors|unet/flux1-schnell-fp8.safetensors"
  "unsloth/FLUX.2-klein-4B-GGUF|flux-2-klein-4b-Q8_0.gguf|unet/flux-2-klein-4b-Q8_0.gguf"
  "Comfy-Org/flux2-dev|split_files/vae/flux2-vae.safetensors|vae/flux2-vae.safetensors"
  "Comfy-Org/Qwen-Image_ComfyUI|split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors|unet/qwen_image_fp8_e4m3fn.safetensors"
  "Comfy-Org/Qwen-Image_ComfyUI|split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors|clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"
  "Comfy-Org/Qwen-Image_ComfyUI|split_files/vae/qwen_image_vae.safetensors|vae/qwen_image_vae.safetensors"
  "lokCX/4x-Ultrasharp|4x-UltraSharp.pth|upscale_models/4x-UltraSharp.pth"
  "OnomaAIResearch/Illustrious-XL-v2.0|Illustrious-XL-v2.0.safetensors|checkpoints/Illustrious-XL-v2.0.safetensors"
  "RunDiffusion/Juggernaut-XL-v9|Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors|checkpoints/Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors"
  "LyliaEngine/Pony_Diffusion_V6_XL|ponyDiffusionV6XL_v6StartWithThisOne.safetensors|checkpoints/ponyDiffusionV6XL_v6StartWithThisOne.safetensors"
  "nyanntama/WAI-NSFW-illustrious-SDXL|waiNSFWIllustrious_v140.safetensors|checkpoints/waiNSFWIllustrious_v140.safetensors"
  "Linaqruf/anime-detailer-xl-lora|anime-detailer-xl.safetensors|loras/anime-detailer-xl.safetensors"
  "alvdansen/midsommarcartoon|araminta_k_midsommar_cartoon.safetensors|loras/araminta_k_midsommar_cartoon.safetensors"
)

missing=()
for spec in "${WANT[@]}"; do
  dst="${spec##*|}"
  [ -s "$MODEL_ROOT/$dst" ] || missing+=("$spec")
done

if [ ${#missing[@]} -eq 0 ]; then
  # THE EXPECTED PATH ON A RIG. The host seeds /cache from S3 with s5cmd before starting
  # this container (same seed-then-stream shape the vLLM path uses, measured at 1.29 GB/s
  # same-region), and /cache is mounted here as /workspace. The acceptance test greps for
  # this exact line to prove the warm S3 path was taken rather than the HuggingFace
  # fallback below — a 103 GB cold pull and a 90-150s warm fetch look the same from
  # outside except for how long you wait and what you paid.
  echo "models: already present, skipping fetch"
else
  echo "models: ${#missing[@]} of ${#WANT[@]} absent — fetching from HuggingFace"
  echo "models: COLD path. On a rig this means the S3 prefix is missing these files, so"
  echo "models: they come from HuggingFace — expect minutes of GPU time. Full set is ~225 GB."
  # HF_XET_HIGH_PERFORMANCE, not HF_HUB_ENABLE_HF_TRANSFER. The old pair was inert and
  # said so on the box (2026-10-03):
  #   WARNING: huggingface-hub 1.33.0 does not provide the extra 'hf-transfer'
  #   FutureWarning: HF_HUB_ENABLE_HF_TRANSFER is deprecated as 'hf_transfer' is not
  #   used anymore. Please use HF_XET_HIGH_PERFORMANCE instead
  # So the accelerated path was never active and the ~103 GB cold pull ran at roughly
  # 100 MB/s sustained instead of the 200-400 MB/s the staging design assumed — the
  # difference between a ~6 and a ~13 minute cold start. The [hf_transfer] extra no
  # longer exists in huggingface-hub 1.x, so installing it was a no-op too.
  export HF_XET_HIGH_PERFORMANCE=1
  for spec in "${missing[@]}"; do
    repo="${spec%%|*}"
    rest="${spec#*|}"
    src="${rest%%|*}"
    dst="$MODEL_ROOT/${spec##*|}"
    echo "  fetching $(basename "$dst")  <- $repo"
    python3 - "$repo" "$src" "$dst" <<'PY' || { echo "FATAL: model fetch failed for $src from $repo" >&2; exit 1; }
import os, shutil, sys
from huggingface_hub import hf_hub_download
repo, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
# MOVE, never copy, and drop the blob cache entry afterwards.
#
# hf_hub_download stages into HF_HOME's blob cache and the old code then COPIED to the
# destination, so the full set needed ~2x its size on disk at once. Measured 2026-10-03:
# 160 GB used for 91 GiB of models. That was survivable for the 4-pipeline set on a 419 GB
# instance store and is NOT survivable for all 15 — ~217 GB of weights would want ~434 GB
# and fill the disk mid-pull.
#
# The cache entry is a symlink into blobs/, so resolve it, move the real file into place,
# then prune the dangling link. os.replace is atomic within a filesystem; fall back to a
# copy across devices (the cache and the models tree are both on /workspace here, so the
# fallback should never fire).
real = os.path.realpath(hf_hub_download(repo_id=repo, filename=src))
os.makedirs(os.path.dirname(dst), exist_ok=True)
try:
    os.replace(real, dst)
except OSError:
    shutil.copyfile(real, dst)
    os.remove(real)
PY
  done
  echo "models: ready"
fi

# ComfyUI needs its model dirs where it expects them.
for d in unet vae clip loras checkpoints upscale_models; do
  mkdir -p "$COMFY_ROOT/models/$d"
  find "$MODEL_ROOT/$d" -maxdepth 1 -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    ln -sf "$f" "$COMFY_ROOT/models/$d/$(basename "$f")"
  done
done

# COMFY_EXTRA_ARGS is deliberately UNQUOTED on expansion so a claim can pass several
# flags (e.g. "--disable-smart-memory --highvram"). That is word-splitting on purpose,
# which is why it is not quoted here and why shellcheck would object.
# ── IS THERE ACTUALLY A GPU? ─────────────────────────────────────────────────────────
# nvidia-smi on the HOST only proves the driver sees the card. It does NOT prove torch
# inside this container can use it: a CUDA-runtime/driver mismatch, a missing
# --gpus flag, or a wrong nvidia-container-toolkit leaves torch happily falling back to
# CPU — and ComfyUI will then render, slowly and silently, on a GPU box that bills by the
# hour. That is a worse failure than crashing, because everything looks fine.
#
# Set REQUIRE_CUDA=0 to allow a CPU run (local smoke tests of this entrypoint do that).
REQUIRE_CUDA="${REQUIRE_CUDA:-1}"
CUDA_REPORT=$(python3 - <<'PYCUDA'
import torch
print(f"torch {torch.__version__} cuda_available={torch.cuda.is_available()} "
      f"built_for={torch.version.cuda} devices={torch.cuda.device_count()}")
PYCUDA
)
echo "cuda: $CUDA_REPORT"
case "$CUDA_REPORT" in
  *cuda_available=True*) : ;;
  *)
    if [ "$REQUIRE_CUDA" = "1" ]; then
      echo "FATAL: torch cannot see a CUDA device ($CUDA_REPORT)." >&2
      echo "       The host driver may predate this image's CUDA runtime, or the" >&2
      echo "       container was started without --gpus all. Refusing to render on CPU" >&2
      echo "       on a GPU instance. Set REQUIRE_CUDA=0 to override." >&2
      exit 1
    fi
    echo "WARNING: no CUDA device; continuing on CPU because REQUIRE_CUDA=0" >&2
    ;;
esac

echo "starting ComfyUI on :$COMFY_PORT ${COMFY_EXTRA_ARGS:+with $COMFY_EXTRA_ARGS}"
# shellcheck disable=SC2086
python3 "$COMFY_ROOT/main.py" --listen 0.0.0.0 --port "$COMFY_PORT" ${COMFY_EXTRA_ARGS:-} &
COMFY_PID=$!

# ── WAIT FOR COMFYUI TO ACTUALLY BIND ────────────────────────────────────────────────
# Not politeness — it closes the half-dead state. The shim answers /healthz with HTTP 200
# and {"comfyui_reachable": false} REGARDLESS of whether ComfyUI is up, and an HTTP probe
# cannot read a response body. So without this, a ComfyUI that fails to start leaves a
# container that boots, serves, and reports healthy while being unable to render anything
# — which is exactly how a rig got recorded as "verified + ComfyUI" having never rendered.
# Exiting non-zero instead lets docker's --restart=always act on it.
#
# /system_stats is ComfyUI's OWN endpoint; it cannot answer unless ComfyUI is really
# listening. 180s because a cold torch + CUDA init on a first boot is slow, and a
# too-short budget here would kill a box that was merely still starting.
echo "waiting for ComfyUI to answer on :$COMFY_PORT"
for i in $(seq 1 90); do
  if curl -fsS --max-time 3 "http://127.0.0.1:$COMFY_PORT/system_stats" > /dev/null 2>&1; then
    echo "ComfyUI is up after ~$((i * 2))s"
    break
  fi
  # If the process is already gone there is nothing to wait for.
  kill -0 "$COMFY_PID" 2>/dev/null || { echo "FATAL: ComfyUI exited during startup" >&2; exit 1; }
  sleep 2
  [ "$i" = 90 ] && { echo "FATAL: ComfyUI did not answer /system_stats within 180s" >&2; kill "$COMFY_PID" 2>/dev/null; exit 1; }
done

# ComfyUI is up, so /object_info is available — convert the shim's API-format pipelines
# into UI workflows so the editor opens with them in its browser rather than empty. Best
# effort on purpose: `|| true` is right HERE and nowhere else in this file, because the
# rig's actual job is the shim's /v1/images API, which does not read these files at all.
# A convenience feature must not take down a box that bills by the hour.
if [ -f /opt/seed_workflows.py ]; then
  python3 /opt/seed_workflows.py "http://127.0.0.1:$COMFY_PORT" \
    "${PIPELINES_DIR:-/opt/comfyui-shim/pipelines}" \
    "$COMFY_ROOT/user/default/workflows" || true
fi

echo "starting comfyui-shim on :$SHIM_PORT"
# The package ships a console script (comfyui_shim.server:main) — use it rather than
# invoking uvicorn directly, so whatever main() configures is not bypassed.
# It imports pipelines at module load and now RAISES on a missing PIPELINES_DIR, so a
# misconfigured catalog fails here instead of serving an empty /v1/models with HTTP 200.
comfyui-shim &
SHIM_PID=$!

# Either dying should take the container down so docker's restart policy can act, rather
# than leaving a half-dead box that answers /v1/models but cannot render.
wait -n "$COMFY_PID" "$SHIM_PID"
echo "a process exited; stopping container" >&2
kill "$COMFY_PID" "$SHIM_PID" 2>/dev/null
exit 1
