# SOPS secrets configuration for OpenClaw + Composio
{ ... }:
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      user_hashedPassword = { };
      openclaw_gateway_token = { };
      composio_encryption_key = { };
      composio_jwt_secret = { };
      signal_phone_number = { };
      wifi_psk = { };
    };
  };
}
