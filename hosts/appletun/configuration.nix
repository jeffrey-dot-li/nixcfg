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
      environmentFile =  config.age.secrets.wifi-ssid.path;
      networks."@WIFI_SSID@" = { 
      psk = "@SSID_PASSWORD@"; 
      };
      interfaces = [interface];
    };
  };
  environment.variables.EDITOR =  "nvim";
  environment.systemPackages = with pkgs; [
    vim
    kitty
    git
    fish
    neovim
    bat
    inputs.agenix.packages.${system}.agenix
  ];
  users = {
    mutableUsers = false;
    users."${user}" = {
      isNormalUser = true;
      hashedPasswordFile = config.age.secrets.login-password.path; 
      extraGroups = ["wheel"];
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
}
