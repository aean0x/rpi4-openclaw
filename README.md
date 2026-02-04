# NixOS OpenClaw Gateway (Raspberry Pi 4)

A NixOS configuration flake for running an OpenClaw AI gateway with **Composio** (self-hosted credential broker) on a Raspberry Pi 4. Designed for **security** (keys never touch OpenClaw), **stability**, and **reproducibility**.

## Features

- **OpenClaw Gateway** (Docker) - AI-powered messaging gateway
- **Composio** (Docker) - Self-hosted credential broker (OAuth/API keys isolated from agent)
- **Signal CLI REST API** (Docker) - Signal messaging integration
- **SOPS-encrypted secrets** - Gateway tokens encrypted at rest
- **Unified Management** - `./deploy` wrapper for builds, deployments, and debugging

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Network: composio                 │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────┐ │
│  │  redis   │  │ postgres │  │  worker  │  │composio-core│ │
│  └──────────┘  └──────────┘  └──────────┘  └──────┬──────┘ │
│                                                    │:8000   │
│  ┌──────────┐  ┌──────────────────────────────────┴──────┐ │
│  │  signal  │  │               openclaw                   │ │
│  │  :8080   │  │ (tools.provider=composio)       :18789  │ │
│  └──────────┘  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Security model:** OpenClaw calls Composio for tool execution. Raw API keys (Gmail, GitHub, Slack, etc.) live only in Composio's encrypted store. Even if the agent is compromised, tokens can't be exfiltrated.

## Quick Start (Docker Only)

If you just want to run the stack without NixOS:

```bash
# Create directories
mkdir -p ~/.openclaw/{config,workspace} ~/.composio/{redis,postgres} ~/.signal-cli

# Generate secrets
export OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
export COMPOSIO_ENCRYPTION_KEY=$(openssl rand -hex 32)
export COMPOSIO_JWT_SECRET=$(openssl rand -hex 32)

# Create network
docker network create composio

# Start Composio stack
docker run -d --name composio-redis --network composio \
  -v ~/.composio/redis:/data redis:7-alpine

docker run -d --name composio-postgres --network composio \
  -e POSTGRES_USER=composio -e POSTGRES_PASSWORD=composio -e POSTGRES_DB=composio \
  -v ~/.composio/postgres:/var/lib/postgresql/data postgres:16-alpine

# Wait for postgres, then migrate
sleep 5
docker run --rm --network composio \
  -e DATABASE_URL=postgresql://composio:composio@composio-postgres:5432/composio \
  -e REDIS_URL=redis://composio-redis:6379/0 \
  composiohq/composio-core:latest alembic upgrade head

# Start Composio core + worker
docker run -d --name composio-core --network composio -p 8000:8000 \
  -e DATABASE_URL=postgresql://composio:composio@composio-postgres:5432/composio \
  -e REDIS_URL=redis://composio-redis:6379/0 \
  -e ENCRYPTION_KEY=$COMPOSIO_ENCRYPTION_KEY \
  -e JWT_SECRET=$COMPOSIO_JWT_SECRET \
  -e PLATFORM_ENVIRONMENT=SELF_HOSTED_ENTERPRISE \
  composiohq/composio-core:latest

docker run -d --name composio-worker --network composio \
  -e DATABASE_URL=postgresql://composio:composio@composio-postgres:5432/composio \
  -e REDIS_URL=redis://composio-redis:6379/0 \
  -e ENCRYPTION_KEY=$COMPOSIO_ENCRYPTION_KEY \
  composiohq/composio-core:latest celery -A composio.cli.worker worker --loglevel=info

# Start OpenClaw
docker run -d --name openclaw --network composio -p 18789:18789 -p 18790:18790 \
  -v ~/.openclaw/config:/home/node/.openclaw \
  -v ~/.openclaw/workspace:/home/node/.openclaw/workspace \
  -e HOME=/home/node -e OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN \
  --init ghcr.io/openclaw/openclaw:latest \
  node dist/index.js gateway --bind 0.0.0.0 --port 18789

# Start Signal
docker run -d --name signal --network composio -p 8080:8080 \
  -v ~/.signal-cli:/home/.local/share/signal-cli \
  -e MODE=native bbernhard/signal-cli-rest-api:latest
```

## Post-Deploy Setup

1. **Configure Composio** - Open `http://<ip>:8000`, create admin account
2. **Connect Apps** - In Composio dashboard: Apps → connect Gmail, GitHub, Slack, etc.
3. **Configure OpenClaw** - Add to `/var/lib/openclaw/config/openclaw.json`:
   ```json
   {
     "tools": { "provider": "composio", "endpoint": "http://composio-core:8000/mcp" },
     "channels": { "signal": { "httpUrl": "http://signal:8080" } }
   }
   ```
4. **Link Signal** - Visit `http://<ip>:8080/v1/qrcodelink?device_name=openclaw`, scan with Signal app

## Full NixOS Setup

### Prerequisites

- Linux workstation with Nix (flake support)
- Git, SSH key pair
- Raspberry Pi 4 (4GB+ RAM recommended for full stack)
- MicroSD card (32GB+ recommended)

### Initial Setup

1. **Clone and configure**
   ```bash
   git clone https://github.com/aean0x/rpi4-openclaw.git && cd rpi4-openclaw
   # Edit settings.nix (network, hostname)
   cd secrets && ./encrypt  # Fill in secrets
   git add . && git commit -m "Initial config"
   ```

2. **Build and flash**
   ```bash
   ./deploy build-sd
   ```

3. **First boot** - SSH in: `ssh user@openclaw.local`

## Management

```bash
./deploy remote-switch      # Apply config changes
./deploy openclaw onboard   # Run onboarding wizard
./deploy openclaw status    # Check status
./deploy composio-core env  # Check composio env
./deploy logs               # OpenClaw logs
./deploy docker-ps          # List all containers
```

## Service Ports

| Service | Port | Description |
|---------|------|-------------|
| OpenClaw Gateway | 18789 | Main API endpoint |
| OpenClaw Bridge | 18790 | Bridge communication |
| Signal CLI REST | 8080 | Signal messaging API |
| Composio Dashboard | 8000 | Credential management UI |

## Secrets

Generate before first build:
```bash
openssl rand -hex 32  # openclaw_gateway_token
openssl rand -hex 32  # composio_encryption_key
openssl rand -hex 32  # composio_jwt_secret
mkpasswd -m SHA-512   # user_hashedPassword
```

## Notes

- **RAM**: Full stack uses ~1.5-2GB. RPi4 4GB recommended.
- **Security**: Model API keys go in Composio, not OpenClaw env.
- **Networking**: All containers on private `composio` bridge network.
