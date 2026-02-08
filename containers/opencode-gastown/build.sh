#!/bin/bash
# Build the OpenCode + GasTown container image
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="claude-code:opencode-gastown"

echo "Building $IMAGE_TAG ..."
podman build -t "$IMAGE_TAG" "$SCRIPT_DIR"
echo "Done: $IMAGE_TAG"
