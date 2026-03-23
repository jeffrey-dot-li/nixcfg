{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
  };
  programs.gamemode.enable = true;
  hardware.opengl = {
    extraPackages = with pkgs; [mangohud];
    extraPackages32 = with pkgs; [mangohud];
  };
  environment.systemPackages = with pkgs; [mangohud protonup-qt lutris bottles heroic];
}
