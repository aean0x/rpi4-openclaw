# Base system configuration for OpenClaw gateway
# Handles: networking, SSH, users, journald, Nix settings, WiFi (optional via sops)
{
  config,
  lib,
  settings,
  ...
}:
{
  imports = [
    ../secrets/sops.nix
    ./scripts.nix
  ];

  # ===================
  # Networking
  # ===================
  networking = {
    hostName = settings.hostName;

    interfaces.${settings.network.interface}.ipv4.addresses = [
      {
        address = settings.network.address;
        prefixLength = settings.network.prefixLength;
      }
    ];

    defaultGateway = settings.network.gateway;
    nameservers = [
      settings.network.dnsPrimary
      settings.network.dnsSecondary
    ];

    wireless = lib.mkIf (settings.enableWifi or false) {
      enable = true;
      networks."${settings.wifiSsid}".pskFile = config.sops.secrets.wifi_psk.path;
    };
  };

  # ===================
  # SSH & Discovery
  # ===================
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = settings.allowPasswordAuth;
    settings.PermitRootLogin = "no";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };

  # ===================
  # User
  # ===================
  users.users.${settings.adminUser} = {
    isNormalUser = true;
    description = settings.description;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets.user_hashedPassword.path;
    openssh.authorizedKeys.keys = settings.sshPubKeys;
  };

  security.sudo.wheelNeedsPassword = false;

  # ===================
  # Logging & Misc
  # ===================
  services.journald.extraConfig = "SystemMaxUse=200M";

  boot.supportedFilesystems.zfs = false;

  nix.settings.trusted-users = [ "@wheel" ];

  # ===================
  # System
  # ===================
  time.timeZone = settings.timeZone;
  system.stateVersion = settings.stateVersion;

  # ===================
  # WiFi PSK secret (only when WiFi is enabled)
  # ===================
  sops.secrets.wifi_psk = lib.mkIf (settings.enableWifi or false) {
    sopsFile = ../secrets/secrets.yaml;
    format = "yaml";
    path = "/run/wifi_psk.txt";
    mode = "0400";
  };
}
