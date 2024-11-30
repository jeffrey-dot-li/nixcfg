{
  nixpkgs,
  nix-darwin,
  self,
  ...
}: let
  inputs = self.inputs;
  core = ../system/core;
  # bootloader = ../system/core/bootloader.nix;
  # impermanence = ../system/core/impermanence.nix;
  # wayland = ../system/wayland;
  agenix = inputs.agenix.nixosModules.default;
  hw = inputs.nixos-hardware.nixosModules;
  homix = inputs.homix.nixosModules.default;
  shared = [
    core
    {nixpkgs.overlays = [inputs.rust-overlay.overlays.default];}
    {system.configurationRevision = self.rev or self.dirtyRev or null;}
  ];
  darwinConfigurations = import ./darwin {
    nix-darwin = nix-darwin;
    shared-modules = shared;
    inputs = inputs;
  };
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
  darwinConfigurations = darwinConfigurations;
  # I'm pretty sure this is not used?
  # darwinPackages = self.darwinConfigurations."applin".pkgs;
}
