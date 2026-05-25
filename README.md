# Jarvis Assistant

A self-contained, always-on voice AI agent running on Raspberry Pi 4.

Wake word → speak → agent responds → idle. No local inference required — cloud APIs handle STT, LLM, and TTS while the Pi manages audio I/O and hosts the LiveKit server.

---

## Hardware Requirements

- **Raspberry Pi 4** (4GB+ RAM)
- **Raspberry Pi OS Lite 64-bit (aarch64)** — must be 64-bit; the LiveKit Docker image is ARM64-only
- **USB audio adapter** or USB mic + 3.5mm speaker (or USB speaker)
- Outbound internet access on port 443 (for Deepgram, OpenAI, Cartesia)

---

## Stack

| Layer | Component |
|---|---|
| Audio capture/playback | ALSA + PyAudio / sounddevice |
| Wake word | openwakeword (ONNX, on-device) |
| Voice transport | LiveKit server (Docker, local) |
| STT | Deepgram (streaming, nova-3 model) |
| LLM | OpenAI gpt-4o-mini (low latency) |
| TTS | Cartesia |
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
   # Edit .env with your DEEPGRAM_API_KEY, OPENAI_API_KEY, CARTESIA_API_KEY
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
   source .venv/bin/activate
   python agent/agent.py dev
   ```

8. **Start the wake word listener** (in another terminal):
   ```bash
   source .venv/bin/activate
   python agent/main.py
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

---

## Configuration Reference

All secrets and tunable values live in `.env`:

| Variable | Description |
|---|---|
| `LIVEKIT_URL` | WebSocket URL for the local LiveKit server (default: `ws://localhost:7880`) |
| `LIVEKIT_API_KEY` | LiveKit API key — must match `docker/livekit.yaml` |
| `LIVEKIT_API_SECRET` | LiveKit API secret — must match `docker/livekit.yaml` |
| `DEEPGRAM_API_KEY` | Deepgram API key for streaming STT (nova-3 model) |
| `OPENAI_API_KEY` | OpenAI API key for LLM (gpt-4o-mini) |
| `CARTESIA_API_KEY` | Cartesia API key for TTS |

Additional tunable constants in `agent/wake.py`:

| Constant | Default | Description |
|---|---|---|
| `WAKE_WORD` | `hey_jarvis` | Wake word model name; openwakeword supports custom model training |
| `THRESHOLD` | `0.5` | Detection confidence threshold (0.0–1.0) |
| `ROOM_NAME` | `voice-agent-room` | LiveKit room name; static is fine for single-device use |

---

## Known Issues / Gotchas

- **Must be 64-bit Pi OS** — the LiveKit Docker image is ARM64-only. Verify with `uname -m` (must return `aarch64`).
- **`network_mode: host` is non-negotiable** — WebRTC will not function correctly without it on Linux. Do not remove it from `docker-compose.yaml`.
- **ALSA card indices vary by hardware** — run `arecord -l` and `aplay -l` to get correct values; indices shift if you plug/unplug USB devices.
- **openwakeword runs at 16kHz** — ensure your ALSA capture rate matches (the default config uses 16000 Hz).
- **Agent worker must start before wake word listener** — the systemd `After=livekit-agent.service` dependency handles this automatically.
- **Cartesia and Deepgram stream over HTTPS** — the Pi needs outbound internet access on port 443. Local-only network setups will not work.
- **Docker group membership** — after `scripts/setup.sh`, you must log out and back in (or run `newgrp docker`) before `docker` commands work without `sudo`.
