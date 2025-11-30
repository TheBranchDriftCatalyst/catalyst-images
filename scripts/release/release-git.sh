#!/usr/bin/env bash
# Commit, tag, and push release to git
# Usage: ./scripts/release-git.sh <version>
# Example: ./scripts/release-git.sh 1.0.1

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/release-config.sh"

NEW_VERSION="${1:-}"
if [[ -z "${NEW_VERSION}" ]]; then
  log_error "Version required: ./scripts/release-git.sh 1.0.1"
  exit 1
fi

cd "${SCRIPT_DIR}/../.."

log_info "Creating git release for v${NEW_VERSION}..."

# Stage all changes
git add -A

# Check if there are changes to commit
if git diff --cached --quiet; then
  log_warn "No changes to commit"
else
  git commit -m "chore(release): v${NEW_VERSION}"
  log_success "Committed release changes"
fi

# Create tag
if git rev-parse "v${NEW_VERSION}" >/dev/null 2>&1; then
  log_warn "Tag v${NEW_VERSION} already exists"
else
  git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
  log_success "Created tag v${NEW_VERSION}"
fi

# Push
log_info "Pushing to origin..."
git push origin main
git push origin "v${NEW_VERSION}"

log_success "Released v${NEW_VERSION} to GitHub!"
echo ""
echo "View release at: https://github.com/${GITHUB_REPO}/releases/tag/v${NEW_VERSION}"
