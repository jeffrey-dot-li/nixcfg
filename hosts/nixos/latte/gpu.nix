{
  config,
  lib,
  pkgs,
  ...
}: let
  cuda-symlink = pkgs.symlinkJoin {
    name = "cudatoolkit";
    paths = with pkgs.cudaPackages; [
      cudatoolkit
      cuda_nvcc
      (lib.getLib cuda_nvrtc)
      (lib.getDev cuda_nvrtc)
      (lib.getLib cuda_cudart)
      (lib.getDev cuda_cudart)
      (lib.getStatic cuda_cudart)
      # This package contains libcuda.so.1
      (lib.getLib config.boot.kernelPackages.nvidiaPackages.beta)
    ];
    postBuild = ''
      ln -s $out/lib $out/lib64
    '';
  };
in {
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
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    cmake
    cuda-symlink
    # Add any missing dynamic libraries for unpackaged programs
    # here, NOT in environment.systemPackages
    # This updates $NIX_LD_LIBRARY_PATH.
    # We then add a script in fish init to update $LIBRARY_PATH and $LD_LIBRARY_PATH
  ];
  environment.variables = {
    CUDA_HOME = "${cuda-symlink}";
    CUDA_PATH = "${cuda-symlink}";
    CUDA_INCLUDE_DIRS = "${cuda-symlink}/include";
    CPATH = "${cuda-symlink}/include";
  };

  environment.systemPackages = with pkgs; [
    cuda-symlink
    nvtopPackages.nvidia
  ];
}
