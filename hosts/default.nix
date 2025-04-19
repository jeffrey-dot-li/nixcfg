{
  inputs,
  config,
  withSystem,
  lib,
  ...
}: let
  core = ../system/core;
  nix-darwin = inputs.nix-darwin;
  nixpkgs = inputs.nixpkgs;
  nixpkgsConfig = import ../nixpkgsConfig.nix {
    inherit inputs lib;
  };
  shared = [
    core
    {nixpkgs = nixpkgsConfig;}
    # {system.configurationRevision = self.rev or self.dirtyRev or null;}
  ];

  # This allows passing through the system-specific `self'` and `inputs'` to each system configuration.
  mkSpecialArgs = system: (withSystem system ({
    inputs',
    self',
    ...
  }: {inherit self' inputs' inputs;}));

  darwinConfigurations = import ./darwin {
    mkSpecialArgs = mkSpecialArgs;
    nix-darwin = nix-darwin;
    shared-modules = shared;
    inputs = inputs;
  };
  nixosConfigurations = import ./nixos {
    mkSpecialArgs = mkSpecialArgs;
    nixpkgs = nixpkgs;
    shared-modules = shared;
    inputs = inputs;
  };
in {
  # nixosConfigurations = {
  #   # Raspberry Pi
  #   appletun = nixpkgs.lib.nixosSystem {
  #     # TODO: Put nixos stuff in its own file.
  #     system = "aarch64-linux";
  #     specialArgs = mkSpecialArgs "aarch64-linux";
  #     modules =
  #       [
  #         {networking.hostName = "appletun";}
  #         ./appletun
  #         inputs.agenix.nixosModules.default
  #         inputs.homix.nixosModules.default
  #         # TODO: Integrate wayland
  #       ]
  #       ++ shared;
  #   };
  # };

  nixosConfigurations = nixosConfigurations;
  darwinConfigurations = darwinConfigurations;
}
