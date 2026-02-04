# NixOS OpenClaw Gateway (Raspberry Pi 4)

A NixOS configuration flake for running an OpenClaw AI gateway on a Raspberry Pi 4. Designed for **stability and reproducibility** on resource-constrained hardware.

## Features

- **OpenClaw Gateway** (Docker) - AI-powered messaging gateway
- **Signal CLI REST API** (Docker) - Signal messaging integration
- **SOPS-encrypted secrets** - Gateway tokens and API keys encrypted at rest
- **Unified Management** - `./deploy` wrapper for builds, deployments, and debugging

## Quick Start (Docker Only)

If you just want to run OpenClaw in Docker without the full NixOS setup:

```bash
# Create directories
mkdir -p ~/.openclaw/config ~/.openclaw/workspace ~/.signal-cli

# Generate a gateway token
export OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)

# Run OpenClaw gateway
docker run -d --name openclaw-gateway \
  -p 18789:18789 -p 18790:18790 \
  -v ~/.openclaw/config:/home/node/.openclaw \
  -v ~/.openclaw/workspace:/home/node/.openclaw/workspace \
  -e HOME=/home/node \
  -e OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN \
  -e CLAUDE_AI_SESSION_KEY=your-claude-key \
  -e GEMINI_API_KEY=your-gemini-key \
  -e GROK_API_KEY=your-grok-key \
  --init --restart unless-stopped \
  ghcr.io/openclaw/openclaw:latest \
  node dist/index.js gateway --bind lan --port 18789

# Run Signal CLI REST API (optional)
docker run -d --name signal-cli \
  -p 8080:8080 \
  -v ~/.signal-cli:/home/.local/share/signal-cli \
  -e MODE=native \
  --restart unless-stopped \
  bbernhard/signal-cli-rest-api:latest

# Link Signal to your phone
# Open http://localhost:8080/v1/qrcodelink?device_name=openclaw
# Scan with Signal app: Settings > Linked devices > +

# Test OpenClaw
curl -H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN" http://localhost:18789/health
```

## Full NixOS Setup (Raspberry Pi 4)

### Prerequisites

- Linux workstation with Nix installed (with flake support)
- Git, SSH key pair
- Raspberry Pi 4 (2GB+ RAM recommended)
- MicroSD card (16GB+)

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/aean0x/rpi4-openclaw.git
   cd rpi4-openclaw
   ```

2. **Configure `settings.nix`**
   - `repoUrl`: Your fork (e.g. `"youruser/rpi4-openclaw"`)
   - `hostName`: Network hostname (default: `openclaw`)
   - `network`: Static IP configuration

3. **Configure Secrets**
   ```bash
   cd secrets && ./encrypt
   ```
   Fill in:
   - `user_hashedPassword` - generate with `mkpasswd -m SHA-512`
   - `openclaw_gateway_token` - generate with `openssl rand -hex 32`
   - `claude_session_key`, `gemini_key`, `grok_key` - your AI API keys
   - `signal_phone_number` - international format (+1234567890)

4. **Commit and build**
   ```bash
   git add . && git commit -m "Initial config"
   ./deploy build-sd
   ```

### First Boot

1. Flash SD card, insert and power on
2. Wait ~2 minutes for initialization
3. SSH: `ssh user@openclaw.local`

### Link Signal

```bash
# On your workstation, open in browser:
http://<device-ip>:8080/v1/qrcodelink?device_name=openclaw

# Scan with Signal app: Settings > Linked devices > +
```

## Management

```bash
./deploy remote-switch   # Apply config changes
./deploy logs            # OpenClaw logs
./deploy logs signal-cli # Signal logs
./deploy system-info     # System health
./deploy docker-ps       # List containers
```

## Service Ports

| Service | Port |
| :--- | :--- |
| OpenClaw Gateway | `18789` |
| OpenClaw Bridge | `18790` |
| Signal CLI REST | `8080` |

## Project Structure

```
├── flake.nix              # Entry point
├── settings.nix           # Public config (IPs, Hostname, Ports)
├── deploy                 # Management wrapper
├── host/
│   ├── configuration.nix  # Base OS
│   ├── devices.nix        # Hardware (RPi4)
│   ├── services.nix       # Docker containers
│   └── scripts.nix        # Host scripts
└── secrets/
    ├── secrets.yaml       # Encrypted secrets
    └── sops.nix           # Decryption config
```

## Notes

- **Memory**: RPi4 has 2-4GB RAM; services run comfortably with zram
- **Remote Building**: Always use `remote-*` commands to avoid OOM
- **Auto-upgrade**: System updates every Sunday at 3 AM
