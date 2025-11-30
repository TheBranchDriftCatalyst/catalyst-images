# catalyst-dev via Nix
# Builds the image using Nix inside Docker
# This is the "canonical" way if you have Docker but not Nix locally
#
# Build: docker build -t catalyst-dev:nix -f Dockerfile.nix .
# Usage: docker run -it catalyst-dev:nix

FROM nixos/nix:latest AS builder

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Copy flake source
WORKDIR /build
COPY catalyst-nix/ ./

# Build the image (outputs to /build/result)
RUN nix build .#docker-full --out-link result

# The result is a tarball that can be loaded into Docker
# For actual use, you'd: docker load < result
# But for multi-stage, we extract it:

FROM scratch
COPY --from=builder /build/result /image.tar.gz
