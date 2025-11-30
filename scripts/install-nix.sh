#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Install Nix Package Manager                                                 ║
# ║  Multi-platform installer with flakes enabled by default                     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../scripts/lib/common.sh"

# ══════════════════════════════════════════════════════════════════════════════
# Configuration
# ══════════════════════════════════════════════════════════════════════════════
NIX_VERSION="${NIX_VERSION:-latest}"
ENABLE_FLAKES="${ENABLE_FLAKES:-true}"
INSTALLER="${INSTALLER:-determinate}"  # determinate or official

# ══════════════════════════════════════════════════════════════════════════════
# Banner
# ══════════════════════════════════════════════════════════════════════════════
print_banner "
███╗   ██╗██╗██╗  ██╗    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗
████╗  ██║██║╚██╗██╔╝    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║
██╔██╗ ██║██║ ╚███╔╝     ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║
██║╚██╗██║██║ ██╔██╗     ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║
██║ ╚████║██║██╔╝ ██╗    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝    ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
                         ${ICON_LIGHTNING} Nix Package Manager Installer ${ICON_LIGHTNING}
" "$CYAN"

# ══════════════════════════════════════════════════════════════════════════════
# Pre-flight Checks
# ══════════════════════════════════════════════════════════════════════════════
log_step "1" "Pre-flight Checks"

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"
info "Detected: ${OS} / ${ARCH}"

# Check if Nix is already installed
if command -v nix &>/dev/null; then
  NIX_CURRENT="$(nix --version 2>/dev/null || echo 'unknown')"
  success "Nix is already installed: ${NIX_CURRENT}"

  # Check if flakes are enabled
  if nix flake --help &>/dev/null 2>&1; then
    success "Flakes are enabled"
  else
    warn "Flakes are NOT enabled"
    log_note "Run this script with ENABLE_FLAKES=true to enable"
  fi

  if ! confirm "Nix is already installed. Re-run installation anyway?"; then
    info "Skipping installation"

    # Just verify flakes work
    log_step "2" "Verifying Nix Flakes"
    if [[ "$ENABLE_FLAKES" == "true" ]]; then
      _enable_flakes
    fi

    _print_summary
    exit 0
  fi
fi

# Check for required tools
require_cmds curl || exit 1

# macOS-specific checks
if [[ "$OS" == "Darwin" ]]; then
  info "macOS detected"

  # Check for Rosetta on Apple Silicon
  if [[ "$ARCH" == "arm64" ]]; then
    if ! /usr/bin/pgrep -q oahd; then
      warn "Rosetta 2 may be required for some packages"
      log_note "Install with: softwareupdate --install-rosetta"
    fi
  fi
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# Functions
# ══════════════════════════════════════════════════════════════════════════════

_enable_flakes() {
  local nix_conf_dir
  local nix_conf

  if [[ "$OS" == "Darwin" ]]; then
    nix_conf_dir="$HOME/.config/nix"
    nix_conf="$nix_conf_dir/nix.conf"
  else
    nix_conf_dir="/etc/nix"
    nix_conf="$nix_conf_dir/nix.conf"
  fi

  # Also check user config
  local user_nix_conf="$HOME/.config/nix/nix.conf"

  info "Enabling Nix flakes..."

  # Create user config directory
  mkdir -p "$HOME/.config/nix"

  # Check if already enabled
  if grep -q "experimental-features.*flakes" "$user_nix_conf" 2>/dev/null; then
    success "Flakes already enabled in user config"
    return 0
  fi

  # Add to user config (works without sudo)
  cat >> "$user_nix_conf" << 'EOF'

# Enable flakes and nix-command
experimental-features = nix-command flakes

# Better error messages
show-trace = true

# Trust users for substituters
trusted-users = root @admin @wheel
EOF

  success "Flakes enabled in $user_nix_conf"
}

_install_determinate() {
  info "Using Determinate Systems installer (recommended)"
  log_note "This installer is more reliable on macOS and enables flakes by default"
  echo ""

  # Determinate Systems installer
  # Use --no-confirm for non-interactive install
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
}

_install_official() {
  info "Using official Nix installer"
  echo ""

  if [[ "$OS" == "Darwin" ]]; then
    # macOS multi-user install
    sh <(curl -L https://nixos.org/nix/install) --daemon
  else
    # Linux single-user install (simpler)
    sh <(curl -L https://nixos.org/nix/install) --no-daemon
  fi
}

_source_nix() {
  # Source Nix environment
  if [[ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
    # shellcheck source=/dev/null
    source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  elif [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi

  # Also try the determinate systems location
  if [[ -f "/nix/var/nix/profiles/default/etc/profile.d/nix.sh" ]]; then
    # shellcheck source=/dev/null
    source "/nix/var/nix/profiles/default/etc/profile.d/nix.sh"
  fi
}

_verify_installation() {
  log_step "4" "Verifying Installation"

  _source_nix

  if ! command -v nix &>/dev/null; then
    error "Nix installation failed - 'nix' command not found"
    log_note "Try opening a new terminal and running: nix --version"
    return 1
  fi

  local nix_version
  nix_version="$(nix --version)"
  success "Nix installed: ${nix_version}"

  # Verify flakes work
  info "Testing flakes..."
  if nix flake --help &>/dev/null 2>&1; then
    success "Flakes are working"
  else
    warn "Flakes command not available"
    log_note "You may need to enable them manually"
  fi

  # Test a simple flake operation
  info "Testing flake evaluation..."
  if nix eval --expr "1 + 1" &>/dev/null 2>&1; then
    success "Nix evaluation works"
  else
    warn "Nix evaluation test failed"
  fi

  return 0
}

_print_summary() {
  print_summary "success"

  print_section "NIX INSTALLATION COMPLETE"
  echo ""

  _source_nix

  print_kv "Nix Version" "$(nix --version 2>/dev/null || echo 'N/A')"
  print_kv "Flakes" "$(nix flake --help &>/dev/null 2>&1 && echo 'enabled' || echo 'disabled')"
  print_kv "Config" "$HOME/.config/nix/nix.conf"
  echo ""

  print_section "QUICK START"
  echo ""
  log_note "Open a new terminal, then:"
  echo ""
  echo -e "  ${CYAN}# Enter catalyst-nix dev shell${RESET}"
  echo -e "  cd docker/catalyst-nix"
  echo -e "  nix develop"
  echo ""
  echo -e "  ${CYAN}# Build Docker image via Nix${RESET}"
  echo -e "  nix build .#docker-full"
  echo -e "  docker load < result"
  echo ""
  echo -e "  ${CYAN}# Use Tilt with Nix${RESET}"
  echo -e "  cd docker"
  echo -e "  tilt up"
  echo ""

  print_next_steps \
    "Open a new terminal (to load Nix into PATH)" \
    "Run: cd docker/catalyst-nix && nix develop" \
    "Or run: tilt up (in docker/ directory)"

  echo -e "${GREEN}${BOLD}${EMOJI_PARTY} Nix is ready!${RESET}"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# Installation
# ══════════════════════════════════════════════════════════════════════════════
log_step "2" "Installing Nix"

print_kv "Installer" "$INSTALLER"
print_kv "Enable Flakes" "$ENABLE_FLAKES"
print_kv "OS" "$OS"
print_kv "Arch" "$ARCH"
echo ""

# Check if we're running interactively (needed for sudo)
if [[ ! -t 0 ]]; then
  warn "This script requires an interactive terminal for sudo"
  echo ""
  echo -e "${CYAN}Run this command directly in your terminal:${RESET}"
  echo ""
  echo -e "  ${BOLD}./docker/scripts/install-nix.sh${RESET}"
  echo ""
  echo -e "Or install Nix manually:"
  echo ""
  echo -e "  ${BOLD}curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install${RESET}"
  echo ""
  exit 1
fi

if ! confirm "Proceed with Nix installation?"; then
  warn "Installation cancelled"
  exit 0
fi

echo ""

case "$INSTALLER" in
  determinate)
    _install_determinate
    ;;
  official)
    _install_official
    ;;
  *)
    error "Unknown installer: $INSTALLER"
    exit 1
    ;;
esac

# ══════════════════════════════════════════════════════════════════════════════
# Post-Installation
# ══════════════════════════════════════════════════════════════════════════════
log_step "3" "Post-Installation Configuration"

# Source nix
_source_nix

# Enable flakes
if [[ "$ENABLE_FLAKES" == "true" ]]; then
  _enable_flakes
fi

# ══════════════════════════════════════════════════════════════════════════════
# Verification
# ══════════════════════════════════════════════════════════════════════════════
_verify_installation || exit 1

# ══════════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════════
_print_summary
