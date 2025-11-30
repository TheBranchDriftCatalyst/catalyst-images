#!/usr/bin/env bash
# Push Docker images to container registry
# Usage: ./scripts/release-push.sh [variant...]
# Examples:
#   ./scripts/release-push.sh           # Push all variants
#   ./scripts/release-push.sh base k8s  # Push specific variants

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/release-config.sh"

# Override variants if arguments provided
if [[ $# -gt 0 ]]; then
  VARIANTS="$*"
fi

log_info "Pushing to: ${FULL_IMAGE}"
log_info "Variants: ${VARIANTS}"
log_info "Version: ${VERSION}"

# Check Docker login
check_ghcr_login() {
  if ! docker pull "${REGISTRY}/library/hello-world" &>/dev/null 2>&1; then
    # Try a simple auth check
    if ! grep -q "ghcr.io" ~/.docker/config.json 2>/dev/null; then
      log_warn "Not logged into GHCR. Please run:"
      echo ""
      echo "  echo \$GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin"
      echo ""
      log_warn "Or set GITHUB_TOKEN env var with a PAT that has 'write:packages' scope"
      return 1
    fi
  fi
  return 0
}

# Verify we can push (check auth)
if ! check_ghcr_login; then
  log_error "GHCR authentication required"
  exit 1
fi

for variant in ${VARIANTS}; do
  log_info "Pushing ${variant}..."

  # Tag for registry
  docker tag "${IMAGE_NAME}:${variant}" "${FULL_IMAGE}:${variant}"
  docker tag "${IMAGE_NAME}:${variant}" "${FULL_IMAGE}:${variant}-${VERSION}"
  docker tag "${IMAGE_NAME}:${variant}" "${FULL_IMAGE}:${variant}-${VERSION}-${ARCH}"

  # Push all tags
  docker push "${FULL_IMAGE}:${variant}"
  docker push "${FULL_IMAGE}:${variant}-${VERSION}"
  docker push "${FULL_IMAGE}:${variant}-${VERSION}-${ARCH}"

  log_success "Pushed ${FULL_IMAGE}:${variant}-${VERSION}"
done

log_success "All variants pushed to ${REGISTRY}!"
echo ""
log_info "Images available at:"
for variant in ${VARIANTS}; do
  echo "  ${FULL_IMAGE}:${variant}"
  echo "  ${FULL_IMAGE}:${variant}-${VERSION}"
done
