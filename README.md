<<<<<<< HEAD
# llm_safe_space
Use pod man to run LLMs safely
=======
# Claude Code Podman Container

Run Claude Code in an isolated Podman container with root privileges, allowing it to install packages and modify the system freely without affecting your host.

## Quick Start

```bash
# Build and run with a project directory
./run-claude-code.sh ~/projects/myapp

# Inside the container
claude
```

## Prerequisites

- Podman installed
- Claude Code authenticated on your host (run `claude` once to set up `~/.claude`)
- Or set `ANTHROPIC_API_KEY` environment variable

## Usage

```
./run-claude-code.sh [options] [directories...]

Options:
  -h, --help          Show help message with credential instructions
  -g, --git           Mount git credentials (~/.gitconfig and ~/.git-credentials)
  -s, --ssh PATHS     Mount specific SSH key files (comma-separated paths)
  -n, --no-build      Skip rebuilding the container image

Arguments:
  directories...      Directories to mount into /workspace (space-separated)
```

## Examples

```bash
# Basic - just Anthropic credentials
./run-claude-code.sh

# Mount a project directory
./run-claude-code.sh ~/projects/myapp

# With git HTTPS credentials
./run-claude-code.sh -g ~/projects/myapp

# With specific SSH keys
./run-claude-code.sh -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub ~/projects/myapp

# With SSH keys and config
./run-claude-code.sh -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub,~/.ssh/config ~/projects/myapp

# Full setup: git + SSH + project
./run-claude-code.sh -g -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub,~/.ssh/config ~/projects/myapp

# Multiple project directories
./run-claude-code.sh ~/proj1 ~/proj2

# Skip rebuild if image exists
./run-claude-code.sh -n ~/projects/myapp
```

## Git/GitHub Credentials

### Option 1: HTTPS with Git Credentials (`-g` flag)

```bash
# On your host, set up credential storage
git config --global credential.helper store

# Authenticate once (credentials get cached)
git push  # or any operation requiring auth

# Run container with -g flag
./run-claude-code.sh -g ~/myproject
```

This mounts `~/.gitconfig` and `~/.git-credentials` (read-only).

### Option 2: SSH Keys (`-s` flag)

```bash
# Specify exact files to mount (comma-separated)
./run-claude-code.sh -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub ~/myproject

# Include config for host aliases
./run-claude-code.sh -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub,~/.ssh/config ~/myproject
```

Files are mounted read-only to `/root/.ssh/` in the container. Use SSH URLs for git:
```bash
git clone git@github.com:user/repo.git
```

### Option 3: GitHub CLI (inside container)

```bash
# Inside the container, install and authenticate gh
apt-get update && apt-get install -y gh
gh auth login
```

## What's Included

The container includes:
- Node.js 22 (Debian Bookworm)
- Claude Code (`@anthropic-ai/claude-code`)
- tmux
- git
- vim
- curl
- openssh-client

## Container Details

- **Root access**: Container runs as root with `--privileged`
- **Workspace**: Mounted directories appear in `/workspace/<dirname>`
- **Credentials**: `~/.claude` mounted to `/root/.claude`
- **Isolation**: Changes inside the container don't affect your host (except mounted directories)

## Inside the Container

```bash
# Start Claude Code
claude

# Use tmux for multiple terminals
tmux

# Your projects are in /workspace
cd /workspace/myapp

# Install additional tools as needed (you're root)
apt-get update && apt-get install -y <package>
```

## Security Notes

- Mounted directories are read-write; Claude can modify your project files
- Git/SSH credentials are mounted read-only
- The container has full root privileges inside its namespace
- Only mount credentials you're comfortable exposing to the container

## Building Manually

```bash
podman build -t claude-code .
```

## Troubleshooting

**"~/.claude not found" warning**
- Run `claude` on your host first to authenticate, or
- Set `ANTHROPIC_API_KEY` environment variable before running the script

**Permission denied on mounted files**
- The `:z` SELinux label is applied automatically
- If issues persist, check your Podman/SELinux configuration

**Container name conflict**
- The script uses `--rm` so containers are removed on exit
- If a container is stuck: `podman rm -f claude-code-session`
>>>>>>> 4d251d1 (start)
