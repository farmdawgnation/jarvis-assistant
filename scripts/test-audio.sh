#!/usr/bin/env bash
# Cross-platform audio test script (Raspberry Pi / Linux or macOS).
#
# Linux:  Uses ALSA (arecord/aplay). Run `arecord -l` to find your USB mic
#         card index and adjust CAPTURE_DEVICE below if needed.
# macOS:  Uses SoX (rec/play). Install with: brew install sox
set -euo pipefail

RECORDING=/tmp/test-audio.wav
DURATION=3
OS="$(uname -s)"

# -------------------------------------------------------------------
# Linux (Raspberry Pi) — ALSA
# -------------------------------------------------------------------
run_linux() {
  local capture_device="${1:-plughw:1,0}"

  echo "==> Available capture devices (arecord -l):"
  arecord -l
  echo ""

  echo "==> Available playback devices (aplay -l):"
  aplay -l
  echo ""

  echo "==> Recording ${DURATION}-second test clip from ${capture_device} ..."
  echo "    >>> Speak now! <<<"
  arecord -D "$capture_device" -f S16_LE -r 16000 -c1 "$RECORDING" -d "$DURATION"
  echo ""

  echo "==> Playing back recording..."
  aplay "$RECORDING"
  echo ""

  echo "  If playback was clear, your mic and speaker are working."
  echo "  If not, adjust the card index in this script and ~/.asoundrc."
}

# -------------------------------------------------------------------
# macOS — SoX
# -------------------------------------------------------------------
run_macos() {
  if ! command -v rec &>/dev/null; then
    echo "ERROR: 'sox' is not installed."
    echo "Install it with:  brew install sox"
    echo ""
    echo "After installing, grant microphone access in:"
    echo "  System Settings → Privacy & Security → Microphone"
    exit 1
  fi

  echo "==> Available audio devices (sox --info):"
  sox --info -a 2>/dev/null || true
  echo ""

  echo "==> Recording ${DURATION}-second test clip from default microphone ..."
  echo "    >>> Speak now! <<<"
  # macOS CoreAudio doesn't allow changing device sample rate,
  # so record at the device's native rate (usually 44100 or 48000).
  # This file is for manual listening only — the actual pipeline
  # uses PyAudio which handles resampling via PortAudio.
  rec -c 1 -b 16 "$RECORDING" trim 0 "$DURATION"
  echo ""

  echo "==> Playing back recording..."
  play "$RECORDING"
  echo ""

  echo "  If playback was clear, your mic and speaker are working."
  echo "  To change the input device, set it in Audio MIDI Setup or use:"
  echo "    rec -t sox -d ...   (see 'man sox' for device options)"
}

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------
cleanup() { rm -f "$RECORDING"; }
trap cleanup EXIT

case "$OS" in
  Linux)
    run_linux "${CAPTURE_DEVICE:-plughw:1,0}"
    ;;
  Darwin)
    run_macos
    ;;
  *)
    echo "ERROR: Unsupported OS '$OS'. This script supports Linux and macOS."
    exit 1
    ;;
esac

echo ""
echo "============================================================"
echo "  Audio test complete!"
echo "============================================================"
