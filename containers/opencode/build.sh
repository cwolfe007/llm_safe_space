#!/bin/bash
# Build the minimal OpenCode container image
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="claude-code:opencode"

echo "Building $IMAGE_TAG ..."
podman build -t "$IMAGE_TAG" "$SCRIPT_DIR"
echo "Done: $IMAGE_TAG"
