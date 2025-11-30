# catalyst-nix/flake.nix
#
# Single source of truth for the Catalyst development environment.
# Outputs: Docker images (Linux), dev shells (native)
#
{
  description = "Catalyst Development Environment - Nix Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Home-manager for user config management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS generators for SD card, ISO, VM, cloud images
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Raspberry Pi support
    raspberry-pi-nix = {
      url = "github:nix-community/raspberry-pi-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, home-manager, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Native pkgs for dev shells (runs on your actual machine)
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Linux pkgs for Docker images (cross-compile if on macOS)
        # Docker always runs Linux containers, so we need Linux binaries
        linuxSystem = if pkgs.stdenv.isDarwin then
          (if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64-linux" else "x86_64-linux")
        else
          system;

        pkgsLinux = import nixpkgs {
          system = linuxSystem;
          config.allowUnfree = true;
        };

        # ==================================================================
        # Package Sets - Modular tool collections
        # These use native pkgs for dev shells
        # ==================================================================

        # Core CLI tools - the essentials
        coreTools = p: with p; [
          # Shell
          zsh
          bash
          starship
          tmux

          # Modern coreutils
          coreutils
          findutils
          gnugrep
          gnused
          gawk
          moreutils
          hostname           # for container hostname

          # File tools
          eza           # modern ls (exa successor)
          bat           # modern cat
          fd            # modern find
          tree
          file
          unzip
          p7zip
          gzip

          # Search
          ripgrep
          fzf

          # Process
          htop
          procs

          # Misc
          curl
          wget
          git
          jq
          yq-go
        ];

        # Git & version control tools
        gitTools = p: with p; [
          git
          git-lfs
          lazygit
          delta         # better diff
          gh            # GitHub CLI
          gron          # greppable JSON
        ];

        # JSON/YAML processing
        dataTools = p: with p; [
          jq
          yq-go
          fx            # interactive JSON
          gron
        ];

        # Kubernetes tools
        k8sTools = p: with p; [
          kubectl
          kubectx
          k9s
          kubernetes-helm
          kustomize
          kubeseal
          stern         # multi-pod logs
        ];

        # Python development
        pythonTools = p: with p; [
          python312
          python312Packages.pip
          python312Packages.virtualenv
          poetry
          ruff
          pyright
        ];

        # Node.js development
        nodeTools = p: with p; [
          nodejs_20
          nodePackages.npm
          nodePackages.yarn
          nodePackages.pnpm
          nodePackages.typescript
          nodePackages.typescript-language-server
        ];

        # Go development
        goTools = p: with p; [
          go
          gopls
          gotools
          golangci-lint
          air           # live reload
        ];

        # Rust development
        rustTools = p: with p; [
          rustup
        ];

        # Editor (Neovim)
        editorTools = p: with p; [
          neovim
        ];

        # ==================================================================
        # Hacker Dashboard Tools - Elite terminal experience
        # ==================================================================

        # System monitoring - see everything
        monitoringTools = p: with p; [
          btop            # Beautiful system monitor (htop on steroids)
          bottom          # Cross-platform graphical process/system monitor
          ncdu            # Interactive disk usage analyzer
          iotop           # IO disk monitoring
          bandwhich       # Terminal bandwidth utilization by process
          nethogs         # Net top - bandwidth per process
          iftop           # Network interface monitoring
          nload           # Real-time network usage
        ];

        # Network security & diagnostics
        networkTools = p: with p; [
          nmap            # Network mapper / security scanner
          mtr             # My Traceroute - network diagnostic
          dig             # DNS lookup (from bind)
          whois           # Domain lookup
          tcpdump         # Packet capture
          netcat-gnu      # Network swiss army knife
          socat           # Multipurpose relay
          ipcalc          # IP address calculator
        ];

        # HTTP & API tools
        httpTools = p: with p; [
          httpie          # Human-friendly HTTP client
          curlie          # curl + httpie = speed + readability
          xh              # Faster httpie alternative (Rust)
          grpcurl         # gRPC command-line client
          websocat        # WebSocket client
        ];

        # File management TUIs
        fileManagerTools = p: with p; [
          ranger          # VIM-inspired file manager
          lf              # Terminal file manager (Go, fast)
          yazi            # Async terminal file manager (Rust, fastest)
          broot           # A better way to navigate directories
        ];

        # Markdown & documentation
        docTools = p: with p; [
          glow            # Render markdown in terminal with style
          mdcat           # Show markdown files in terminal
          pandoc          # Universal document converter
        ];

        # Advanced data tools
        advancedDataTools = p: with p; [
          visidata        # Interactive multitool for tabular data
          miller          # Like awk, sed, cut, join for CSV/JSON/etc
          dasel           # Query and modify data structures
          htmlq           # Like jq but for HTML
          qsv             # Fast CSV toolkit (xsv fork)
        ];

        # System info & aesthetics
        sysInfoTools = p: with p; [
          neofetch        # System information display
          fastfetch       # Faster neofetch (C++)
          onefetch        # Git repository summary
          cpufetch        # CPU architecture fetcher
          lsd             # LSDeluxe - modern ls with icons
        ];

        # Security & crypto tools
        securityTools = p: with p; [
          openssl         # Crypto toolkit
          gnupg           # GPG encryption
          age             # Simple, modern encryption
          sops            # Secrets management
          pass            # Password manager
          pwgen           # Password generator
        ];

        # Process & container debugging
        debugTools = p: with p; [
          strace          # System call tracer
          ltrace          # Library call tracer
          lsof            # List open files
          pstree          # Process tree
          dive            # Docker image layer explorer
        ];

        # Git extras
        gitExtraTools = p: with p; [
          gitui           # Blazing fast Git TUI (Rust)
          tig             # Text interface for Git
          git-absorb      # Auto-squash fixups
          git-crypt       # Encrypt files in git
          pre-commit      # Git pre-commit hooks
        ];

        # Terminal multiplexing & productivity
        productivityTools = p: with p; [
          zellij          # Modern terminal multiplexer (Rust)
          # tmux already in coreTools
          direnv          # Directory-based env vars
          watchexec       # Execute on file changes
          entr            # Run commands when files change
          pv              # Pipe viewer - monitor data flow
          parallel        # GNU Parallel - shell job parallelization
        ];

        # Fun & aesthetics
        funTools = p: with p; [
          cmatrix         # Matrix-style animation
          pipes           # Animated pipes terminal screensaver
          sl              # Steam locomotive for typos
          cowsay          # Cow says moo
          figlet          # ASCII art text
          lolcat          # Rainbow text
          asciiquarium    # Aquarium in terminal
        ];

        # ==================================================================
        # Profile Combinations (parameterized by pkgs)
        # ==================================================================

        mkProfiles = p: {
          minimal = coreTools p;
          base = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p;
          k8s = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p ++ k8sTools p;
          python = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p ++ pythonTools p;
          node = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p ++ nodeTools p;
          go = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p ++ goTools p;
          rust = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p ++ rustTools p;

          # Hacker dashboard - elite terminal tools for power users
          hacker = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p
            ++ monitoringTools p
            ++ networkTools p
            ++ httpTools p
            ++ fileManagerTools p
            ++ docTools p
            ++ advancedDataTools p
            ++ sysInfoTools p
            ++ securityTools p
            ++ debugTools p
            ++ gitExtraTools p
            ++ productivityTools p
            ++ funTools p;

          # Full = development + hacker + all languages
          full = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p
            ++ k8sTools p ++ pythonTools p ++ nodeTools p ++ goTools p
            ++ monitoringTools p
            ++ networkTools p
            ++ httpTools p
            ++ fileManagerTools p
            ++ docTools p
            ++ advancedDataTools p
            ++ sysInfoTools p
            ++ securityTools p
            ++ debugTools p
            ++ gitExtraTools p
            ++ productivityTools p;
            # Note: funTools excluded from full to keep size reasonable
        };

        # Native profiles for dev shells
        profiles = mkProfiles pkgs;

        # Linux profiles for Docker images
        linuxProfiles = mkProfiles pkgsLinux;

        # ==================================================================
        # Shell Configuration (for native dev shells)
        # ==================================================================

        shellHook = ''
          # Set up starship prompt
          export STARSHIP_CONFIG="${./configs/starship.toml}"
          eval "$(starship init zsh)"

          # Set default editor
          export EDITOR=nvim
          export VISUAL=nvim

          # Catalyst environment marker
          export CATALYST_ENV="nix-shell"
          export CONTAINER="catalyst-nix"

          # Modern aliases
          alias ls='eza --group-directories-first'
          alias l='eza -la --group-directories-first'
          alias ll='eza -l --group-directories-first'
          alias la='eza -la --group-directories-first --git'
          alias lt='eza --tree --level=2'
          alias cat='bat --paging=never'
          alias grep='rg'
          alias find='fd'

          echo ""
          echo "╔═══════════════════════════════════════════════════════════════╗"
          echo "║                    Catalyst Development Shell                  ║"
          echo "╠═══════════════════════════════════════════════════════════════╣"
          echo "║  Profile: $CATALYST_PROFILE                                   ║"
          echo "║  Tools:   starship, eza, bat, fzf, ripgrep, fd, jq           ║"
          echo "╚═══════════════════════════════════════════════════════════════╝"
          echo ""
        '';

        # ==================================================================
        # Docker Image Builder
        # ==================================================================
        #
        # NOTE: We use native pkgs.dockerTools (runs on host machine) but with
        # Linux package contents from pkgsLinux. This allows building Docker
        # images on macOS without needing a Linux builder.
        #
        # The dockerTools derivation runs on the host, but the IMAGE CONTENTS
        # are Linux binaries from pkgsLinux.

        mkDockerImage = { name, profile, tag ? "latest" }:
          pkgs.dockerTools.streamLayeredImage {
            name = "catalyst-images";
            tag = tag;

            # IMPORTANT: Use Linux packages as contents
            contents = [
              pkgsLinux.bashInteractive
              pkgsLinux.coreutils
              pkgsLinux.cacert
              # Locale support for Unicode/emoji in terminal
              pkgsLinux.glibcLocales
            ] ++ profile;

            # Maximize layer count for better caching granularity
            maxLayers = 125;

            config = {
              Env = [
                "SHELL=/bin/zsh"
                "EDITOR=nvim"
                "TERM=xterm-256color"
                "LANG=en_US.UTF-8"
                "LC_ALL=en_US.UTF-8"
                "LOCALE_ARCHIVE=${pkgsLinux.glibcLocales}/lib/locale/locale-archive"
                "STARSHIP_CONFIG=/etc/starship.toml"
                "CATALYST_ENV=docker"
                "CONTAINER=catalyst-images"
                "CATALYST_VARIANT=${tag}"
              ];
              Cmd = [ "/bin/zsh" ];
              WorkingDir = "/workspace";
              Volumes = {
                "/workspace" = {};
              };
              Labels = {
                "org.opencontainers.image.source" = "https://github.com/TheBranchDriftCatalyst/catalyst-images";
                "org.opencontainers.image.description" = "Catalyst Development Environment - ${tag}";
                "dev.catalyst.variant" = tag;
              };
            };

            # Copy configs into image
            extraCommands = ''
              mkdir -p etc
              cp ${./configs/starship.toml} etc/starship.toml

              # Create global zshrc that initializes starship
              cp ${./configs/zshrc} etc/zshrc

              # Also create /etc/zsh/zshrc for some zsh builds
              mkdir -p etc/zsh
              cp ${./configs/zshrc} etc/zsh/zshrc

              # Set a proper hostname for the container
              echo "catalyst-${tag}" > etc/hostname
            '';
          };

      in
      {
        # ==================================================================
        # Development Shells (native - run on your machine)
        # ==================================================================

        devShells = {
          default = pkgs.mkShell {
            buildInputs = profiles.full;
            inherit shellHook;
            CATALYST_PROFILE = "full";
          };

          minimal = pkgs.mkShell {
            buildInputs = profiles.minimal;
            inherit shellHook;
            CATALYST_PROFILE = "minimal";
          };

          base = pkgs.mkShell {
            buildInputs = profiles.base;
            inherit shellHook;
            CATALYST_PROFILE = "base";
          };

          k8s = pkgs.mkShell {
            buildInputs = profiles.k8s;
            inherit shellHook;
            CATALYST_PROFILE = "k8s";
          };

          python = pkgs.mkShell {
            buildInputs = profiles.python;
            inherit shellHook;
            CATALYST_PROFILE = "python";
          };

          node = pkgs.mkShell {
            buildInputs = profiles.node;
            inherit shellHook;
            CATALYST_PROFILE = "node";
          };

          go = pkgs.mkShell {
            buildInputs = profiles.go;
            inherit shellHook;
            CATALYST_PROFILE = "go";
          };

          rust = pkgs.mkShell {
            buildInputs = profiles.rust;
            inherit shellHook;
            CATALYST_PROFILE = "rust";
          };

          hacker = pkgs.mkShell {
            buildInputs = profiles.hacker;
            inherit shellHook;
            CATALYST_PROFILE = "hacker";
          };
        };

        # ==================================================================
        # Docker Images (Linux - for Docker containers)
        # ==================================================================

        packages = {
          docker-minimal = mkDockerImage {
            name = "minimal";
            profile = linuxProfiles.minimal;
            tag = "minimal";
          };

          docker-base = mkDockerImage {
            name = "base";
            profile = linuxProfiles.base;
            tag = "base";
          };

          docker-k8s = mkDockerImage {
            name = "k8s";
            profile = linuxProfiles.k8s;
            tag = "k8s";
          };

          docker-python = mkDockerImage {
            name = "python";
            profile = linuxProfiles.python;
            tag = "python";
          };

          docker-node = mkDockerImage {
            name = "node";
            profile = linuxProfiles.node;
            tag = "node";
          };

          docker-go = mkDockerImage {
            name = "go";
            profile = linuxProfiles.go;
            tag = "go";
          };

          docker-full = mkDockerImage {
            name = "full";
            profile = linuxProfiles.full;
            tag = "full";
          };

          # Hacker dashboard - elite terminal tools
          docker-hacker = mkDockerImage {
            name = "hacker";
            profile = linuxProfiles.hacker;
            tag = "hacker";
          };

          # Default package
          default = self.packages.${system}.docker-full;
        };

        # ==================================================================
        # NixOS System Images (Raspberry Pi, VMs, Cloud)
        # ==================================================================
        #
        # These require building on Linux or using a remote builder.
        # Build with: nix build .#nixosConfigurations.catalyst-rpi4.config.system.build.sdImage
        #
        # For now, we expose the nixos-generators as a reference.
        # Full implementation requires:
        #   1. Linux builder (or remote builder from macOS)
        #   2. nixos-generators integration
        #
        # Example usage (from Linux):
        #   nix run github:nix-community/nixos-generators -- \
        #     --format sd-aarch64 \
        #     --system aarch64-linux \
        #     -c ./configs/rpi.nix
        #
        # Supported formats via nixos-generators:
        #   - sd-aarch64          : Raspberry Pi SD card image
        #   - sd-aarch64-installer: RPi installer with interactive setup
        #   - iso                 : Bootable ISO image
        #   - qcow2               : QEMU/KVM virtual machine
        #   - virtualbox          : VirtualBox OVA
        #   - vmware              : VMware VMDK
        #   - amazon              : AWS EC2 AMI
        #   - azure               : Azure VHD
        #   - gce                 : Google Compute Engine
        #   - digitalocean        : DigitalOcean droplet image
        #

        # ==================================================================
        # Checks
        # ==================================================================

        checks = {
          # Verify shell configurations work (native)
          shell-test = pkgs.runCommand "shell-test" {
            buildInputs = profiles.base;
          } ''
            # Test that core tools are available
            zsh --version
            starship --version
            eza --version
            bat --version
            rg --version
            fd --version
            jq --version
            touch $out
          '';
        };
      }
    );
}
