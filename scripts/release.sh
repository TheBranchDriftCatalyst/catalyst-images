#!/usr/bin/env bash
# Full release pipeline: version bump → changelog → build → push → git
# Usage: ./scripts/release.sh <version> [--skip-build] [--skip-push]
# Examples:
#   ./scripts/release.sh 1.0.1              # Full release
#   ./scripts/release.sh 1.0.1 --skip-push  # Build only, no registry push
#   ./scripts/release.sh 1.0.1 --skip-build # Git release only (images already built)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/release
source "${SCRIPT_DIR}/release-config.sh"

# Parse arguments
NEW_VERSION=""
SKIP_BUILD=false
SKIP_PUSH=false

for arg in "$@"; do
  case $arg in
    --skip-build) SKIP_BUILD=true ;;
    --skip-push) SKIP_PUSH=true ;;
    -*) log_error "Unknown option: $arg"; exit 1 ;;
    *) NEW_VERSION="$arg" ;;
  esac
done

if [[ -z "${NEW_VERSION}" ]]; then
  echo "Usage: ./scripts/release.sh <version> [--skip-build] [--skip-push]"
  echo ""
  echo "Examples:"
  echo "  ./scripts/release.sh 1.0.1              # Full release"
  echo "  ./scripts/release.sh 1.0.1 --skip-push  # Build only"
  echo "  ./scripts/release.sh 1.0.1 --skip-build # Git only"
  echo ""
  echo "Current version: ${VERSION}"
  exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              CATALYST RELEASE PIPELINE v${NEW_VERSION}              "
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Version bump
log_info "Step 1/5: Version bump"
"${SCRIPT_DIR}/release-version.sh" "${NEW_VERSION}"
export VERSION="${NEW_VERSION}"

# Step 2: Changelog
log_info "Step 2/5: Update changelog"
"${SCRIPT_DIR}/release-changelog.sh" "${NEW_VERSION}"

# Step 3: Build
if [[ "${SKIP_BUILD}" == "true" ]]; then
  log_warn "Step 3/5: Skipping build (--skip-build)"
else
  log_info "Step 3/5: Build all variants"
  "${SCRIPT_DIR}/release-build.sh"
fi

# Step 4: Push to registry
if [[ "${SKIP_PUSH}" == "true" ]]; then
  log_warn "Step 4/5: Skipping push (--skip-push)"
else
  log_info "Step 4/5: Push to registry"
  "${SCRIPT_DIR}/release-push.sh"
fi

# Step 5: Git commit, tag, push
log_info "Step 5/5: Git release"
"${SCRIPT_DIR}/release-git.sh" "${NEW_VERSION}"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    RELEASE COMPLETE!                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
log_success "Released v${NEW_VERSION}"
echo ""
echo "Images: ${FULL_IMAGE}:*-${NEW_VERSION}"
echo "GitHub: https://github.com/${GITHUB_REPO}/releases/tag/v${NEW_VERSION}"
