#!/usr/bin/env bash
# Update CHANGELOG.md using git-cliff
# Usage: ./scripts/release-changelog.sh <version>
# Example: ./scripts/release-changelog.sh 1.0.1

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/release-config.sh"

NEW_VERSION="${1:-}"
if [[ -z "${NEW_VERSION}" ]]; then
  log_error "Version required: ./scripts/release-changelog.sh 1.0.1"
  exit 1
fi

cd "${SCRIPT_DIR}/../.."

log_info "Generating CHANGELOG.md for v${NEW_VERSION}..."

# Check if git-cliff is installed
if ! command -v git-cliff &>/dev/null; then
  log_warn "git-cliff not found, installing..."
  if command -v brew &>/dev/null; then
    brew install git-cliff
  else
    log_error "Please install git-cliff: https://git-cliff.org"
    exit 1
  fi
fi

# Generate changelog with git-cliff
git-cliff --tag "v${NEW_VERSION}" -o CHANGELOG.md

log_success "Generated CHANGELOG.md for v${NEW_VERSION}"
echo ""
echo "--- CHANGELOG Preview ---"
head -40 CHANGELOG.md
echo "..."
