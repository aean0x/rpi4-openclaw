# NixOS OpenClaw Gateway (Raspberry Pi 4)

A NixOS configuration flake for running an OpenClaw AI gateway on a Raspberry Pi 4. Designed for **stability and reproducibility** on resource-constrained hardware.

## Features

- **OpenClaw Gateway** (Docker) - AI-powered messaging gateway
- **SOPS-encrypted secrets** - Gateway tokens and API keys encrypted at rest
- **Unified Management** - `./deploy` wrapper for builds, deployments, and debugging

## Prerequisites

- Linux workstation with Nix installed (with flake support)
- Git
- SSH key pair
- Raspberry Pi 4 (2GB+ RAM recommended)
- MicroSD card (16GB+)

## Initial Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/aean0x/rpi4-openclaw.git
   cd rpi4-openclaw
   ```

2. **Configure `settings.nix`**
   - `repoUrl`: Your fork (e.g. `"youruser/rpi4-openclaw"`)
   - `hostName`: Network hostname (default: `openclaw`)
   - `network`: Static IP configuration
   - `gatewayPort` / `bridgePort`: OpenClaw service ports

3. **Configure Secrets**
   ```bash
   cd secrets
   ./encrypt
   ```
   Fill in:
   - `user_hashedPassword` (generate with `mkpasswd -m SHA-512`)
   - `openclaw_gateway_token` (generate with `openssl rand -hex 32`)
   - `claude_session_key` (your Claude API session key)

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "Initial config"
   ```

## Build & Flash SD Image

```bash
./deploy build-sd
```

Follow the prompts to flash directly, or use the output with `dd` / Etcher manually.

## First Boot

1. Insert SD card and power on
2. Wait for initialization (~2 minutes)
3. SSH into the device:
   ```bash
   ssh user@openclaw.local
   ```

## Management

Use the `./deploy` wrapper from your workstation:

```bash
# Apply configuration changes (builds on workstation, deploys to device)
./deploy remote-switch

# Check logs
./deploy logs

# Check system health
./deploy system-info
```

### Available Commands

| Command | Description |
| :--- | :--- |
| `remote-switch` | Build on workstation, switch immediately |
| `remote-boot` | Build on workstation, activate on reboot |
| `logs [container]` | Tail container logs (default: openclaw-gateway) |
| `system-info` | Overview of memory, disk, and generation |
| `docker-ps` | List running containers |
| `docker-stats` | Real-time CPU/RAM usage |
| `cleanup` | Garbage collect old generations |

## Service Ports

| Service | Port |
| :--- | :--- |
| OpenClaw Gateway | `18789` |
| OpenClaw Bridge | `18790` |

## Project Structure

```
├── flake.nix              # Entry point: Host configs & SD image outputs
├── settings.nix           # Public configuration (IPs, Hostname, Ports)
├── shell.nix              # Dev shell (sops, ssh, nix tools)
├── deploy                 # Wrapper for SSH & Nix builds
├── host/                  # NixOS configuration
│   ├── configuration.nix  # Base OS (Network, Users, SSH)
│   ├── devices.nix        # Hardware config (RPi4)
│   ├── services.nix       # Docker container definitions
│   └── scripts.nix        # Host management scripts
└── secrets/               # SOPS-encrypted secrets
    ├── secrets.yaml       # Encrypted data store
    └── sops.nix           # Runtime decryption module
```

## OpenClaw Configuration

After first boot, connect to the gateway:
1. Access the gateway at `http://<device-ip>:18789`
2. Use your configured `openclaw_gateway_token` for authentication
3. Set up messaging channels via the CLI:
   ```bash
   ./deploy ssh
   docker exec -it openclaw-gateway node dist/index.js channels login
   ```

## Notes

- **Memory**: RPi4 has 2-4GB RAM; the gateway runs comfortably with zram enabled
- **Remote Building**: Always use `remote-*` commands to avoid OOM on the device
- **Auto-upgrade**: System updates automatically every Sunday at 3 AM