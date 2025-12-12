{
  inputs,
  pkgs,
  lib,
  config,
  self',
  ...
}: let
  user = "jeffreyli";
  keys = import ../../../secrets/ssh_keys.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ./cloudflare.nix
    ./secrets.nix
    ./gpu.nix
    ./steam.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network proxy
  networking = {
    hostName = "latte";
    # Juse use ethernet by default.

    # wlps11s0 not working for some reason in `ip a`? TODO: Figure this out
    # wireless = {
    #   enable = true;
    #   secretsFile = config.age.secrets.wifi-ssid.path;
    #   # Bruh our fcking wifi ssid has a space in it :/ otherwise can use ext:WIFI_SSID
    #   networks."Wabu Wabu" = {
    #     pskRaw = "ext:SSID_PASSWORD";
    #   };
    #   interfaces = ["wlp11s0"];
    # };
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.enable = true;
  hardware.graphics.enable = true;
  # hardware.graphics.enable32Bit = true;
  # KDE Plasma Desktop Environment
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Select internationalisation properties.

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # CUPS to print documents?
  services.printing.enable = true;

  # User account:
  users.users."${user}" = {
    isNormalUser = true;
    shell = self'.packages.fish;
    description = "Li";
    openssh.authorizedKeys.keys = [
      keys.users.jeffreyli
      keys.users.junli
    ];
    extraGroups = ["networkmanager" "wheel" "docker"];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  environment.systemPackages = with pkgs; [
    minikube
    docker
    k3s
    kubernetes-helm
    kubectl # You'll likely want this too
    runc
  ];
  virtualisation.docker = {
    enable = true;
    # enableNvidia = true;
  };

  # Enable Docker service

  systemd.services.create-bash-symlink = {
    description = "Create /bin/bash symlink";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/ln -sf /run/current-system/sw/bin/bash /bin/bash";
      RemainAfterExit = true;
    };
  };

  # Auto login

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = user;

  # Disable auto sleep
  services.logind.settings.Login = {
    "HandleSuspendKey" = "ignore";
    "HandleLidSwitch" = "ignore";
    "HandleLidSwitchDocked" = "ignore";
    "IdleAction" = "ignore";
  };

  # Install firefox.
  programs.firefox.enable = true;

  system.stateVersion = "24.11";
}
