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
- `catalyst-dev:base` (latest)
- `catalyst-dev:base-1.0.0` (versioned)

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
docker run -e CATALYST_DEBUG=1 -p 9229:9229 catalyst-dev:base

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

# Creates: catalyst-dev:base-1.0.0-arm64 (or -amd64)
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
tilt trigger catalyst-dev-base

# View logs
tilt logs -f

# Stop
task dev:down
```

## Using in Your Projects

### As Base Image

```dockerfile
FROM ghcr.io/thebranchdriftcatalyst/catalyst-dev:node-1.0.0

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["npm", "start"]
```

### As Devcontainer

```json
{
  "image": "ghcr.io/thebranchdriftcatalyst/catalyst-dev:full-1.0.0",
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
| `CONTAINER` | `catalyst-dev` | Container display name |

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

Registry: `ghcr.io/thebranchdriftcatalyst/catalyst-dev`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following conventional commits
4. Run `task lint` and `task test`
5. Submit a pull request

## Related Projects

- **catalyst-devspace** - Parent workspace
- **@dotfiles-2024** - Dotfile configurations sourced in zshrc
- **talos-homelab** - Kubernetes cluster using these images

## License

MIT

---

**Run `task setup && task build:base && task shell` to get started!**
