# catalyst-nix

> Single source of truth for the Catalyst development environment.
> Define once in Nix, deploy everywhere.

```
     ██████╗ █████╗ ████████╗ █████╗ ██╗  ██╗   ██╗███████╗████████╗    ███╗   ██╗██╗██╗  ██╗
    ██╔════╝██╔══██╗╚══██╔══╝██╔══██╗██║  ╚██╗ ██╔╝██╔════╝╚══██╔══╝    ████╗  ██║██║╚██╗██╔╝
    ██║     ███████║   ██║   ███████║██║   ╚████╔╝ ███████╗   ██║       ██╔██╗ ██║██║ ╚███╔╝
    ██║     ██╔══██║   ██║   ██╔══██║██║    ╚██╔╝  ╚════██║   ██║       ██║╚██╗██║██║ ██╔██╗
    ╚██████╗██║  ██║   ██║   ██║  ██║███████╗██║   ███████║   ██║       ██║ ╚████║██║██╔╝ ██╗
     ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝   ╚══════╝   ╚═╝       ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝
```

## Philosophy

**DRY principle applied to development environments:**

1. **Nix = Source of Truth** - All packages, configs, and shell setup defined in Nix
2. **Multiple Outputs** - Generate Docker images and native dev shells from single definition
3. **Reproducibility** - Byte-for-byte identical environments across machines
4. **Layered Architecture** - Compose minimal bases into full-featured dev environments

## Architecture

```
                                 ┌─────────────────────┐
                                 │       flake.nix     │
                                 │   (Source of Truth) │
                                 └──────────┬──────────┘
                                            │
               ┌────────────────────────────┼────────────────────────────┐
               │                            │                            │
               ▼                            ▼                            ▼
    ┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
    │  Docker Images   │        │   Nix Dev Shells │        │ Tilt Orchestration│
    │ nix build .#docker-* │    │  nix develop .#* │        │    tilt up       │
    └──────────────────┘        └──────────────────┘        └──────────────────┘
```

## Image Variants

| Tag | Base | Tools Added |
|-----|------|-------------|
| `minimal` | - | zsh, starship, coreutils, eza, bat, fd, ripgrep, fzf, curl, git, jq |
| `base` | minimal | lazygit, delta, gh, neovim, fx, gron |
| `k8s` | base | kubectl, kubectx, k9s, helm, kustomize, kubeseal, stern |
| `python` | base | python3.12, poetry, ruff, pyright, pip, virtualenv |
| `node` | base | node20, npm, yarn, pnpm, typescript, ts-language-server |
| `go` | base | go, gopls, gotools, golangci-lint, air |
| `rust` | base | rustup |
| `full` | base | k8s + python + node + go (everything except rust) |

## File Structure

```
nix/
├── flake.nix           # Main flake - defines ALL packages and outputs
├── flake.lock          # Locked dependencies
├── README.md           # This file
├── configs/
│   └── starship.toml   # Starship prompt (cyberpunk theme)
└── result-*            # Build output symlinks (gitignored)
```

## Usage

### Native Development Shell

```bash
# Enter full development environment
nix develop

# Enter specific profile
nix develop .#base
nix develop .#python
nix develop .#k8s
nix develop .#node
nix develop .#go
nix develop .#rust
```

### Build Docker Images

```bash
# Build specific variant (streamLayeredImage outputs a script)
nix build .#docker-base
./result | docker load

# Build all variants
for variant in base k8s python node full; do
  nix build .#docker-$variant --out-link result-$variant
  ./result-$variant | docker load
done
```

> **Note**: We use `streamLayeredImage` which outputs a script that streams
> the image layers directly to Docker. This enables cross-platform builds
> (macOS → Linux containers) without needing a Linux builder.

### Via Tilt (Recommended)

```bash
# From repository root
tilt up

# Use nav buttons or trigger manually:
tilt trigger docker-base
tilt trigger docker-all
```

## Core Tools (All Variants)

### Shell & Navigation
- `zsh` - Primary shell
- `starship` - Cyberpunk prompt with git/docker/k8s awareness
- `tmux` - Session persistence

### Modern CLI Replacements
| Classic | Modern | Purpose |
|---------|--------|---------|
| `ls` | `eza` | File listing with git status |
| `cat` | `bat` | Syntax highlighting |
| `find` | `fd` | Fast file finder |
| `grep` | `ripgrep` (rg) | Fast search |
| `diff` | `delta` | Better diffs |

### Data Processing
- `jq` - JSON processor
- `yq-go` - YAML processor
- `fx` - Interactive JSON viewer
- `gron` - Greppable JSON

### Git & Version Control
- `git` + `git-lfs`
- `lazygit` - Terminal UI
- `gh` - GitHub CLI
- `delta` - Diff viewer

## Starship Prompt

The included `configs/starship.toml` provides:
- Neon cyan directories
- Hot pink git branch
- Memory usage indicator
- Docker/K8s context awareness
- Git status with emoji indicators
- Rocket success / explosion error symbols

## Environment Variables (in Docker images)

```
SHELL=/bin/zsh
EDITOR=nvim
TERM=xterm-256color
LANG=en_US.UTF-8
STARSHIP_CONFIG=/etc/starship.toml
CATALYST_ENV=docker
CATALYST_VARIANT=<variant>
CONTAINER=catalyst-images
```

## Layer Caching

The flake uses `buildLayeredImage` with `maxLayers = 125` for optimal Docker layer caching:
- Packages are cached in `/nix/store` and reused across variants
- Each image shares common base layers
- Rebuilds only regenerate changed layers

## Adding New Packages

Edit `flake.nix` and add to the appropriate tool set:

```nix
# For all base variants
coreTools = with pkgs; [
  # ... existing tools
  your-new-tool
];

# For specific variant
pythonTools = with pkgs; [
  # ... existing tools
  python312Packages.your-package
];
```

Then rebuild: `nix build .#docker-<variant>`

## Quick Reference

```bash
# Check flake validity
nix flake check

# Update dependencies
nix flake update

# Enter shell
nix develop

# Build image
nix build .#docker-full
docker load < result

# Garbage collect old builds
nix-collect-garbage -d
```

---

**Built with Nix flakes for reproducible, composable development environments.**
