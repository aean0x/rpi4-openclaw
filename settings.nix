# System settings - edit for your setup
# Secrets (gateway tokens, API keys) go in secrets/secrets.yaml
let
  repoUrl = "aean0x/rpi4-openclaw";
  parts = builtins.filter (p: p != "") (builtins.split "/" repoUrl);
in
{
  # System identification
  hostName = "openclaw";
  description = "OpenClaw Gateway Server";
  timeZone = "Europe/Berlin";

  # Admin user
  adminUser = "user";

  # SSH configuration
  allowPasswordAuth = false;

  # SSH public keys for authentication
  sshPubKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICB8EtGX5PD1QPF/jrdd5G+fQy4tV2L3fhCY1dhZc4ep aean@nix-pc"
  ];

  # Repository coordinates
  inherit repoUrl;
  repoOwner = builtins.elemAt parts 0;
  repoName = builtins.elemAt parts 1;

  # Network configuration (static IP)
  network = {
    interface = "eth0";
    address = "192.168.1.100";
    prefixLength = 24;
    gateway = "192.168.1.1";
    dnsPrimary = "1.1.1.1";
    dnsSecondary = "8.8.8.8";
  };

  # Optional WiFi
  enableWifi = false;
  wifiSsid = "MyWifiNetwork";

  # Service ports
  gatewayPort = 18789;
  bridgePort = 18790;
  signalPort = 8080;

  # System
  stateVersion = "25.11";
}
