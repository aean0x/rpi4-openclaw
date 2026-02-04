# AGENTS.md

## Overview

NixOS configuration flake for Raspberry Pi 4 running an OpenClaw gateway server. The system is **immutable** at the OS level while running OpenClaw in a **Docker container** for isolation.

**Target Hardware:** Raspberry Pi 4 (mono-device, no multi-board support).
**Primary Service:** OpenClaw AI gateway.

## Architecture & File Structure

```
├── flake.nix              # Entry point. Outputs: `nixosConfigurations.openclaw` and `packages.aarch64-linux.sdImage`.
├── settings.nix           # Public configuration (IP, Hostname, Ports).
├── shell.nix              # Dev environment (sops, age, ssh, nix).
├── deploy                 # Master control script for SSH, builds, SD generation.
├── host/
│   ├── configuration.nix  # Base OS: Networking, Users, SSH, Journald.
│   ├── devices.nix        # Hardware config (RPi4 only, SD image, swap).
│   ├── services.nix       # OpenClaw container definition.
│   └── scripts.nix        # Shell scripts installed on the host.
└── secrets/
    ├── .sops.yaml         # Encryption rules (Age public keys).
    ├── secrets.yaml       # Encrypted data store.
    ├── sops.nix           # NixOS module to decrypt secrets at runtime.
    ├── encrypt            # Script: encrypts `secrets.yaml`.
    └── decrypt            # Script: decrypts `secrets.yaml` for editing.
```

## Core Design Patterns

### 1. Configuration Split
- **`settings.nix`**: Network topology, ports, hostname. No secrets.
- **`secrets/secrets.yaml`**: Gateway tokens, Claude API keys. Decrypted at runtime by `sops-nix`.

### 2. The Deployment Wrapper (`./deploy`)
All interactions go through `./deploy`:
- `deploy ssh` - Interactive shell
- `deploy remote-switch` - Build on workstation, deploy to device
- `deploy build-sd` - Generate initial SD image
- `deploy logs` - Tail OpenClaw container logs

### 3. Remote Building
RPi4 has limited RAM. Always prefer `deploy remote-switch` over `deploy switch`.

## Service Stack

Single container running OpenClaw gateway:

| Service | Port | Notes |
|---------|------|-------|
| **OpenClaw Gateway** | `18789` | Main gateway endpoint |
| **OpenClaw Bridge** | `18790` | Bridge communication port |

## Secrets Schema

Expected keys in `secrets/secrets.yaml`:

```yaml
user_hashedPassword: "$6$..."           # mkpasswd -m SHA-512
openclaw_gateway_token: "hex-token"     # openssl rand -hex 32
claude_session_key: "sk-..."            # Claude API key
wifi_psk: "password"                    # Only if enableWifi = true
```

## Workflow Guidelines

1. **Do not invent file paths.** Check `settings.nix` for structure.
2. **Secrets go in `secrets.yaml`**, not nix files. Use `./secrets/encrypt`.
3. **Prefer `remote-switch`** over on-device builds.
4. **Debugging loop:**
   - `deploy docker-ps` (running?)
   - `deploy logs` (app logs)
   - `deploy journal docker.service` (daemon logs)
   - `deploy system-info` (disk/RAM exhausted?)