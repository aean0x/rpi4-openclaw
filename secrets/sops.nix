# SOPS secrets configuration for OpenClaw
{ ... }:
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      user_hashedPassword = { };
      openclaw_gateway_token = { };
      claude_session_key = { };
      wifi_psk = { };
    };
  };
}
