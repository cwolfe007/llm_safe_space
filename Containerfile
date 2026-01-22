# Containerfile for Claude Code with tmux
# Build: podman build -t claude-code .

FROM node:22-bookworm

# Install system dependencies and tmux
RUN apt-get update && apt-get install -y \
    tmux \
    git \
    curl \
    vim \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Default command - start a shell
CMD ["/bin/bash"]
