#!/usr/bin/env bash
# Release configuration - sourced by other release scripts
# Derives registry from git remote automatically

set -euo pipefail

# Get repo info from git remote
get_github_repo() {
  git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | tr '[:upper:]' '[:lower:]'
}

# Configuration
export GITHUB_REPO="${GITHUB_REPO:-$(get_github_repo)}"
export REGISTRY="${REGISTRY:-ghcr.io}"
export IMAGE_NAME="${IMAGE_NAME:-catalyst-images}"
export FULL_IMAGE="${REGISTRY}/${GITHUB_REPO%%/*}/${IMAGE_NAME}"
export VERSION="${VERSION:-$(cat VERSION 2>/dev/null || echo '0.0.0')}"
# Available variants (rust not yet in flake)
export VARIANTS="${VARIANTS:-minimal base k8s python node go full hacker}"

# Architecture
export ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/' | sed 's/arm64/arm64/')

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

log_info() { echo -e "${CYAN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Print config if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Release Configuration:"
  echo "  GITHUB_REPO: ${GITHUB_REPO}"
  echo "  REGISTRY:    ${REGISTRY}"
  echo "  IMAGE_NAME:  ${IMAGE_NAME}"
  echo "  FULL_IMAGE:  ${FULL_IMAGE}"
  echo "  VERSION:     ${VERSION}"
  echo "  ARCH:        ${ARCH}"
  echo "  VARIANTS:    ${VARIANTS}"
fi
