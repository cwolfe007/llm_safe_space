#!/bin/bash
#
# Run Claude Code in a Podman container with optional directory mounts
#
# Usage: ./run-claude-code.sh [options] [directories...]
#
# Options:
#   -h, --help          Show this help message
#   -t, --tag TAG       Container flavor to use: minimal, gastown (default: minimal)
#   -g, --git           Mount git credentials (~/.gitconfig and ~/.git-credentials)
#   -s, --ssh PATHS     Mount specific SSH key files (comma-separated paths)
#   -n, --no-build      Skip building the container image
#   -p, --privileged    Run container in privileged mode (use with caution)
#
# Arguments:
#   directories...      Directories to mount into /workspace (space-separated)
#
# Examples:
#   ./run-claude-code.sh ~/projects/myapp              # Minimal container
#   ./run-claude-code.sh -t gastown ~/projects/myapp   # GasTown container (gt + bd)
#   ./run-claude-code.sh -g ~/projects/myapp           # Mount with git credentials
#   ./run-claude-code.sh -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub ~/myapp
#   ./run-claude-code.sh -g -s ~/.ssh/github_key,~/.ssh/github_key.pub,~/.ssh/config ~/proj
#

set -e

CONTAINER_TAG="minimal"
CONTAINER_NAME="claude-code-session"

# Parse options
MOUNT_GIT=false
SSH_KEYS=()
SKIP_BUILD=false
PRIVILEGED=false
DIRS=()

show_help() {
    head -24 "$0" | tail -23 | sed 's/^# \?//'
    echo ""
    echo "=========================================="
    echo "GIT/GITHUB CREDENTIALS INSTRUCTIONS"
    echo "=========================================="
    echo ""
    echo "Option 1: HTTPS with Git Credentials (-g flag)"
    echo "  1. Configure git credential storage on your host:"
    echo "     git config --global credential.helper store"
    echo "  2. Run any git operation that requires auth to cache credentials"
    echo "  3. Run this script with -g flag to mount ~/.gitconfig and ~/.git-credentials"
    echo ""
    echo "Option 2: SSH Keys (-s flag with specific paths)"
    echo "  1. Specify exact SSH files to mount (comma-separated):"
    echo "     -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub"
    echo "  2. Include ~/.ssh/config if needed for host aliases:"
    echo "     -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub,~/.ssh/config"
    echo "  3. Use SSH URLs for git (git@github.com:user/repo.git)"
    echo "  4. Files are mounted read-only to /root/.ssh/"
    echo ""
    echo "Option 3: GitHub CLI (gh)"
    echo "  The container includes git. You can install gh inside and run:"
    echo "     gh auth login"
    echo ""
    echo "Security Note:"
    echo "  Mounting credentials gives the container full access to your git/GitHub."
    echo "  Only use with trusted code and understand the implications."
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--tag)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: -t/--tag requires a tag name (minimal, gastown)"
                exit 1
            fi
            CONTAINER_TAG="$2"
            shift 2
            ;;
        -g|--git)
            MOUNT_GIT=true
            shift
            ;;
        -s|--ssh)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: -s/--ssh requires comma-separated paths"
                echo "Example: -s ~/.ssh/id_ed25519,~/.ssh/id_ed25519.pub"
                exit 1
            fi
            IFS=',' read -ra SSH_KEYS <<< "$2"
            shift 2
            ;;
        -n|--no-build)
            SKIP_BUILD=true
            shift
            ;;
        -p|--privileged)
            PRIVILEGED=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use -h for help"
            exit 1
            ;;
        *)
            DIRS+=("$1")
            shift
            ;;
    esac
done

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve container directory and image name from tag
CONTAINER_DIR="$SCRIPT_DIR/containers/$CONTAINER_TAG"
IMAGE_NAME="claude-code:$CONTAINER_TAG"

if [ ! -d "$CONTAINER_DIR" ]; then
    echo "Error: unknown container tag '$CONTAINER_TAG'"
    echo "Available tags:"
    for d in "$SCRIPT_DIR"/containers/*/; do
        [ -d "$d" ] && echo "  $(basename "$d")"
    done
    exit 1
fi

# Build the image if needed
if [ "$SKIP_BUILD" = false ]; then
    echo "Building $IMAGE_NAME ..."
    podman build -t "$IMAGE_NAME" "$CONTAINER_DIR"
fi

# Start building the podman run command
PODMAN_ARGS=(
    "run"
    "--rm"
    "-it"
    "--name" "$CONTAINER_NAME"
    "--hostname" "claude-code"
    # Run as root inside the container
    "--user" "root"
    # Let Claude Code know it's running in a sandbox/dev container
    "-e" "IS_SANDBOX=1"
)

# Add privileged mode if requested
if [ "$PRIVILEGED" = true ]; then
    echo "Warning: Running in privileged mode - container has elevated host access"
    PODMAN_ARGS+=("--privileged")
fi

# Mount Anthropic credentials
# Claude Code stores config in ~/.claude
CLAUDE_CONFIG_DIR="$HOME/.claude"
if [ -d "$CLAUDE_CONFIG_DIR" ]; then
    echo "Mounting Anthropic credentials from $CLAUDE_CONFIG_DIR"
    PODMAN_ARGS+=("-v" "$CLAUDE_CONFIG_DIR:/root/.claude:z")
else
    echo "Warning: $CLAUDE_CONFIG_DIR not found. You may need to run 'claude' to authenticate first."
    echo "Creating directory for credentials..."
    mkdir -p "$CLAUDE_CONFIG_DIR"
    PODMAN_ARGS+=("-v" "$CLAUDE_CONFIG_DIR:/root/.claude:z")
fi

# Also check for ANTHROPIC_API_KEY environment variable
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "Passing ANTHROPIC_API_KEY environment variable"
    PODMAN_ARGS+=("-e" "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
fi

# Mount git credentials if requested
if [ "$MOUNT_GIT" = true ]; then
    if [ -f "$HOME/.gitconfig" ]; then
        echo "Mounting git config"
        PODMAN_ARGS+=("-v" "$HOME/.gitconfig:/root/.gitconfig:ro,z")
    else
        echo "Warning: ~/.gitconfig not found"
    fi

    if [ -f "$HOME/.git-credentials" ]; then
        echo "Mounting git credentials"
        PODMAN_ARGS+=("-v" "$HOME/.git-credentials:/root/.git-credentials:ro,z")
    else
        echo "Warning: ~/.git-credentials not found (run 'git config --global credential.helper store' and authenticate once)"
    fi
fi

# Mount SSH keys if specified
if [ ${#SSH_KEYS[@]} -gt 0 ]; then
    echo "Mounting SSH keys..."
    for key_path in "${SSH_KEYS[@]}"; do
        # Expand tilde and resolve path
        expanded_path="${key_path/#\~/$HOME}"
        if [ -f "$expanded_path" ]; then
            key_name="$(basename "$expanded_path")"
            echo "  Mounting $expanded_path -> /root/.ssh/$key_name"
            PODMAN_ARGS+=("-v" "$expanded_path:/root/.ssh/$key_name:ro,z")
        else
            echo "Warning: SSH key not found: $key_path"
        fi
    done
fi

# Mount requested directories
if [ ${#DIRS[@]} -gt 0 ]; then
    for dir in "${DIRS[@]}"; do
        # Expand to absolute path
        abs_dir="$(cd "$dir" 2>/dev/null && pwd)" || {
            echo "Error: Directory not found: $dir"
            exit 1
        }
        # Get the basename for the mount point
        dir_name="$(basename "$abs_dir")"
        echo "Mounting $abs_dir -> /workspace/$dir_name"
        PODMAN_ARGS+=("-v" "$abs_dir:/workspace/$dir_name:z")
    done
else
    echo "No directories mounted. Use arguments to mount project directories."
    echo "Example: $0 ~/myproject"
fi

# Add the image name
PODMAN_ARGS+=("$IMAGE_NAME")

echo ""
echo "=========================================="
echo "Starting Claude Code container ($CONTAINER_TAG)"
echo "=========================================="
echo ""
echo "Inside the container:"
echo "  - Run 'claude' to start Claude Code"
echo "  - Run 'tmux' for terminal multiplexing"
echo "  - Your mounted directories are in /workspace/"
echo "  - You have root access - Claude can install packages, modify system, etc."
if [ "$CONTAINER_TAG" = "gastown" ]; then
echo "  - GasTown tools available: 'gt' and 'bd'"
fi
echo ""

# Run the container
exec podman "${PODMAN_ARGS[@]}"
