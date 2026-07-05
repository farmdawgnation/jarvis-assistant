#!/bin/bash
# Setup script for macOS ARM64 (Apple Silicon)
# Creates the tflite_runtime shim so openwakeword can use tensorflow's TFLite interpreter.
# Uses uv for all Python dependency management and invocation.

set -euo pipefail

if [ "$(uname)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    echo "This script is for macOS ARM64 (Apple Silicon) only."
    exit 1
fi

# Resolve project root (this script lives in agent/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "Setting up tflite_runtime shim for macOS ARM64..."

# Ensure uv is available
if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: uv is not installed."
    echo "Install with:  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Ensure Python 3.13 is available (tensorflow has no wheels for 3.14+)
echo "==> Ensuring Python 3.13 is available..."
uv python install 3.13
uv venv --python 3.13

# Verify the venv is on 3.13 (tensorflow won't import on 3.14+)
PY_MINOR=$(uv run python -c "import sys; print(sys.version_info.minor)")
if [ "$PY_MINOR" -gt 13 ]; then
    echo "Error: venv Python is 3.${PY_MINOR}; tensorflow needs 3.13 or earlier."
    echo "Recreate with:  uv venv --python 3.13"
    exit 1
fi

echo "==> Installing Python dependencies..."
uv pip install -r agent/requirements.txt

# Install tensorflow if not already importable in the venv
if ! uv run python -c "import tensorflow" 2>/dev/null; then
    echo "==> Installing tensorflow..."
    uv pip install 'tensorflow<2.20'
fi

# Create the shim inside the venv's site-packages
SITE=$(uv run python -c "import site; print(site.getsitepackages()[0])")
SHIM_DIR="$SITE/tflite_runtime"

echo "==> Creating shim in $SHIM_DIR..."
mkdir -p "$SHIM_DIR"

cat > "$SHIM_DIR/__init__.py" << 'EOF'
# Shim to make tensorflow's TFLite interpreter available as tflite_runtime
EOF

cat > "$SHIM_DIR/interpreter.py" << 'EOF'
from tensorflow.lite.python.interpreter import Interpreter
from tensorflow.lite.python.interpreter import load_delegate
EOF

echo "✓ Shim created successfully"
echo ""
echo "You can now use openwakeword with inference_framework='tflite'"
echo "The wake.py module will auto-detect this setup."
