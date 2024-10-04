{
  nixpkgs,
  self,
  ...
}: let
  inherit (self) inputs;
  core = ../system/core;
  # bootloader = ../system/core/bootloader.nix;
  # impermanence = ../system/core/impermanence.nix;
  # wayland = ../system/wayland;
  agenix = inputs.agenix.nixosModules.default;
  hw = inputs.nixos-hardware.nixosModules;
  homix = inputs.homix.nixosModules.default;
  shared = [core agenix homix];
in {
  # all my hosts are named after saturn moons btw

  # Raspberry Pi
  appletun = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules =
      [
        {networking.hostName = "appletun";}
        ./appletun
        #wayland
        #bootloader
        #impermanence
        # hw.lenovo-thinkpad-x1-7th-gen
      ]
      ++ shared;
    specialArgs = {inherit inputs agenix;};
  };
}
