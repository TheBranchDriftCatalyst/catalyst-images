# Example App Dockerfile
# Demonstrates using catalyst-images as a base image

ARG BASE_IMAGE=catalyst-images:node

FROM ${BASE_IMAGE}

LABEL maintainer="TheBranchDriftCatalyst"
LABEL description="Example application using catalyst-images base image"

# Set working directory
WORKDIR /app

# Copy package files first (layer caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/

# Expose port
EXPOSE 3000

# Default command
CMD ["node", "src/index.js"]
