{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  user = "jeffrey";
  interface = "wlan0";
  hostname = "appletun";
  ssid = "Bill Wi the Science Fi";
in {
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
  };

  networking = {
    hostName = hostname;
    wireless = {
      enable = true;
      environmentFile = config.age.secrets.wifi-ssid.path;
      networks."@WIFI_SSID@" = {
        psk = "@SSID_PASSWORD@";
      };
      interfaces = [interface];
    };
  };
  environment.variables.EDITOR = "nvim";
  environment.systemPackages = with pkgs; [
    vim
    kitty
    git
    fish
    neovim
    bat
    inputs.agenix.packages.${system}.agenix
    gh
    cloudflared
    alejandra
    starship
    zoxide
  ];
  users = {
    mutableUsers = false;
    users."${user}" = {
      isNormalUser = true;
      hashedPasswordFile = config.age.secrets.login-password.path;
      extraGroups = ["wheel"];
      homix = true;
      shell = let 
      	colors = config.colorScheme.palette;
	in
	pkgs.callPackage ../../shell {inherit pkgs inputs colors; };
    };
  };
  imports = [./hardware-configuration.nix];

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "23.11";
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
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

  programs.starship = {
    enable = true;
    settings = {
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
    };
  };
}
