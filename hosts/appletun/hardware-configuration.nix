{
  config,
  lib,
  pkgs,
  ...
}: {
  # Import your hardware configuration
  imports = [
    "${fetchTarball {
      url = "https://github.com/NixOS/nixos-hardware/tarball/master";
      sha256 = "12np46508738d2bqdcmmwqc1a1q920pr1cwcm2liqc3m01nmzax0";
    }}/raspberry-pi/4"
  ];

  # Set the host platform
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  # If you're on a different architecture (e.g., aarch64 for Raspberry Pi 4),
  # use the appropriate string, like "aarch64-linux"

  # Rest of your NixOS configuration...
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # ...
}
