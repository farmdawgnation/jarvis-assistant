#!/bin/bash
# Setup script for macOS ARM64 (Apple Silicon)
# This creates the tflite_runtime shim so openwakeword can use tensorflow's TFLite interpreter

set -e

if [ "$(uname)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    echo "This script is for macOS ARM64 (Apple Silicon) only."
    exit 1
fi

echo "Setting up tflite_runtime shim for macOS ARM64..."

# Check Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
if [ "$(python3 -c "import sys; print(sys.version_info.minor)")" -gt 13 ]; then
    echo "Error: Python 3.14+ is not supported by tensorflow on macOS ARM64."
    echo "Please use Python 3.13 or earlier."
    exit 1
fi

# Install tensorflow if not already installed
if ! python3 -c "import tensorflow" 2>/dev/null; then
    echo "Installing tensorflow..."
    pip install 'tensorflow<2.20'
fi

# Create the shim
SITE=$(python3 -c "import site; print(site.getsitepackages()[0])")
SHIM_DIR="$SITE/tflite_runtime"

echo "Creating shim in $SHIM_DIR..."
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
