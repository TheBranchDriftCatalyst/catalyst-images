# catalyst-dev

> Docker images built from Nix - The Catalyst development environment in container form.

```
     ██████╗ █████╗ ████████╗ █████╗ ██╗  ██╗   ██╗███████╗████████╗    ██████╗ ███████╗██╗   ██╗
    ██╔════╝██╔══██╗╚══██╔══╝██╔══██╗██║  ╚██╗ ██╔╝██╔════╝╚══██╔══╝    ██╔══██╗██╔════╝██║   ██║
    ██║     ███████║   ██║   ███████║██║   ╚████╔╝ ███████╗   ██║       ██║  ██║█████╗  ██║   ██║
    ██║     ██╔══██║   ██║   ██╔══██║██║    ╚██╔╝  ╚════██║   ██║       ██║  ██║██╔══╝  ╚██╗ ██╔╝
    ╚██████╗██║  ██║   ██║   ██║  ██║███████╗██║   ███████║   ██║       ██████╔╝███████╗ ╚████╔╝
     ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝   ╚══════╝   ╚═╝       ╚═════╝ ╚══════╝  ╚═══╝
```

## Overview

**This directory contains fallback Dockerfiles.** The source of truth is `../nix/flake.nix`.

```
nix/           →  flake.nix (defines everything)
                   ├── configs/starship.toml
                   └── nix build .#docker-*
                          ↓
docker/        →  Fallback Dockerfiles (this directory)
                   └── For non-Nix builds only
```

## Building Images

### Preferred: Via Nix (recommended)

```bash
# From nix/ directory
cd ../nix

# Build specific variant (streamLayeredImage outputs a script)
nix build .#docker-base
./result | docker load

# Build all variants
for variant in base k8s python node full; do
  nix build .#docker-$variant --out-link result-$variant
  ./result-$variant | docker load
done
```

> **Note**: The result is a script that streams the image to Docker.
> This enables cross-platform builds (macOS → Linux containers).

### Via Tilt (Recommended for development)

```bash
# From repository root (catalyst-images/)
tilt up

# Use the nav buttons in the UI, or:
tilt trigger docker-base
tilt trigger docker-all
```

### Fallback: Traditional Docker (without Nix)

```bash
# Only if you don't have Nix installed
docker build -t catalyst-dev:base -f Dockerfile.base .
```

## Image Variants

| Tag | Description | Use Case |
|-----|-------------|----------|
| `minimal` | zsh, starship, core tools | Smallest footprint |
| `base` | + eza, bat, fzf, ripgrep, jq, git, neovim | General development |
| `k8s` | + kubectl, k9s, helm, kustomize | Kubernetes work |
| `python` | + python, poetry, ruff, pyright | Python development |
| `node` | + node, npm, yarn, typescript | Node.js/TypeScript |
| `go` | + go, gopls, air | Go development |
| `full` | Everything above | Kitchen sink |

## Quick Usage

```bash
# Interactive shell
docker run -it -v $(pwd):/workspace catalyst-dev:full

# As base image
FROM catalyst-dev:base
WORKDIR /app
COPY . .
```

## What's Inside

### Shell Experience

- **ZSH** with modern plugins
- **Starship** prompt (cyberpunk theme, container-aware)
- Modern aliases: `ls→eza`, `cat→bat`, `grep→ripgrep`, `find→fd`

### Environment Variables

```
SHELL=/bin/zsh
EDITOR=nvim
STARSHIP_CONFIG=/etc/starship.toml
CATALYST_ENV=docker
CATALYST_VARIANT=<variant>
CONTAINER=catalyst-dev
```

## Files in This Directory

| File | Purpose |
|------|---------|
| `Dockerfile.base` | Fallback Alpine-based image (no Nix required) |
| `Dockerfile.nix` | Build via Nix inside Docker |
| `README.md` | This file |

## Don't Modify Here for Package Changes!

To change the development environment:

1. Edit `../nix/flake.nix` (packages, configs)
2. Edit `../nix/configs/starship.toml` (prompt)
3. Rebuild: `nix build .#docker-<variant>` or use Tilt

The fallback Dockerfiles (`Dockerfile.*`) are for environments without Nix.

---

**Source of truth: [`../nix/`](../nix/)**
