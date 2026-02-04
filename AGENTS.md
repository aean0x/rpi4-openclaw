# AGENTS.md

## Overview

NixOS configuration flake for Raspberry Pi 4 running OpenClaw gateway + Signal CLI REST API. The system is **immutable** at the OS level while running services in **Docker containers**.

**Target Hardware:** Raspberry Pi 4 (mono-device).
**Services:** OpenClaw gateway, Signal CLI REST API.

## File Structure

```
├── flake.nix              # Entry point. Outputs: nixosConfigurations.openclaw, packages.aarch64-linux.sdImage
├── settings.nix           # Public config (IP, Hostname, Ports)
├── deploy                 # Master control script
├── host/
│   ├── configuration.nix  # Base OS: Networking, Users, SSH
│   ├── devices.nix        # Hardware config (RPi4 only)
│   ├── services.nix       # Container definitions (openclaw-gateway, signal-cli)
│   └── scripts.nix        # Shell scripts installed on host
└── secrets/
    ├── secrets.yaml       # Encrypted data store
    └── sops.nix           # Decryption config
```

## Configuration Split

- **`settings.nix`**: Network, ports, hostname. No secrets.
- **`secrets/secrets.yaml`**: Tokens and API keys. Decrypted at runtime by sops-nix.

## Service Stack

| Service | Port | Notes |
|---------|------|-------|
| **OpenClaw Gateway** | `18789` | Main gateway endpoint |
| **OpenClaw Bridge** | `18790` | Bridge communication |
| **Signal CLI REST** | `8080` | Signal messaging API |

## Secrets Schema

```yaml
user_hashedPassword: "$6$..."           # mkpasswd -m SHA-512
openclaw_gateway_token: "hex-token"     # openssl rand -hex 32
claude_session_key: "sk-..."            # Claude API key
gemini_key: "..."                       # Gemini API key
grok_key: "..."                         # Grok API key
signal_phone_number: "+1234567890"      # International format
wifi_psk: "password"                    # Only if enableWifi = true
```

## Workflow

1. **Do not invent file paths.** Check `settings.nix`.
2. **Secrets go in `secrets.yaml`**, use `./secrets/encrypt`.
3. **Prefer `remote-switch`** over on-device builds.
4. **Debugging:**
   - `deploy docker-ps` → running?
   - `deploy logs [container]` → app logs
   - `deploy system-info` → disk/RAM?
