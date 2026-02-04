{
  description = "NixOS OpenClaw Gateway (Raspberry Pi 4)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      nixos-hardware,
      ...
    }@inputs:
    let
      settings = import ./settings.nix;
      system = "aarch64-linux";

      keyFilePath = builtins.getEnv "KEY_FILE_PATH";
      keyContent = if keyFilePath != "" then builtins.readFile keyFilePath else "";
    in
    {
      nixosConfigurations.${settings.hostName} = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs settings;
          inherit nixos-hardware;
          inherit nixpkgs;
        };

        modules = [
          sops-nix.nixosModules.sops

          ./host/configuration.nix
          ./host/services.nix

          (
            { ... }:
            {
              system.activationScripts.setupSopsKey =
                if keyContent != "" then
                  ''
                    mkdir -p /var/lib/sops-nix
                    echo "${keyContent}" > /var/lib/sops-nix/key.txt
                    chmod 600 /var/lib/sops-nix/key.txt
                  ''
                else
                  "";
            }
          )
        ];
      };

      packages.${system}.sdImage =
        self.nixosConfigurations.${settings.hostName}.config.system.build.sdImage;
    };
}
