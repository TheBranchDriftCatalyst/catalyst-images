#!/usr/bin/env bash
# Build Analytics Beacon
#
# Privacy-respecting telemetry for tracking build success/failures.
# Disabled by default - enable via CATALYST_ANALYTICS_ENABLED=1
#
# No user data is collected - only aggregate build metrics:
# - variant name, version, status
# - build duration
# - architecture
# - timestamp
#
# Usage:
#   source scripts/analytics-beacon.sh
#   beacon_start
#   # ... do build ...
#   beacon_end "success" "base"
#

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/release-config.sh" 2>/dev/null || true

# ============================================================================
# Configuration
# ============================================================================

# Disabled by default - opt-in only
export CATALYST_ANALYTICS_ENABLED="${CATALYST_ANALYTICS_ENABLED:-0}"

# Webhook endpoint for build notifications (e.g., Slack, Discord, custom)
export CATALYST_WEBHOOK_URL="${CATALYST_WEBHOOK_URL:-}"

# Analytics endpoint (e.g., Plausible, self-hosted collector)
export CATALYST_ANALYTICS_URL="${CATALYST_ANALYTICS_URL:-}"

# Build ID for correlation
export BUILD_ID="${BUILD_ID:-$(date +%s)-$$}"

# ============================================================================
# Internal State
# ============================================================================

_BEACON_START_TIME=""
_BEACON_VARIANTS_BUILT=()
_BEACON_VARIANTS_FAILED=()

# ============================================================================
# Functions
# ============================================================================

beacon_enabled() {
  [[ "${CATALYST_ANALYTICS_ENABLED}" == "1" ]]
}

beacon_start() {
  _BEACON_START_TIME=$(date +%s)
  _BEACON_VARIANTS_BUILT=()
  _BEACON_VARIANTS_FAILED=()

  if beacon_enabled; then
    log_info "Analytics beacon enabled (BUILD_ID: ${BUILD_ID})"
  fi
}

beacon_record_variant() {
  local variant="$1"
  local status="${2:-success}"

  if [[ "$status" == "success" ]]; then
    _BEACON_VARIANTS_BUILT+=("$variant")
  else
    _BEACON_VARIANTS_FAILED+=("$variant")
  fi
}

beacon_end() {
  local status="${1:-success}"
  local variant="${2:-all}"

  if ! beacon_enabled; then
    return 0
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - _BEACON_START_TIME))

  # Build payload
  local payload
  payload=$(cat <<EOF
{
  "build_id": "${BUILD_ID}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "${status}",
  "version": "${VERSION:-unknown}",
  "variant": "${variant}",
  "variants_built": $(printf '%s\n' "${_BEACON_VARIANTS_BUILT[@]:-}" | jq -R . | jq -s .),
  "variants_failed": $(printf '%s\n' "${_BEACON_VARIANTS_FAILED[@]:-}" | jq -R . | jq -s .),
  "duration_seconds": ${duration},
  "arch": "${ARCH:-unknown}",
  "registry": "${REGISTRY:-unknown}",
  "image": "${FULL_IMAGE:-unknown}"
}
EOF
)

  # Send to analytics endpoint
  if [[ -n "${CATALYST_ANALYTICS_URL}" ]]; then
    curl -X POST "${CATALYST_ANALYTICS_URL}" \
      --data-binary "${payload}" \
      --header "Content-Type: application/json" \
      --max-time 5 \
      --silent \
      --show-error \
      || log_warn "Failed to send analytics"
  fi

  # Send webhook notification
  if [[ -n "${CATALYST_WEBHOOK_URL}" ]]; then
    beacon_send_webhook "${status}" "${variant}" "${duration}"
  fi

  log_info "Build completed: ${status} (${duration}s)"
}

beacon_send_webhook() {
  local status="$1"
  local variant="$2"
  local duration="$3"

  local emoji="✅"
  local color="good"
  if [[ "$status" != "success" ]]; then
    emoji="❌"
    color="danger"
  fi

  # Slack-compatible webhook payload
  local webhook_payload
  webhook_payload=$(cat <<EOF
{
  "attachments": [{
    "color": "${color}",
    "title": "${emoji} Catalyst Build: ${status}",
    "fields": [
      {"title": "Version", "value": "${VERSION:-unknown}", "short": true},
      {"title": "Variant", "value": "${variant}", "short": true},
      {"title": "Duration", "value": "${duration}s", "short": true},
      {"title": "Arch", "value": "${ARCH:-unknown}", "short": true}
    ],
    "footer": "catalyst-images",
    "ts": $(date +%s)
  }]
}
EOF
)

  curl -X POST "${CATALYST_WEBHOOK_URL}" \
    --data-binary "${webhook_payload}" \
    --header "Content-Type: application/json" \
    --max-time 5 \
    --silent \
    --show-error \
    || log_warn "Failed to send webhook"
}

# ============================================================================
# GitHub Actions Integration
# ============================================================================

beacon_github_summary() {
  # Write build summary to GitHub Actions step summary
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat >> "${GITHUB_STEP_SUMMARY}" <<EOF

## 🚀 Build Summary

| Metric | Value |
|--------|-------|
| **Version** | ${VERSION:-unknown} |
| **Variants Built** | ${#_BEACON_VARIANTS_BUILT[@]} |
| **Variants Failed** | ${#_BEACON_VARIANTS_FAILED[@]} |
| **Architecture** | ${ARCH:-unknown} |

### Variants
$(for v in "${_BEACON_VARIANTS_BUILT[@]:-}"; do echo "- ✅ $v"; done)
$(for v in "${_BEACON_VARIANTS_FAILED[@]:-}"; do echo "- ❌ $v"; done)

EOF
  fi
}

# ============================================================================
# Registry Pull Stats
# ============================================================================

beacon_get_pull_stats() {
  # Get pull counts from GHCR (requires gh CLI and appropriate permissions)
  local image="${1:-${IMAGE_NAME}}"

  if ! command -v gh &>/dev/null; then
    log_warn "gh CLI not available for pull stats"
    return 1
  fi

  # GHCR API endpoint for package versions
  local owner="${GITHUB_REPO%%/*}"

  gh api "users/${owner}/packages/container/${image}/versions" \
    --jq '.[] | {tag: .metadata.container.tags[0], downloads: .metadata.package_version_statistics.downloads_count}' \
    2>/dev/null || echo "Pull stats not available"
}

# ============================================================================
# Print config if run directly
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Analytics Beacon Configuration:"
  echo "  CATALYST_ANALYTICS_ENABLED: ${CATALYST_ANALYTICS_ENABLED}"
  echo "  CATALYST_WEBHOOK_URL:       ${CATALYST_WEBHOOK_URL:-<not set>}"
  echo "  CATALYST_ANALYTICS_URL:     ${CATALYST_ANALYTICS_URL:-<not set>}"
  echo ""
  echo "To enable analytics:"
  echo "  export CATALYST_ANALYTICS_ENABLED=1"
  echo "  export CATALYST_WEBHOOK_URL=https://hooks.slack.com/..."
  echo ""
  echo "Usage:"
  echo "  source scripts/analytics-beacon.sh"
  echo "  beacon_start"
  echo "  # ... build ..."
  echo "  beacon_end 'success' 'base'"
fi
