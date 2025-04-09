{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    # We don't need to add user keys to host keys. These will be keys in /etc/ssh by default. See `secrets/README.md` for explanation of the difference.
    # hostKeys = ["~/.ssh/id_ed25519"];
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22];
  };
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
    description = "Cloudflare Tunnel user";
    home = "/var/lib/cloudflared";
    createHome = true;
  };
  users.groups.cloudflared = {};
  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel";
    after = ["network.target" "network-online.target"];
    wants = ["network.target" "network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run";
      Restart = "always";
      EnvironmentFile = [config.age.secrets.cloudflared-environment.path];
      RestartSec = "5s";
      User = "cloudflared";
      Group = "cloudflared";
    };
  };
  environment.systemPackages = with pkgs; [
    inputs.agenix.packages.${system}.agenix
    cloudflared
  ];
}
