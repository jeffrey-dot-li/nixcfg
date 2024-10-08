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
  agenix = inputs.agenix.nixosModules.default;
  hw = inputs.nixos-hardware.nixosModules;
  homix = inputs.homix.nixosModules.default;
  shared = [core];
in {
  nixosConfigurations = {
    # Raspberry Pi
    appletun = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules =
        [
          {networking.hostName = "appletun";}
          ./appletun
          agenix
          homix
          #wayland
          #bootloader
          #impermanence
          # hw.lenovo-thinkpad-x1-7th-gen
        ]
        ++ shared;
      specialArgs = {inherit inputs;};
    };
  };
  darwinConfigurations = {
    # Macbook
    applin = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules =
        [
          ./applin
          {system.configurationRevision = self.rev or self.dirtyRev or null;}
        ]
        ++ shared;
      specialArgs = {inherit inputs;};
    };
  };
  darwinPackages = self.darwinConfigurations."applin".pkgs;
}
