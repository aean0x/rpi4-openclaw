# AGENTS.md

## Overview

NixOS configuration for Raspberry Pi 4 running OpenClaw gateway + Composio (self-hosted credential broker) + Signal CLI. All containers on private docker network. Model API keys isolated in Composio, never in OpenClaw process memory.

## File Structure

```
├── flake.nix              # Entry point
├── settings.nix           # Public config (IP, Hostname, Ports)
├── deploy                 # Master control script
├── host/
│   ├── configuration.nix  # Base OS + Hardware (RPi4)
│   ├── services.nix       # Container definitions + systemd services
│   └── scripts.nix        # Host scripts + dynamic container exec
└── secrets/
    ├── secrets.yaml       # Encrypted secrets
    └── sops.nix           # Decryption config
```

## Container Stack

All containers on `composio` docker network:

| Container | Image | Purpose |
|-----------|-------|---------|
| composio-redis | redis:7-alpine | Composio cache |
| composio-postgres | postgres:16-alpine | Composio DB |
| composio-worker | composiohq/composio-core | Celery worker |
| composio-core | composiohq/composio-core | API + dashboard (:8000) |
| signal | bbernhard/signal-cli-rest-api | Signal messaging (:8080) |
| openclaw | ghcr.io/openclaw/openclaw | Gateway (:18789, :18790) |

## Secrets Schema

```yaml
user_hashedPassword: "$6$..."        # mkpasswd -m SHA-512
openclaw_gateway_token: "..."        # openssl rand -hex 32
composio_encryption_key: "..."       # openssl rand -hex 32
composio_jwt_secret: "..."           # openssl rand -hex 32
signal_phone_number: "+1234567890"
wifi_psk: "..."                      # if enableWifi = true
```

## Dynamic Container Exec

Any container name works as a command:
```bash
./deploy openclaw status
./deploy composio-core env
./deploy composio-postgres  # opens psql
./deploy signal curl localhost:8080/v1/about
```

On device:
```bash
openclaw onboard
composio-postgres
```

## Post-Deploy Config

1. Composio: `http://<ip>:8000` → create admin → connect apps
2. OpenClaw config (`/var/lib/openclaw/config/openclaw.json`):
   ```json
   {
     "tools": { "provider": "composio", "endpoint": "http://composio-core:8000/mcp" },
     "channels": { "signal": { "httpUrl": "http://signal:8080" } }
   }
   ```
3. Signal: `http://<ip>:8080/v1/qrcodelink?device_name=openclaw`

## Debugging

```bash
./deploy docker-ps           # container status
./deploy logs composio-core  # composio logs
./deploy logs openclaw       # gateway logs
./deploy system-info         # RAM/disk
```
