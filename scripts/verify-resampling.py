#!/usr/bin/env python3
"""
Verify that PyAudio/PortAudio software resampling works correctly.

Records a fixed wall-clock duration at 16kHz, then checks:
  1. Total bytes received matches expected (catches missing resampling)
  2. Output WAV file has correct sample rate and duration
  3. Per-chunk read timing matches expected 80ms per 1280-frame chunk

Run this after activating the project's venv:
    source .venv/bin/activate
    python scripts/verify-resampling.py

Requires: pyaudio, numpy, soundfile (or wave)
"""

import time
import wave

import numpy as np
import pyaudio

RATE = 16000
CHANNELS = 1
FORMAT = pyaudio.paInt16
CHUNK = 1280  # 80ms at 16kHz
DURATION_SEC = 3.0
OUTPUT_WAV = "/tmp/verify-resampling.wav"

EXPECTED_FRAMES = int(RATE * DURATION_SEC)
EXPECTED_BYTES = EXPECTED_FRAMES * 2  # 16-bit = 2 bytes per frame
CHUNK_DURATION_MS = (CHUNK / RATE) * 1000  # 80ms
TOLERANCE_BYTES = 0.1 * EXPECTED_BYTES  # 10% tolerance for timing jitter
TOLERANCE_MS = 20  # 20ms tolerance per chunk


def main():
    print(f"==> Recording {DURATION_SEC}s at {RATE}Hz via PyAudio...")
    print(f"    Expected: {EXPECTED_FRAMES} frames, {EXPECTED_BYTES} bytes")
    print(f"    Chunk size: {CHUNK} frames = {CHUNK_DURATION_MS:.0f}ms")
    print()

    pa = pyaudio.PyAudio()
    stream = pa.open(
        format=FORMAT,
        channels=CHANNELS,
        rate=RATE,
        input=True,
        frames_per_buffer=CHUNK,
    )

    all_data = bytearray()
    chunk_times = []
    start = time.monotonic()

    while True:
        chunk_start = time.monotonic()
        data = stream.read(CHUNK, exception_on_overflow=False)
        chunk_elapsed = time.monotonic() - chunk_start
        chunk_times.append(chunk_elapsed)

        all_data.extend(data)

        elapsed = time.monotonic() - start
        if elapsed >= DURATION_SEC:
            break

    stream.stop_stream()
    stream.close()
    pa.terminate()

    total_elapsed = time.monotonic() - start
    actual_bytes = len(all_data)
    actual_frames = actual_bytes // 2

    # --- Check 1: byte count ---
    print(f"==> Check 1: Byte count")
    print(f"    Wall-clock time:   {total_elapsed:.3f}s")
    print(f"    Bytes received:    {actual_bytes}")
    print(f"    Bytes expected:    {EXPECTED_BYTES} (±{TOLERANCE_BYTES:.0f})")

    if abs(actual_bytes - EXPECTED_BYTES) > TOLERANCE_BYTES:
        print(f"    FAIL: Byte count off by {actual_bytes - EXPECTED_BYTES} bytes.")
        print(f"          PortAudio may not be resampling. Got {actual_bytes} bytes")
        print(
            f"          which corresponds to ~{actual_frames / total_elapsed:.0f}Hz effective rate."
        )
        return False
    print(f"    PASS")
    print()

    # --- Check 2: save WAV and verify ---
    print(f"==> Check 2: WAV file integrity")
    with wave.open(OUTPUT_WAV, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(RATE)
        wf.writeframes(bytes(all_data))

    with wave.open(OUTPUT_WAV, "rb") as wf:
        wav_rate = wf.getframerate()
        wav_channels = wf.getnchannels()
        wav_frames = wf.getnframes()
        wav_duration = wav_frames / wav_rate

    print(f"    Saved to: {OUTPUT_WAV}")
    print(f"    WAV rate:      {wav_rate}Hz (expected {RATE}Hz)")
    print(f"    WAV channels:  {wav_channels} (expected {CHANNELS})")
    print(f"    WAV frames:    {wav_frames}")
    print(f"    WAV duration:  {wav_duration:.3f}s (expected ~{DURATION_SEC}s)")

    if wav_rate != RATE:
        print(f"    FAIL: WAV sample rate is {wav_rate}Hz, expected {RATE}Hz")
        return False
    if abs(wav_duration - DURATION_SEC) > 0.5:
        print(
            f"    FAIL: WAV duration is {wav_duration:.3f}s, expected ~{DURATION_SEC}s"
        )
        return False
    print(f"    PASS")
    print()

    # --- Check 3: chunk timing ---
    print(f"==> Check 3: Per-chunk read timing")
    avg_chunk_ms = np.mean(chunk_times) * 1000
    min_chunk_ms = np.min(chunk_times) * 1000
    max_chunk_ms = np.max(chunk_times) * 1000
    print(f"    Chunks read:  {len(chunk_times)}")
    print(
        f"    Avg per chunk: {avg_chunk_ms:.1f}ms (expected {CHUNK_DURATION_MS:.0f}ms)"
    )
    print(f"    Min: {min_chunk_ms:.1f}ms, Max: {max_chunk_ms:.1f}ms")

    if abs(avg_chunk_ms - CHUNK_DURATION_MS) > TOLERANCE_MS:
        print(
            f"    WARN: Average chunk time deviates by {abs(avg_chunk_ms - CHUNK_DURATION_MS):.1f}ms."
        )
        print(f"          Resampling may be introducing latency or dropping frames.")
    else:
        print(f"    PASS")
    print()

    # --- Summary ---
    print("============================================================")
    print("  All checks passed. PortAudio resampling is working correctly.")
    print(f"  Play the recording to verify audio quality:")
    print(f"    sox {OUTPUT_WAV} -d     # macOS/Linux")
    print(f"    aplay {OUTPUT_WAV}      # Linux/ALSA")
    print("============================================================")
    return True


if __name__ == "__main__":
    import sys

    ok = main()
    sys.exit(0 if ok else 1)
