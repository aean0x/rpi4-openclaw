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
      gemini_key = { };
      grok_key = { };
      signal_phone_number = { };
      wifi_psk = { };
    };
  };
}
