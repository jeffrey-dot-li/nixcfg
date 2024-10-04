{...}: {
  services.nix-daemon.enable = true;
  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = "applin";
  nix.settings.experimental-features = "nix-command flakes";
  system.stateVersion = 4;
}
