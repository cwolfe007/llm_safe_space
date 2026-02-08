#!/bin/bash
# Build the minimal Claude Code container image
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="claude-code:minimal"

echo "Building $IMAGE_TAG ..."
podman build -t "$IMAGE_TAG" "$SCRIPT_DIR"
echo "Done: $IMAGE_TAG"
