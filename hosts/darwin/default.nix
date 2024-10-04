{
  nixpkgs,
  nix-darwin,
  self,
  ...
}: let
  inherit (self) inputs;
  core = ../system/core;
  # bootloader = ../system/core/bootloader.nix;
  # impermanence = ../system/core/impermanence.nix;
  # wayland = ../system/wayland;
  shared = [core];
in {
  # all my hosts are named after saturn moons btw

  applin = nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules =
      [
        {
          services.nix-daemon.enable = true;
          nixpkgs.hostPlatform = "aarch64-darwin";
          networking.hostName = "applin";
          nix.settings.experimental-features = "nix-command flakes";
          system.stateVersion = 4;
        }
      ]
      ++ [core];
    specialArgs = {inherit inputs;};
  };
}
