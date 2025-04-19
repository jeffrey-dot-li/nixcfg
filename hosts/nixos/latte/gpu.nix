{
  config,
  lib,
  pkgs,
  ...
}: {
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    # This needs to be true for 5070Ti for some reason. Not 100% sure why and what impacts it has.
    open = true;
    nvidiaSettings = true;
    # Look at latest nixpkgs (nixos-unstable version). Then look at
    # https://github.com/NixOS/nixpkgs/blob/18dd725c29603f582cf1900e0d25f9f1063dbf11/pkgs/os-specific/linux/nvidia-x11/default.nix#L66
    # If need to update, run `nix flake update` to update flake parts.
    # Nvidia requirements are https://www.nvidia.com/en-us/drivers/results/
    # Currently version 570.133.07, CUDA Version 12.8
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };
}
