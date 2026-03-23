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
  # https://wiki.lix.systems/books/lix-contributors/page/running-lix-main
  shared = [
    core
    {nixpkgs = nixpkgsConfig;}
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
  nixosConfigurations = nixosConfigurations;
  darwinConfigurations = darwinConfigurations;
}
