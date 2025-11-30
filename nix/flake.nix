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
          full = coreTools p ++ gitTools p ++ dataTools p ++ editorTools p ++ k8sTools p ++ pythonTools p ++ nodeTools p ++ goTools p;
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
            name = "catalyst-dev";
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
                "CONTAINER=catalyst-dev"
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

          # Default package
          default = self.packages.${system}.docker-full;
        };

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
