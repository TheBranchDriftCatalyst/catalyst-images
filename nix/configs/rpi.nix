# Raspberry Pi NixOS Configuration
#
# Usage (requires Linux or remote builder):
#   nix run github:nix-community/nixos-generators -- \
#     --format sd-aarch64 \
#     --system aarch64-linux \
#     -c ./configs/rpi.nix
#
# Or with raspberry-pi-nix:
#   nix build .#nixosConfigurations.catalyst-rpi4.config.system.build.sdImage
#
{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # System Configuration
  # ============================================================================

  system.stateVersion = "24.05";

  networking.hostName = "catalyst-pi";
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";

  # ============================================================================
  # Boot Configuration (for Raspberry Pi)
  # ============================================================================

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # For Pi 4, allocate more CMA for GPU
  boot.kernelParams = [ "cma=128M" ];

  # ============================================================================
  # Users
  # ============================================================================

  users.users.catalyst = {
    isNormalUser = true;
    description = "Catalyst User";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.zsh;
    # Set a password or use SSH keys
    # hashedPassword = "...";  # Generate with: mkpasswd -m sha-512
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here
      # "ssh-ed25519 AAAA... user@host"
    ];
  };

  # Allow passwordless sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # ============================================================================
  # Services
  # ============================================================================

  # SSH access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Docker
  virtualisation.docker.enable = true;

  # ============================================================================
  # Catalyst Development Environment
  # ============================================================================

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    # Shell
    zsh
    starship
    tmux

    # Modern coreutils
    eza
    bat
    fd
    ripgrep
    fzf

    # Git
    git
    lazygit
    gh
    delta

    # Data processing
    jq
    yq-go
    fx

    # Editor
    neovim

    # System monitoring
    htop
    btop
    ncdu

    # Network
    curl
    wget
    nmap
    mtr

    # Container tools
    docker
    docker-compose

    # System info
    neofetch
    fastfetch
  ];

  # Starship prompt configuration
  environment.etc."starship.toml".source = ./starship.toml;

  # Global zsh configuration
  environment.etc."zshrc".source = ./zshrc;

  # ============================================================================
  # System Settings
  # ============================================================================

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Enable zram swap (good for Pi with limited RAM)
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;
}
