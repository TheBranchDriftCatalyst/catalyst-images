#!/usr/bin/env bash
# Bump version in VERSION file
# Usage: ./scripts/release-version.sh <version>
# Example: ./scripts/release-version.sh 1.0.1

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/release-config.sh"

NEW_VERSION="${1:-}"
if [[ -z "${NEW_VERSION}" ]]; then
  log_error "Version required: ./scripts/release-version.sh 1.0.1"
  exit 1
fi

VERSION_FILE="${SCRIPT_DIR}/../../VERSION"
OLD_VERSION=$(cat "${VERSION_FILE}" 2>/dev/null || echo "0.0.0")

log_info "Bumping version: ${OLD_VERSION} → ${NEW_VERSION}"

echo "${NEW_VERSION}" > "${VERSION_FILE}"

log_success "Version updated to ${NEW_VERSION}"
