#!/usr/bin/env bash
# Build all Docker image variants
# Usage: ./scripts/release-build.sh [variant...]
# Examples:
#   ./scripts/release-build.sh           # Build all variants
#   ./scripts/release-build.sh base k8s  # Build specific variants

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/release-config.sh"
source "${SCRIPT_DIR}/../analytics-beacon.sh" 2>/dev/null || true

# Override variants if arguments provided
if [[ $# -gt 0 ]]; then
  VARIANTS="$*"
fi

log_info "Building variants: ${VARIANTS}"
log_info "Version: ${VERSION}"
log_info "Architecture: ${ARCH}"

cd "${SCRIPT_DIR}/../../nix"

# Start analytics tracking
beacon_start 2>/dev/null || true

for variant in ${VARIANTS}; do
  log_info "Building ${IMAGE_NAME}:${variant}..."

  # Build with Nix
  if nix build ".#docker-${variant}" --out-link "result-${variant}"; then
    # Load into Docker
    ./result-${variant} | docker load

    # Tag with version
    docker tag "${IMAGE_NAME}:${variant}" "${IMAGE_NAME}:${variant}-${VERSION}"
    docker tag "${IMAGE_NAME}:${variant}" "${IMAGE_NAME}:${variant}-${VERSION}-${ARCH}"

    log_success "Built ${IMAGE_NAME}:${variant}-${VERSION}-${ARCH}"
    beacon_record_variant "${variant}" "success" 2>/dev/null || true
  else
    log_error "Failed to build ${variant}"
    beacon_record_variant "${variant}" "failed" 2>/dev/null || true
  fi
done

# End analytics tracking
beacon_end "success" "all" 2>/dev/null || true
beacon_github_summary 2>/dev/null || true

log_success "All variants built successfully!"

# Show built images
echo ""
log_info "Built images:"
docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -20
