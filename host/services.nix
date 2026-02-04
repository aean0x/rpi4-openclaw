{
  config,
  settings,
  pkgs,
  ...
}:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # Create composio network before containers start
  systemd.services.docker-network-composio = {
    description = "Create composio docker network";
    after = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.docker}/bin/docker network inspect composio >/dev/null 2>&1 || \
        ${pkgs.docker}/bin/docker network create composio
    '';
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {

      # ===================
      # Composio Stack
      # ===================
      composio-redis = {
        image = "redis:7-alpine";
        cmd = [ "redis-server" "--save" "60" "1" "--loglevel" "warning" ];
        volumes = [ "/var/lib/composio/redis:/data" ];
        extraOptions = [ "--network=composio" ];
        autoStart = true;
      };

      composio-postgres = {
        image = "postgres:16-alpine";
        environment = {
          POSTGRES_PASSWORD = "composio";
          POSTGRES_USER = "composio";
          POSTGRES_DB = "composio";
        };
        volumes = [ "/var/lib/composio/postgres:/var/lib/postgresql/data" ];
        extraOptions = [ "--network=composio" ];
        autoStart = true;
      };

      composio-worker = {
        image = "composiohq/composio-core:latest";
        dependsOn = [ "composio-redis" "composio-postgres" ];
        environmentFiles = [ "/run/composio.env" ];
        cmd = [ "celery" "-A" "composio.cli.worker" "worker" "--loglevel=info" ];
        extraOptions = [ "--network=composio" ];
        autoStart = true;
      };

      composio-core = {
        image = "composiohq/composio-core:latest";
        ports = [ "${toString settings.composioPort}:8000" ];
        dependsOn = [ "composio-redis" "composio-postgres" ];
        environment = {
          ENVIRONMENT = "PRODUCTION";
          DATABASE_URL = "postgresql://composio:composio@composio-postgres:5432/composio";
          REDIS_URL = "redis://composio-redis:6379/0";
          PORT = "8000";
          PLATFORM_ENVIRONMENT = "SELF_HOSTED_ENTERPRISE";
        };
        environmentFiles = [ "/run/composio.env" ];
        extraOptions = [ "--network=composio" ];
        autoStart = true;
      };

      # ===================
      # Signal CLI REST API
      # ===================
      signal = {
        image = "bbernhard/signal-cli-rest-api:latest";
        ports = [ "${toString settings.signalPort}:8080" ];
        volumes = [ "/var/lib/signal-cli:/home/.local/share/signal-cli" ];
        environment = { MODE = "native"; };
        environmentFiles = [ "/run/signal.env" ];
        extraOptions = [ "--network=composio" ];
        autoStart = true;
      };

      # ===================
      # OpenClaw Gateway
      # ===================
      openclaw = {
        image = "ghcr.io/openclaw/openclaw:latest";
        ports = [
          "${toString settings.gatewayPort}:18789"
          "${toString settings.bridgePort}:18790"
        ];
        volumes = [
          "/var/lib/openclaw/config:/home/node/.openclaw"
          "/var/lib/openclaw/workspace:/home/node/.openclaw/workspace"
        ];
        environment = {
          HOME = "/home/node";
          TERM = "xterm-256color";
        };
        environmentFiles = [ "/run/openclaw.env" ];
        cmd = [
          "node"
          "dist/index.js"
          "gateway"
          "--bind"
          "0.0.0.0"
          "--port"
          "18789"
        ];
        dependsOn = [ "composio-core" ];
        extraOptions = [
          "--network=composio"
          "--init"
        ];
        autoStart = true;
      };
    };
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
  };

  networking.firewall.allowedTCPPorts = [
    settings.gatewayPort
    settings.bridgePort
    settings.signalPort
    settings.composioPort
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "github:${settings.repoUrl}#${settings.hostName}";
    dates = "Sun *-*-* 03:00:00";
  };

  systemd.timers.restart-services = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:30:00";
      Persistent = true;
    };
  };

  systemd.services.restart-services = {
    script = ''
      ${config.virtualisation.docker.package}/bin/docker restart openclaw signal composio-core composio-worker || true
    '';
    serviceConfig.Type = "oneshot";
  };

  # Composio DB migration (one-shot on first boot)
  systemd.services.composio-migrate = {
    description = "Run Composio database migrations";
    after = [ "docker-composio-postgres.service" "docker-composio-redis.service" "docker-network-composio.service" ];
    requires = [ "docker-composio-postgres.service" "docker-composio-redis.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for postgres to be ready
      sleep 5
      ${pkgs.docker}/bin/docker run --rm \
        --network=composio \
        --env-file=/run/composio.env \
        -e DATABASE_URL=postgresql://composio:composio@composio-postgres:5432/composio \
        -e REDIS_URL=redis://composio-redis:6379/0 \
        composiohq/composio-core:latest \
        alembic upgrade head || true
    '';
  };

  # Ensure composio-core waits for migration
  systemd.services.docker-composio-core.after = [ "composio-migrate.service" ];
  systemd.services.docker-composio-worker.after = [ "composio-migrate.service" ];

  # Composio env setup
  systemd.services.docker-composio-core.preStart = ''
    mkdir -p /var/lib/composio/{redis,postgres}
    ENCRYPTION_KEY=$(cat ${config.sops.secrets.composio_encryption_key.path} 2>/dev/null || echo "")
    JWT_SECRET=$(cat ${config.sops.secrets.composio_jwt_secret.path} 2>/dev/null || echo "")
    {
      echo "ENCRYPTION_KEY=$ENCRYPTION_KEY"
      echo "JWT_SECRET=$JWT_SECRET"
    } > /run/composio.env
    chmod 600 /run/composio.env
  '';

  # OpenClaw env (gateway token only, model keys moved to Composio)
  systemd.services.docker-openclaw.preStart = ''
    mkdir -p /var/lib/openclaw/config /var/lib/openclaw/workspace
    TOKEN=$(cat ${config.sops.secrets.openclaw_gateway_token.path} 2>/dev/null || echo "")
    {
      echo "OPENCLAW_GATEWAY_TOKEN=$TOKEN"
    } > /run/openclaw.env
    chmod 600 /run/openclaw.env
  '';

  # Signal env
  systemd.services.docker-signal.preStart = ''
    mkdir -p /var/lib/signal-cli
    PHONE=$(cat ${config.sops.secrets.signal_phone_number.path} 2>/dev/null || echo "")
    {
      echo "SIGNAL_CLI_NUMBER=$PHONE"
    } > /run/signal.env
    chmod 600 /run/signal.env
  '';
}
