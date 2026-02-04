# Development shell for OpenClaw NixOS configuration
# Usage: nix-shell
{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Secrets management (encrypt/decrypt)
    age
    sops

    # Remote deployment
    openssh

    # Build tools
    nix
    git

    # Used in scripts
    gnugrep
    gnused
    coreutils
    bash

    # SD card flashing
    zstd
  ];

  shellHook = ''
    echo "OpenClaw Gateway development shell"
    echo ""
    echo "Available commands:"
    echo "  ./deploy <cmd>        - Unified management (SSH, build-sd, remote-build)"
    echo "  ./secrets/encrypt     - Encrypt secrets"
    echo "  ./secrets/decrypt     - Decrypt secrets for editing"
    echo ""
  '';
}
