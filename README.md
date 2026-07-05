# Jarvis Assistant

A self-contained, always-on voice AI agent running on Raspberry Pi 4 (with macOS supported for local development).

Wake word → speak → agent responds → idle. The Pi manages audio I/O and hosts the LiveKit server; STT/TTS use Cartesia and the LLM is served via Ollama Cloud.

---

## Hardware Requirements

Production (Raspberry Pi):

- **Raspberry Pi 4** (4GB+ RAM)
- **Raspberry Pi OS Lite 64-bit (aarch64)** — must be 64-bit; the LiveKit Docker image is ARM64-only
- **USB audio adapter** or USB mic + 3.5mm speaker (or USB speaker)
- Outbound internet access on port 443 (for Cartesia and Ollama Cloud)

Development (macOS, optional):

- **macOS on Apple Silicon (arm64)** — see [Development on macOS](#development-on-macos)
- Python 3.13 (tensorflow has no wheels for 3.14+)
- Built-in or USB mic + speakers

---

## Stack

| Layer | Component |
|---|---|
| Audio capture/playback | ALSA + PyAudio (Pi) / PyAudio + CoreAudio (macOS) |
| Wake word | openwakeword (TFLite preferred, ONNX fallback, on-device) |
| Voice transport | LiveKit server (Docker, local) |
| STT | Cartesia (`ink-whisper` model) |
| LLM | Ollama Cloud `gpt-oss:20b-cloud` (via OpenAI-compatible endpoint) |
| TTS | Cartesia |
| VAD | Silero (on-device) |
| Agent framework | livekit-agents Python SDK (~1.5.x) |
| State broker | Redis (Docker, local) |

---

## Quick Start

1. **Clone the repo** onto your Pi:
   ```bash
   git clone <repo-url> ~/jarvis-assistant
   cd ~/jarvis-assistant
   ```

2. **Configure environment** — copy the example and fill in your API keys:
   ```bash
   cp .env.example .env
   # Edit .env with your OLLAMA_API_KEY and CARTESIA_API_KEY
   ```

3. **Run setup** — installs system packages, creates the Python venv, configures the firewall:
   ```bash
   scripts/setup.sh
   # Log out and back in after this step for docker group membership
   ```

4. **Test audio** — verify mic and speaker are working:
   ```bash
   scripts/test-audio.sh
   ```

5. **Start Docker services** (LiveKit + Redis):
   ```bash
   cd docker && docker compose up -d
   ```

6. **Verify LiveKit is up** (expect a 404 response):
   ```bash
   curl http://localhost:7880
   ```

7. **Start the agent worker**:
   ```bash
   uv run python agent/agent.py dev
   ```

8. **Start the wake word listener** (in another terminal):
   ```bash
   uv run python agent/main.py
   ```

9. **Say "Hey Jarvis"** and ask your question. The agent will respond through the speaker.

---

## Audio Configuration

ALSA card indices vary by hardware and can shift when USB devices are plugged/unplugged.

1. Find your device indices:
   ```bash
   arecord -l   # capture devices (mic)
   aplay -l     # playback devices (speaker)
   ```

2. Create `~/.asoundrc` with the correct card and device numbers, for example:
   ```
   defaults.pcm.card 1
   defaults.pcm.device 0
   defaults.ctl.card 1
   ```

3. Update `scripts/test-audio.sh` if your mic is not on `plughw:1,0`.

---

## Run on Boot (systemd)

Install the two systemd services so everything starts automatically after reboot:

```bash
sudo cp systemd/livekit-agent.service /etc/systemd/system/
sudo cp systemd/livekit-wake.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable livekit-agent livekit-wake
sudo systemctl start livekit-agent livekit-wake
```

Check status:
```bash
sudo systemctl status livekit-agent
sudo systemctl status livekit-wake
journalctl -u livekit-agent -f
```

> Note: the systemd units invoke `.venv/bin/python` directly (the venv is created by `uv` in `scripts/setup.sh`). They run `agent.py start` (production mode); for interactive development use `uv run python agent/agent.py dev` instead — `dev` enables hot-reload and verbose logging.

---

## Configuration Reference

All secrets and tunable values live in `.env`:

| Variable | Description |
|---|---|
| `LIVEKIT_URL` | WebSocket URL for the local LiveKit server (default: `ws://localhost:7880`) |
| `LIVEKIT_API_KEY` | LiveKit API key — must match `docker/livekit.yaml` |
| `LIVEKIT_API_SECRET` | LiveKit API secret — must match `docker/livekit.yaml` |
| `OLLAMA_API_KEY` | Ollama Cloud API key for the `gpt-oss:20b-cloud` LLM |
| `CARTESIA_API_KEY` | Cartesia API key (used for both STT and TTS) |

Additional tunable constants:

| Constant | File | Default | Description |
|---|---|---|---|
| `WAKE_WORD` | `agent/wake.py` | `hey_jarvis` | Wake word model name; openwakeword supports custom model training |
| `THRESHOLD` | `agent/wake.py` | `0.5` | Detection confidence threshold (0.0–1.0) |
| `ROOM_NAME` | `agent/main.py` | `voice-agent-room` | LiveKit room name; static is fine for single-device use |

---

## Known Issues / Gotchas

- **Must be 64-bit Pi OS** — the LiveKit Docker image is ARM64-only. Verify with `uname -m` (must return `aarch64`).
- **`network_mode: host` is non-negotiable** — WebRTC will not function correctly without it on Linux. Do not remove it from `docker-compose.yaml`.
- **ALSA card indices vary by hardware** — run `arecord -l` and `aplay -l` to get correct values; indices shift if you plug/unplug USB devices.
- **openwakeword runs at 16kHz** — ensure your ALSA capture rate matches (the default config uses 16000 Hz).
- **Agent worker must start before wake word listener** — the systemd `After=livekit-agent.service` dependency handles this automatically.
- **Cartesia and Ollama Cloud stream over HTTPS** — the Pi needs outbound internet access on port 443. Local-only network setups will not work.
- **Docker group membership** — after `scripts/setup.sh`, you must log out and back in (or run `newgrp docker`) before `docker` commands work without `sudo`.
- **openwakeword ships without model weights** — the package only contains code; `scripts/setup.sh` downloads the required `.onnx`/`.tflite` files after installing dependencies. If you installed the Python deps another way, run `uv run python -c "from openwakeword.utils import download_models; download_models(['hey_jarvis'])"` once to fetch them.
- **Inference framework is platform-dependent** — `agent/wake.py` auto-detects `tflite-runtime` (Pi/Linux), then tensorflow with the macOS shim (Apple Silicon), then falls back to `onnxruntime`. ONNX is known to produce near-zero scores on macOS ARM64, so the shim is preferred there.

---

## Development on macOS

For local development on Apple Silicon without a Pi:

1. **Install uv** (if not already present):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

2. **Run the macOS setup** (creates the `tflite_runtime` shim over tensorflow, using uv to provision Python 3.13 and the venv):
   ```bash
   agent/setup_macos.sh
   ```
   Requires Python 3.13 — tensorflow has no wheels for 3.14+. The script uses `uv python install 3.13` to fetch it.

3. **Install deps and run** (uv auto-discovers `.venv`, no activation needed):
   ```bash
   uv pip install -r agent/requirements.txt
   uv run python agent/agent.py dev   # in one terminal
   uv run python agent/main.py        # in another
   ```

4. **Test audio** (uses SoX instead of ALSA):
   ```bash
   brew install sox
   scripts/test-audio.sh
   ```

5. **Skip Docker on macOS for casual testing** — LiveKit/Redis can run via Docker Desktop, but `network_mode: host` behaves differently on macOS. For full end-to-end validation, run on a Pi.

`scripts/test-audio.sh` and `scripts/verify-resampling.py` both have macOS code paths; `agent/wake.py` auto-detects the platform.
