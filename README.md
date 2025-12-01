# Catalyst Development Images

> Reproducible development environment images built with Nix, orchestrated with Tilt.

```
   ██████╗ █████╗ ████████╗ █████╗ ██╗  ██╗   ██╗███████╗████████╗
  ██╔════╝██╔══██╗╚══██╔══╝██╔══██╗██║  ╚██╗ ██╔╝██╔════╝╚══██╔══╝
  ██║     ███████║   ██║   ███████║██║   ╚████╔╝ ███████╗   ██║
  ██║     ██╔══██║   ██║   ██╔══██║██║    ╚██╔╝  ╚════██║   ██║
  ╚██████╗██║  ██║   ██║   ██║  ██║███████╗██║   ███████║   ██║
   ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝   ╚══════╝   ╚═╝
```

<!-- Build & Release -->
[![Release](https://img.shields.io/github/v/release/TheBranchDriftCatalyst/catalyst-images?style=flat-square&logo=github&label=Release&color=blue)](https://github.com/TheBranchDriftCatalyst/catalyst-images/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/TheBranchDriftCatalyst/catalyst-images/release.yml?style=flat-square&logo=githubactions&logoColor=white&label=CI)](https://github.com/TheBranchDriftCatalyst/catalyst-images/actions)
[![Nix Flake](https://img.shields.io/badge/Nix-Flake-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)

<!-- Package & Registry -->
[![GHCR](https://img.shields.io/badge/GHCR-catalyst--images-blue?style=flat-square&logo=github&logoColor=white)](https://github.com/TheBranchDriftCatalyst/catalyst-images/pkgs/container/catalyst-images)
[![Docker Pulls](https://img.shields.io/badge/dynamic/json?style=flat-square&logo=docker&logoColor=white&label=Pulls&query=$.pull_count&url=https://ghcr.io/v2/thebranchdriftcatalyst/catalyst-images/manifests/latest&color=2496ED)](https://github.com/TheBranchDriftCatalyst/catalyst-images/pkgs/container/catalyst-images)
[![Multi-Arch](https://img.shields.io/badge/Arch-amd64%20%7C%20arm64-orange?style=flat-square&logo=linux&logoColor=white)](https://github.com/TheBranchDriftCatalyst/catalyst-images/pkgs/container/catalyst-images)

<!-- Repository Stats -->
[![Stars](https://img.shields.io/github/stars/TheBranchDriftCatalyst/catalyst-images?style=flat-square&logo=github&label=Stars&color=yellow)](https://github.com/TheBranchDriftCatalyst/catalyst-images/stargazers)
[![Forks](https://img.shields.io/github/forks/TheBranchDriftCatalyst/catalyst-images?style=flat-square&logo=github&label=Forks)](https://github.com/TheBranchDriftCatalyst/catalyst-images/network/members)
[![Issues](https://img.shields.io/github/issues/TheBranchDriftCatalyst/catalyst-images?style=flat-square&logo=github&label=Issues)](https://github.com/TheBranchDriftCatalyst/catalyst-images/issues)
[![PRs](https://img.shields.io/github/issues-pr/TheBranchDriftCatalyst/catalyst-images?style=flat-square&logo=github&label=PRs)](https://github.com/TheBranchDriftCatalyst/catalyst-images/pulls)

<!-- Activity & Quality -->
[![Last Commit](https://img.shields.io/github/last-commit/TheBranchDriftCatalyst/catalyst-images?style=flat-square&logo=git&logoColor=white&label=Last%20Commit)](https://github.com/TheBranchDriftCatalyst/catalyst-images/commits/main)
[![Commits](https://img.shields.io/github/commit-activity/m/TheBranchDriftCatalyst/catalyst-images?style=flat-square&logo=git&logoColor=white&label=Commits)](https://github.com/TheBranchDriftCatalyst/catalyst-images/commits/main)
[![License](https://img.shields.io/github/license/TheBranchDriftCatalyst/catalyst-images?style=flat-square&label=License)](LICENSE)
[![Conventional Commits](https://img.shields.io/badge/Commits-Conventional-FE5196?style=flat-square&logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)

<!-- Tech Stack -->
[![Nix](https://img.shields.io/badge/Nix-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://docker.com)
[![ZSH](https://img.shields.io/badge/ZSH-121011?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.zsh.org/)
[![Starship](https://img.shields.io/badge/Starship-DD0B78?style=flat-square&logo=starship&logoColor=white)](https://starship.rs)
[![Taskfile](https://img.shields.io/badge/Taskfile-29BEB0?style=flat-square&logo=task&logoColor=white)](https://taskfile.dev)
[![Tilt](https://img.shields.io/badge/Tilt-0052FF?style=flat-square&logo=tilt&logoColor=white)](https://tilt.dev)

<!-- Languages in Images -->
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Node.js](https://img.shields.io/badge/Node.js-20-339933?style=flat-square&logo=node.js&logoColor=white)](https://nodejs.org)
[![Go](https://img.shields.io/badge/Go-1.21-00ADD8?style=flat-square&logo=go&logoColor=white)](https://golang.org)
[![Rust](https://img.shields.io/badge/Rust-stable-000000?style=flat-square&logo=rust&logoColor=white)](https://rust-lang.org)

## Features

- **Nix-based builds** - Reproducible, declarative Docker images
- **Multiple variants** - From minimal to full-stack development
- **Cross-platform** - Build Linux images on macOS (ARM/x86)
- **Modern shell** - ZSH + Starship with synthwave styling
- **Debug mode** - Built-in debugging for Python, Node, Go
- **Taskfile automation** - Consistent build, test, release workflow
- **Git hooks** - Conventional commits with lefthook

## Quick Start

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- [Docker](https://docs.docker.com/get-docker/)
- [Task](https://taskfile.dev/installation/) (go-task)
- [Lefthook](https://github.com/evilmartians/lefthook) (optional, for git hooks)

### Installation

```bash
# Clone the repository
git clone https://github.com/TheBranchDriftCatalyst/catalyst-images.git
cd catalyst-images

# Install dependencies and git hooks
task setup

# Build the base image
task build:base

# Run interactive shell
task shell
```

## Project Structure

```
catalyst-images/
├── README.md           # This file
├── VERSION             # Semantic version (1.0.0)
├── Taskfile.yml        # Task automation
├── Tiltfile            # Local development orchestration
├── lefthook.yml        # Git hooks configuration
│
└── nix/                # Nix flake (source of truth)
    ├── flake.nix       # Package definitions & Docker images
    ├── flake.lock      # Pinned dependencies
    └── configs/        # Shell configurations
        ├── zshrc           # ZSH config with functions & aliases
        └── starship.toml   # Prompt configuration
```

## Taskfile Commands

### Setup & Dependencies

```bash
task setup          # Install all dependencies and git hooks
task deps           # Install Nix and verify tools
task hooks          # Install lefthook git hooks
```

### Building

```bash
task build          # Build all image variants
task build:base     # Build base variant
task build:full     # Build full variant
task build:variant VARIANT=python  # Build specific variant
```

### Development

```bash
task dev            # Start Tilt development environment
task dev:down       # Stop Tilt
task shell          # Run interactive shell in container
task shell:debug    # Run shell with debug mode enabled
```

### Testing & Linting

```bash
task lint           # Run all linters (Nix + shell)
task lint:nix       # Lint Nix files only
task lint:shell     # Lint shell scripts with shellcheck
task test           # Run image tests
```

### Release & Publishing

```bash
task release VERSION=1.1.0   # Create a new release
task publish                  # Publish all variants to registry
task publish:variant VARIANT=base  # Publish specific variant
```

### Cleanup

```bash
task clean          # Clean build artifacts
task clean:nix      # Remove Nix result symlinks
task clean:docker   # Prune Docker cache
task clean:all      # Deep clean including Nix GC
```

## Image Variants

All images are tagged with both variant name and version:
- `catalyst-images:base` (latest)
- `catalyst-images:base-1.0.0` (versioned)

| Variant | Description | Includes |
|---------|-------------|----------|
| `minimal` | Bare essentials | zsh, coreutils, git, curl |
| `base` | Standard development | + starship, fzf, ripgrep, bat, fd, neovim |
| `k8s` | Kubernetes tools | + kubectl, k9s, helm, kustomize, stern |
| `python` | Python development | + python 3.12, poetry, ruff, pyright |
| `node` | Node.js development | + node 20, npm, yarn, pnpm, typescript |
| `go` | Go development | + go, gopls, golangci-lint, air |
| `rust` | Rust development | + rustup |
| `full` | Everything | All of the above |

## Shell Environment

The container shell includes:

### Modern CLI Aliases

```bash
ls      # eza with directories first
l, ll   # eza long format
la      # eza with git status
lt      # eza tree view
cat     # bat with syntax highlighting
grep    # ripgrep
find    # fd
```

### Global Aliases (Pipe Modifiers)

```bash
command L   # | less
command G   # | grep
command X   # | xargs
command N   # >/dev/null 2>&1
command F   # | fzf
command H   # | head
command T   # | tail
```

### Utility Functions

```bash
ffind       # Find files with fzf preview
tfind       # Find text in files with fzf
dexec       # Docker exec with shell detection
glog        # Git log with fzf preview
tre         # Tree with sensible defaults
serve       # Quick HTTP server
mkd         # mkdir && cd
```

## Debug Mode

Enable debugging by setting `CATALYST_DEBUG=1`:

```bash
# Via docker run
docker run -e CATALYST_DEBUG=1 -p 9229:9229 catalyst-images:base

# Via task
task shell:debug
```

Debug mode enables:
- **Python**: `PYTHONUNBUFFERED=1`, debugpy ready
- **Node.js**: `--inspect=0.0.0.0:9229`
- **Go**: `GODEBUG=gctrace=1`
- **General**: `DEBUG=*`, `VERBOSE=1`

For shell command tracing, also set `CATALYST_DEBUG_TRACE=1`.

## Multi-Architecture Builds

Build for multiple architectures:

```bash
# Build for current arch with arch suffix
task build:multiarch VARIANT=base

# Creates: catalyst-images:base-1.0.0-arm64 (or -amd64)
```

## Git Hooks (Lefthook)

The repository uses lefthook for git hooks:

### Pre-commit
- Nix flake check
- Shellcheck for shell scripts
- Trailing whitespace removal

### Commit Message
- Conventional commits enforcement
- Format: `type(scope): message`
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert

### Pre-push
- Image test verification

## Tilt Development

For rapid iteration with live reload:

```bash
# Start Tilt
task dev
# or: tilt up

# Open Tilt UI
open http://localhost:10350

# Trigger specific builds
tilt trigger catalyst-images-base

# View logs
tilt logs -f

# Stop
task dev:down
```

## Using in Your Projects

### As Base Image

```dockerfile
FROM ghcr.io/thebranchdriftcatalyst/catalyst-images:node-1.0.0

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["npm", "start"]
```

### As Devcontainer

```json
{
  "image": "ghcr.io/thebranchdriftcatalyst/catalyst-images:full-1.0.0",
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh"
      }
    }
  }
}
```

### Native Nix Shell

```bash
# Enter development shell without Docker
cd nix
nix develop          # Full profile
nix develop .#base   # Base profile
nix develop .#python # Python profile
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CATALYST_ENV` | `docker` | Environment type (docker/nix-shell) |
| `CATALYST_VARIANT` | varies | Image variant name |
| `CATALYST_DEBUG` | unset | Enable debug mode |
| `CATALYST_DEBUG_TRACE` | unset | Enable shell tracing |
| `CONTAINER` | `catalyst-images` | Container display name |

## Publishing

Images are published to GitHub Container Registry:

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Publish all variants
task publish

# Publish specific variant
task publish:variant VARIANT=base
```

Registry: `ghcr.io/thebranchdriftcatalyst/catalyst-images`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following conventional commits
4. Run `task lint` and `task test`
5. Submit a pull request

## Related Projects

- **catalyst-imagesspace** - Parent workspace
- **@dotfiles-2024** - Dotfile configurations sourced in zshrc
- **talos-homelab** - Kubernetes cluster using these images

## License

MIT

---

**Run `task setup && task build:base && task shell` to get started!**
