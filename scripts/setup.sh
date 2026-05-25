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
  python3-pyaudio \
  python3-pip \
  python3-venv \
  alsa-utils

echo "==> Adding $USER to docker group..."
sudo usermod -aG docker "$USER"

echo "==> Configuring firewall rules..."
sudo ufw allow 7880/tcp
sudo ufw allow 7881/tcp
sudo ufw allow 50000:60000/udp

# Resolve the project root (one level up from this script's directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Creating Python virtual environment at $PROJECT_ROOT/.venv ..."
python3 -m venv "$PROJECT_ROOT/.venv"

echo "==> Installing Python dependencies..."
"$PROJECT_ROOT/.venv/bin/pip" install --upgrade pip
"$PROJECT_ROOT/.venv/bin/pip" install -r "$PROJECT_ROOT/agent/requirements.txt"

echo ""
echo "============================================================"
echo "  Setup complete!"
echo "  IMPORTANT: Log out and back in for docker group membership"
echo "  to take effect, then run: scripts/test-audio.sh"
echo "============================================================"
