{
  config,
  settings,
  ...
}:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      openclaw-gateway = {
        image = "ghcr.io/openclaw/openclaw:latest";
        volumes = [
          "/var/lib/openclaw/config:/home/node/.openclaw"
          "/var/lib/openclaw/workspace:/home/node/.openclaw/workspace"
        ];
        environment = {
          HOME = "/home/node";
          TERM = "xterm-256color";
        };
        environmentFiles = [ "/run/openclaw.env" ];
        ports = [
          "${toString settings.gatewayPort}:18789"
          "${toString settings.bridgePort}:18790"
        ];
        cmd = [
          "node"
          "dist/index.js"
          "gateway"
          "--bind"
          "lan"
          "--port"
          "18789"
        ];
        extraOptions = [ "--init" ];
        autoStart = true;
      };
    };
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
  };

  networking.firewall = {
    allowedTCPPorts = [
      settings.gatewayPort
      settings.bridgePort
    ];
  };

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "github:${settings.repoUrl}#${settings.hostName}";
    dates = "Sun *-*-* 03:00:00";
  };

  systemd.timers.restart-openclaw = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:30:00";
      Persistent = true;
    };
  };

  systemd.services.restart-openclaw = {
    script = ''
      ${config.virtualisation.docker.package}/bin/docker restart openclaw-gateway || true
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.docker-openclaw-gateway.preStart = ''
    mkdir -p /var/lib/openclaw/config /var/lib/openclaw/workspace
    TOKEN=$(cat ${config.sops.secrets.openclaw_gateway_token.path} 2>/dev/null || echo "")
    CLAUDE_KEY=$(cat ${config.sops.secrets.claude_session_key.path} 2>/dev/null || echo "")
    {
      echo "OPENCLAW_GATEWAY_TOKEN=$TOKEN"
      echo "CLAUDE_AI_SESSION_KEY=$CLAUDE_KEY"
    } > /run/openclaw.env
    chmod 600 /run/openclaw.env
  '';
}
