#!/usr/bin/env bash
set -euo pipefail

# Verify 64-bit OS
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
  echo "ERROR: This script requires a 64-bit (aarch64) OS. Detected: $ARCH"
  echo "Please install Raspberry Pi OS Lite 64-bit and try again."
  exit 1
fi

echo "==> Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "==> Installing system dependencies..."
sudo apt install -y \
  docker.io \
  docker-compose-plugin \
  portaudio19-dev \
  python3 \
  alsa-utils \
  curl

echo "==> Adding $USER to docker group..."
sudo usermod -aG docker "$USER"

echo "==> Configuring firewall rules..."
sudo ufw allow 7880/tcp
sudo ufw allow 7881/tcp
sudo ufw allow 50000:60000/udp

echo "==> Installing uv (Astral)..."
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
# uv installs to ~/.local/bin; make it available for the rest of this script
export PATH="$HOME/.local/bin:$PATH"

# Resolve the project root (one level up from this script's directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Creating Python virtual environment at $PROJECT_ROOT/.venv ..."
uv venv "$PROJECT_ROOT/.venv"

echo "==> Installing Python dependencies..."
uv pip install --python "$PROJECT_ROOT/.venv/bin/python" \
  -r "$PROJECT_ROOT/agent/requirements.txt"

echo "==> Downloading openwakeword model files..."
( cd "$PROJECT_ROOT" && uv run python -c \
  "from openwakeword.utils import download_models; download_models(['hey_jarvis'])" )

echo ""
echo "============================================================"
echo "  Setup complete!"
echo "  IMPORTANT: Log out and back in for docker group membership"
echo "  to take effect, then run: scripts/test-audio.sh"
echo "============================================================"
