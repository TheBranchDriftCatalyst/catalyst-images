# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**catalyst-images** is a development environment image system that uses Nix as the source of truth for building Docker images. It provides reproducible, layered development containers with modern CLI tooling (starship, eza, bat, fzf, ripgrep, etc.).

Key features:
- Nix-based reproducible builds
- Cross-platform (build Linux images on macOS)
- Multiple variants (minimal to full-stack)
- Debug mode for Python/Node/Go
- Taskfile automation
- Lefthook git hooks with conventional commits

## Architecture

```
catalyst-images/
├── Taskfile.yml      → Task automation (build, test, release)
├── Tiltfile          → Tilt development orchestration
├── lefthook.yml      → Git hooks (conventional commits)
├── VERSION           → Semantic version (1.0.0)
│
└── nix/              → Source of truth
    ├── flake.nix     → Package definitions, profiles, docker builder
    ├── flake.lock    → Pinned dependencies
    └── configs/
        ├── zshrc         → Shell config (aliases, functions, welcome)
        └── starship.toml → Prompt configuration
```

**Build Flow:**
```
nix/flake.nix → nix build .#docker-<variant> → ./result-<variant> | docker load → catalyst-images:<variant>
```

Note: `streamLayeredImage` outputs a **script** that streams to docker load, not a tarball.

## Common Commands

### Taskfile (Primary)

```bash
# Setup
task setup              # Install deps + git hooks
task deps               # Install Nix, verify tools

# Build
task build              # Build all variants
task build:base         # Build base variant
task build:variant VARIANT=python

# Development
task dev                # Start Tilt
task shell              # Interactive shell in container
task shell:debug        # Shell with debug mode

# Test & Lint
task lint               # Run all linters
task test               # Test images

# Release
task release VERSION=1.1.0
task publish
task publish:variant VARIANT=base

# Clean
task clean              # Clean artifacts
task clean:all          # Deep clean + Nix GC
```

### Tilt (Interactive Development)

```bash
tilt up                           # Start
tilt trigger catalyst-images-base    # Trigger specific build
tilt logs -f                      # Follow logs
tilt down                         # Stop
```

### Nix (Direct Builds)

```bash
cd nix

# Dev shells
nix develop              # Full profile
nix develop .#base       # Base tools
nix develop .#python     # Python tools

# Build images
nix build .#docker-base --out-link result-base
./result-base | docker load
```

## Image Variants

| Tag | Description | Key Packages |
|-----|-------------|--------------|
| `minimal` | Bare essentials | zsh, coreutils, git, curl |
| `base` | Standard dev | + starship, fzf, ripgrep, bat, fd, neovim |
| `k8s` | Kubernetes | + kubectl, k9s, helm, kustomize, stern |
| `python` | Python dev | + python 3.12, poetry, ruff, pyright |
| `node` | Node.js dev | + node 20, npm, yarn, pnpm, typescript |
| `go` | Go dev | + go, gopls, golangci-lint, air |
| `rust` | Rust dev | + rustup |
| `full` | Everything | All of the above |

Images are tagged: `catalyst-images:<variant>` and `catalyst-images:<variant>-<version>`

## Key Files

- `nix/flake.nix` - **Edit this** to add/modify packages
  - Lines 47-87: Package set definitions
  - Lines 161-170: Profile combinations
  - Lines 226-283: Docker image builder
- `nix/configs/zshrc` - Shell configuration
  - Debug mode handling
  - Aliases and functions
  - Synthwave welcome screen
- `nix/configs/starship.toml` - Prompt configuration
- `Taskfile.yml` - Build/test/release automation
- `lefthook.yml` - Git hooks

## Debug Mode

Enable with `CATALYST_DEBUG=1`:

```bash
docker run -e CATALYST_DEBUG=1 -p 9229:9229 catalyst-images:base
# or
task shell:debug
```

Enables:
- Python: `PYTHONUNBUFFERED=1`, debugpy ready
- Node.js: `--inspect=0.0.0.0:9229`
- Go: `GODEBUG=gctrace=1`

Add `CATALYST_DEBUG_TRACE=1` for shell command tracing.

## Cross-Platform Building

Docker images contain Linux binaries but can be built on macOS:

```nix
# Native dockerTools runs on host
# Contents come from pkgsLinux (Linux packages)
linuxSystem = if pkgs.stdenv.isDarwin then
  (if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64-linux" else "x86_64-linux")
else
  system;
```

## Adding New Packages

1. Edit `nix/flake.nix`
2. Add package to appropriate tool set (coreTools, gitTools, k8sTools, etc.)
3. Assign to profile(s) in the `mkProfiles` function
4. Test: `nix develop .#<profile>`
5. Build: `task build:variant VARIANT=<profile>`

## Conventions

### Commits
Uses conventional commits (enforced by lefthook):
- `feat(scope): message` - New feature
- `fix(scope): message` - Bug fix
- `docs(scope): message` - Documentation
- `chore(scope): message` - Maintenance

### Versioning
Semantic versioning in `VERSION` file. Release with:
```bash
task release VERSION=1.1.0
git push && git push --tags
```
