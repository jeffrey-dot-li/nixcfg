{
  config,
  lib,
  pkgs,
  ...
}: let
  # Pinned so `nix flake update` never changes the driver behind our back.
  # 595.45.04 (the old `beta` alias) hung games in vkWaitForPresent2KHR.
  # To bump: copy version + hashes from nvidiaPackages in
  # pkgs/os-specific/linux/nvidia-x11/default.nix, and check it builds
  # against the kernel pinned below. Needs a reboot (`nixos-rebuild boot`).
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "595.104.02";
    sha256_64bit = "sha256-5CHCAuTHn1jDx/MWG75xRU67PYiTb4ggWg4yfNBMWco=";
    sha256_aarch64 = "sha256-PafStmwNMufeDp3VtpTGGCoW+53Gor/mieO1m1pI7gI=";
    openSha256 = "sha256-FWk5ra2yjz8VAxAA8GXrSoeBj/XC1BKvsKsBKR09joE=";
    settingsSha256 = "sha256-4Kxro6tvI5aX4nu2RspgyBsW+Jq3/VYjSAS5UGdzTCU=";
    persistencedSha256 = "sha256-JsMLPqJuZwAtHngsQODMsmgO7F2tVkQ2arc7fYa2bwo=";
  };
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
      (lib.getLib nvidiaPackage)
    ];
    postBuild = ''
      ln -s $out/lib $out/lib64
      sed -i "1i\_HERE_ = $out/bin" $out/bin/nvcc.profile
    '';
  };
in {
  # Pinned to the 6.18 LTS line: the NVIDIA module is built per kernel, and
  # 595.45.04 failed to build on 7.3. Change together with nvidiaPackage.
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    # This needs to be true for 5070Ti for some reason. Not 100% sure why and what impacts it has.
    open = true;
    nvidiaSettings = true;
    # Nvidia requirements are https://www.nvidia.com/en-us/drivers/results/
    package = nvidiaPackage;
  };
  hardware.nvidia-container-toolkit.enable = true;
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
