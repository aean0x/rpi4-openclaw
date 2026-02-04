# Hardware configuration for Raspberry Pi 4
# Mono-device config - no multi-board switching
{
  nixos-hardware,
  nixpkgs,
  ...
}:
{
  imports = [
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    "${nixos-hardware}/raspberry-pi/4"
  ];

  # Swap configuration for 2GB+ RAM boards
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 2048;
    }
  ];
}
