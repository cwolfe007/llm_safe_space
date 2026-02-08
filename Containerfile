# Containerfile for Claude Code with tmux
# Build: podman build -t claude-code .

# Stage 1: Get Go from official image
FROM golang:latest AS go-builder

# Stage 2: Main image
FROM node:22-bookworm

# Copy Go installation from golang image
COPY --from=go-builder /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Install system dependencies, tmux, and Python
RUN apt-get update && apt-get install -y \
    tmux \
    git \
    curl \
    vim \
    openssh-client \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*
RUN go install github.com/steveyegge/gastown/cmd/gt@latest
# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code  

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Default command - start a shell
CMD ["/bin/bash"]
