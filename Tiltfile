# -*- mode: Python -*-
"""
Catalyst Docker Development Environment
Orchestrates building nix → catalyst-dev images

Architecture:
  nix/  →  flake.nix (source of truth)
                     ├── configs/starship.toml
                     └── nix build .#docker-*
                            ↓
  catalyst-dev/  →  Generated Docker images
                     └── Fallback Dockerfiles (non-Nix)
                            ↓
  example-app/   →  Demo app using catalyst-dev:*
"""

# ==============================================================================
# Tilt Extensions
# ==============================================================================

load('ext://uibutton', 'cmd_button', 'location', 'text_input', 'bool_input', 'choice_input')
load('ext://dotenv', 'dotenv')

# Load environment variables from .env file (if exists)
dotenv()

# ==============================================================================
# Configuration
# ==============================================================================

# Note: Only one config can have args=True (positional args)
config.define_string_list("variants", args=True)
config.define_string("registry")
config.define_bool("use-nix")

cfg = config.parse()

# Image variants to build
DEFAULT_VARIANTS = ["base", "k8s", "python", "node", "full"]
VARIANTS = cfg.get("variants", DEFAULT_VARIANTS)

# Registry for publishing
REGISTRY = cfg.get("registry", "ghcr.io/thebranchdriftcatalyst")

# Use Nix for builds (recommended)
USE_NIX = cfg.get("use-nix", True)

# ==============================================================================
# Labels for Tilt UI (numbered prefixes for ordering)
# ==============================================================================

LABEL_BUILDS = "1-builds"
LABEL_SHELLS = "2-shells"
LABEL_APP = "3-example-app"
LABEL_OPS = "4-ops"

# ==============================================================================
# NAV BUTTONS - Quick actions in the navigation bar
# ==============================================================================

# Build variant selector (dropdown)
cmd_button(
    name='btn-build',
    argv=['sh', '-c', '''
        case "$VARIANT" in
            "all")
                for v in base k8s python node full; do
                    tilt trigger docker-$v &
                done
                wait
                echo "✅ All builds triggered"
                ;;
            *)
                tilt trigger docker-$VARIANT
                echo "✅ docker-$VARIANT triggered"
                ;;
        esac
    '''],
    location=location.NAV,
    text='Build',
    icon_name='build',
    inputs=[
        choice_input('VARIANT', 'Variant', ['all', 'base', 'k8s', 'python', 'node', 'full'])
    ]
)

# Shell selector (dropdown)
cmd_button(
    name='btn-shell',
    argv=['sh', '-c', '''
        case "$SHELL_TYPE" in
            "nix") tilt trigger nix-shell ;;
            "docker-full") docker run --rm -it -v $(pwd):/workspace catalyst-dev:full ;;
            "docker-base") docker run --rm -it -v $(pwd):/workspace catalyst-dev:base ;;
            "docker-k8s") docker run --rm -it -v $(pwd):/workspace catalyst-dev:k8s ;;
            "docker-python") docker run --rm -it -v $(pwd):/workspace catalyst-dev:python ;;
            "docker-node") docker run --rm -it -v $(pwd):/workspace catalyst-dev:node ;;
            *) echo "Unknown shell: $SHELL_TYPE" ;;
        esac
    '''],
    location=location.NAV,
    text='Shell',
    icon_name='terminal',
    inputs=[
        choice_input('SHELL_TYPE', 'Type', ['docker-full', 'docker-base', 'docker-k8s', 'docker-python', 'docker-node', 'nix'])
    ]
)

# Publish dropdown
cmd_button(
    name='btn-publish',
    argv=['sh', '-c', '''
        REGISTRY="{registry}"
        case "$PUBLISH_TARGET" in
            "all")
                for v in base k8s python node full; do
                    echo "Publishing $REGISTRY/catalyst-dev:$v..."
                    docker tag catalyst-dev:$v $REGISTRY/catalyst-dev:$v
                    docker push $REGISTRY/catalyst-dev:$v
                done
                docker tag catalyst-dev:full $REGISTRY/catalyst-dev:latest
                docker push $REGISTRY/catalyst-dev:latest
                echo "✅ All images published"
                ;;
            *)
                echo "Publishing $REGISTRY/catalyst-dev:$PUBLISH_TARGET..."
                docker tag catalyst-dev:$PUBLISH_TARGET $REGISTRY/catalyst-dev:$PUBLISH_TARGET
                docker push $REGISTRY/catalyst-dev:$PUBLISH_TARGET
                echo "✅ Published catalyst-dev:$PUBLISH_TARGET"
                ;;
        esac
    '''.format(registry=REGISTRY)],
    location=location.NAV,
    text='Publish',
    icon_name='cloud_upload',
    inputs=[
        choice_input('PUBLISH_TARGET', 'Target', ['all', 'base', 'k8s', 'python', 'node', 'full'])
    ],
    requires_confirmation=True
)

# Quick status
cmd_button(
    name='btn-images',
    argv=['sh', '-c', '''
        echo "=== Catalyst Images ===" && \
        docker images | grep -E "(catalyst-dev|example-app)" | head -20 || echo "No images found" && \
        echo "" && echo "=== Nix Store Size ===" && \
        du -sh /nix/store 2>/dev/null || echo "Nix not installed"
    '''],
    location=location.NAV,
    text='Images',
    icon_name='inventory_2'
)

# Cleanup dropdown
cmd_button(
    name='btn-cleanup',
    argv=['sh', '-c', '''
        case "$CLEANUP_TYPE" in
            "images")
                docker images catalyst-dev -q | xargs -r docker rmi -f
                docker images example-app -q | xargs -r docker rmi -f
                echo "✅ Removed catalyst images"
                ;;
            "nix-results")
                rm -f nix/result-*
                echo "✅ Removed Nix result symlinks"
                ;;
            "dangling")
                docker image prune -f
                echo "✅ Removed dangling images"
                ;;
            "all")
                docker images catalyst-dev -q | xargs -r docker rmi -f 2>/dev/null
                docker images example-app -q | xargs -r docker rmi -f 2>/dev/null
                rm -f nix/result-*
                docker image prune -f
                echo "✅ Full cleanup complete"
                ;;
            *) echo "Unknown cleanup: $CLEANUP_TYPE" ;;
        esac
    '''],
    location=location.NAV,
    text='Cleanup',
    icon_name='delete_sweep',
    inputs=[
        choice_input('CLEANUP_TYPE', 'Type', ['all', 'images', 'nix-results', 'dangling'])
    ],
    requires_confirmation=True
)

# Cache busting dropdown (for when caches cause issues)
cmd_button(
    name='btn-cache-bust',
    argv=['sh', '-c', '''
        case "$CACHE_TARGET" in
            "docker-builder")
                echo "🧹 Clearing Docker builder cache..."
                docker builder prune -af
                echo "✅ Docker builder cache cleared"
                ;;
            "docker-all")
                echo "🧹 Clearing ALL Docker caches..."
                docker system prune -af --volumes
                echo "✅ All Docker caches cleared (images, containers, volumes, networks)"
                ;;
            "nix-gc")
                echo "🧹 Running Nix garbage collection..."
                nix-collect-garbage -d
                echo "✅ Nix garbage collected"
                du -sh /nix/store
                ;;
            "nix-store-gc")
                echo "🧹 Aggressive Nix store cleanup..."
                nix-collect-garbage -d
                nix-store --optimise
                echo "✅ Nix store optimized"
                du -sh /nix/store
                ;;
            "nix-flake-cache")
                echo "🧹 Clearing Nix flake cache..."
                rm -rf ~/.cache/nix/
                echo "✅ Nix flake cache cleared"
                ;;
            "all-caches")
                echo "🧹 NUCLEAR OPTION - Clearing ALL caches..."
                echo ""
                echo "Docker builder cache..."
                docker builder prune -af 2>/dev/null || true
                echo ""
                echo "Docker system prune..."
                docker system prune -af 2>/dev/null || true
                echo ""
                echo "Nix garbage collection..."
                nix-collect-garbage -d 2>/dev/null || true
                echo ""
                echo "Nix flake cache..."
                rm -rf ~/.cache/nix/ 2>/dev/null || true
                echo ""
                echo "Nix result symlinks..."
                rm -f nix/result-* 2>/dev/null || true
                echo ""
                echo "✅ All caches cleared!"
                ;;
            *) echo "Unknown cache target: $CACHE_TARGET" ;;
        esac
    '''],
    location=location.NAV,
    text='Cache',
    icon_name='layers_clear',
    inputs=[
        choice_input('CACHE_TARGET', 'Target', [
            'docker-builder',
            'docker-all',
            'nix-gc',
            'nix-store-gc',
            'nix-flake-cache',
            'all-caches'
        ])
    ],
    requires_confirmation=True
)

# ==============================================================================
# Source of Truth: nix
# ==============================================================================

# Watch Nix flake for changes
watch_file("nix/flake.nix")
watch_file("nix/flake.lock")
watch_file("nix/configs/starship.toml")

# Validate flake (suppress incompatible systems warning - we only build for current arch)
local_resource(
    "nix-flake-check",
    cmd="cd nix && nix flake check 2>&1 | grep -v 'incompatible systems' | grep -v \"Use '--all-systems'\" || echo 'Flake check failed (nix may not be installed)'",
    labels=[LABEL_OPS],
    auto_init=True,
)

# Nix garbage collection
local_resource(
    "nix-gc",
    cmd="""
    echo "Running Nix garbage collection..."
    nix-collect-garbage -d
    echo "✅ Garbage collection complete"
    du -sh /nix/store
    """,
    labels=[LABEL_OPS],
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
)

# ==============================================================================
# Docker Image Builds
# ==============================================================================

if USE_NIX:
    # Build Docker images via Nix (preferred)
    # Note: Variants that extend 'base' depend on docker-base being built first
    VARIANT_DEPS = {
        "base": [],
        "k8s": ["docker-base"],
        "python": ["docker-base"],
        "node": ["docker-base"],
        "full": ["docker-base"],
    }

    for variant in VARIANTS:
        deps = ["nix-flake-check"] + VARIANT_DEPS.get(variant, [])
        local_resource(
            "docker-{}".format(variant),
            cmd="""
            cd nix
            echo "Building catalyst-dev:{variant} via Nix..."
            nix build .#docker-{variant} --out-link result-{variant}
            echo "Streaming image to Docker..."
            ./result-{variant} | docker load
            echo "✅ catalyst-dev:{variant} loaded into Docker"
            """.format(variant=variant),
            labels=[LABEL_BUILDS],
            resource_deps=deps,
            auto_init=False,
            trigger_mode=TRIGGER_MODE_MANUAL,
        )

    # Build all variants - triggers individual builds in parallel via Tilt
    local_resource(
        "docker-all",
        cmd="""
        echo "Triggering all docker builds in parallel..."
        for variant in {variants}; do
            tilt trigger docker-$variant &
        done
        wait
        echo "✅ All build jobs triggered - check individual resources for status"
        """.format(variants=" ".join(VARIANTS)),
        labels=[LABEL_BUILDS],
        resource_deps=["nix-flake-check"],
        auto_init=False,
        trigger_mode=TRIGGER_MODE_MANUAL,
    )

    # Add buttons to individual build resources
    for variant in VARIANTS:
        cmd_button(
            name='btn-shell-{}'.format(variant),
            resource='docker-{}'.format(variant),
            argv=['sh', '-c', 'docker run --rm -it -v $(pwd):/workspace catalyst-dev:{}'.format(variant)],
            text='Shell',
            icon_name='terminal'
        )

        cmd_button(
            name='btn-inspect-{}'.format(variant),
            resource='docker-{}'.format(variant),
            argv=['sh', '-c', '''
                echo "=== Image Info ===" && \
                docker inspect catalyst-dev:{variant} --format "Size: {{{{.Size}}}}" 2>/dev/null && \
                echo "" && echo "=== Layers ===" && \
                docker history catalyst-dev:{variant} --no-trunc 2>/dev/null | head -20
            '''.format(variant=variant)],
            text='Inspect',
            icon_name='info'
        )

else:
    # Fallback: Build with traditional Dockerfiles
    for variant in VARIANTS:
        dockerfile = "docker/Dockerfile.{}".format(variant)
        if not os.path.exists(dockerfile):
            dockerfile = "docker/Dockerfile.base"

        docker_build(
            ref="catalyst-dev:{}".format(variant),
            context=".",
            dockerfile=dockerfile,
            build_args={"VARIANT": variant},
        )

# ==============================================================================
# Development Shells (via Nix)
# ==============================================================================

local_resource(
    "nix-shell",
    serve_cmd="cd nix && nix develop",
    labels=[LABEL_SHELLS],
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
)

for profile in ["base", "k8s", "python", "node", "go", "rust"]:
    local_resource(
        "nix-shell-{}".format(profile),
        serve_cmd="cd nix && nix develop .#{}".format(profile),
        labels=[LABEL_SHELLS],
        auto_init=False,
        trigger_mode=TRIGGER_MODE_MANUAL,
    )

# ==============================================================================
# Example App
# ==============================================================================

# Build example app (depends on catalyst-dev:node)
local_resource(
    "example-app-build",
    cmd="""
    echo "Building example-app:dev..."
    docker build -t example-app:dev \
        --build-arg BASE_IMAGE=catalyst-dev:node \
        -f example-app/Dockerfile \
        example-app/
    echo "✅ example-app:dev built"
    """,
    labels=[LABEL_APP],
    resource_deps=["docker-node"] if USE_NIX else [],
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
)

# Run example app
local_resource(
    "example-app-run",
    serve_cmd="""
    docker run --rm -it \
        -p 3000:3000 \
        -v $(pwd)/example-app/src:/app/src \
        example-app:dev
    """,
    labels=[LABEL_APP],
    resource_deps=["example-app-build"],
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
    links=[
        link('http://localhost:3000', 'Example App')
    ]
)

# Add buttons to example app
cmd_button(
    name='btn-example-shell',
    resource='example-app-build',
    argv=['docker', 'run', '--rm', '-it', '-v', '$(pwd)/example-app:/app', 'example-app:dev', '/bin/zsh'],
    text='Shell',
    icon_name='terminal'
)

# ==============================================================================
# Interactive Shells (Docker)
# ==============================================================================

# Interactive shell with catalyst-dev:full
local_resource(
    "interactive-shell",
    serve_cmd="docker run --rm -it -v $(pwd):/workspace catalyst-dev:full",
    labels=[LABEL_SHELLS],
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
)

# Interactive shell with catalyst-dev:base (for testing)
local_resource(
    "test-base-shell",
    serve_cmd="docker run --rm -it -v $(pwd):/workspace catalyst-dev:base",
    labels=[LABEL_SHELLS],
    resource_deps=["docker-base"],
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
)

# ==============================================================================
# Operations Resources
# ==============================================================================

local_resource(
    "list-images",
    cmd="docker images | grep -E '(catalyst-dev|example-app)' || echo 'No images found'",
    labels=[LABEL_OPS],
    auto_init=True,
)

local_resource(
    "nix-store-size",
    cmd="""
    echo "=== Nix Store ===" && \
    du -sh /nix/store 2>/dev/null || echo "Nix not installed" && \
    echo "" && echo "=== Catalyst Packages ===" && \
    ls -la nix/result-* 2>/dev/null || echo "No result links"
    """,
    labels=[LABEL_OPS],
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
)

# ==============================================================================
# UI Configuration
# ==============================================================================

update_settings(
    max_parallel_updates=4,  # Increased for faster parallel builds
    k8s_upsert_timeout_secs=60,
)

# Welcome message
print("""
╔════════════════════════════════════════════════════════════════════════╗
║                    Catalyst Docker Development                          ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                         ║
║  UI Groups:                                                             ║
║    1-builds      → Docker image builds (via Nix)                       ║
║    2-shells      → Development shells (Nix & Docker)                   ║
║    3-example-app → Demo application                                    ║
║    4-ops         → Operations & utilities                              ║
║                                                                         ║
║  Nav Buttons:                                                          ║
║    Build   → Build images (dropdown selector)                          ║
║    Shell   → Start shell (dropdown selector)                           ║
║    Publish → Push to registry                                          ║
║    Images  → List local images                                         ║
║    Cleanup → Remove images/artifacts                                   ║
║                                                                         ║
║  Variants: {variants}
║  Registry: {registry}
║                                                                         ║
╚════════════════════════════════════════════════════════════════════════╝
""".format(
    variants=", ".join(VARIANTS),
    registry=REGISTRY
))
