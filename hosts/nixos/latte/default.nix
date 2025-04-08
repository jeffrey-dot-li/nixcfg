{
  inputs,
  pkgs,
  lib,
  ...
}: let
  user = "jeffreyli";
in {
  imports = [
    ./hardware-configuration.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "latte";
  # networking.wireless.enable = true;

  # Network proxy

  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.enable = true;

  # KDE Plasma Desktop Environment
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # CUPS to print documents?
  services.printing.enable = true;

  # User account:
  users.users.li = {
    isNormalUser = true;
    description = "Li";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # Auto login

  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "li";

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.11";
}
