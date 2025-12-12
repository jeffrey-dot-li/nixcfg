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
      sed -i "1i\_HERE_ = $out/bin" $out/bin/nvcc.profile
    '';
  };
in {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };
}
