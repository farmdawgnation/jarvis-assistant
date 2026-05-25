#!/usr/bin/env bash
# NOTE: The capture device plughw:1,0 below uses card index 1, device 0.
# Run `arecord -l` to find the correct card index for your USB mic and adjust accordingly.
set -euo pipefail

RECORDING=/tmp/test-audio.wav

echo "==> Available capture devices (arecord -l):"
arecord -l
echo ""

echo "==> Available playback devices (aplay -l):"
aplay -l
echo ""

echo "==> Recording 3-second test clip from plughw:1,0 ..."
echo "    >>> Speak now! <<<"
arecord -D plughw:1,0 -f S16_LE -r 16000 -c1 "$RECORDING" -d 3
echo ""

echo "==> Playing back recording..."
aplay "$RECORDING"
echo ""

echo "==> Cleaning up..."
rm -f "$RECORDING"

echo ""
echo "============================================================"
echo "  Audio test complete!"
echo "  If playback was clear, your mic and speaker are working."
echo "  If not, adjust the card index in this script and ~/.asoundrc."
echo "============================================================"
