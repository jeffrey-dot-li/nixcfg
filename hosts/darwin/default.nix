{
  nix-darwin,
  shared-modules,
  inputs,
  mkSpecialArgs,
}
: let
  # darwin-defaults = import ./darwin-defaults.nix;
  makeDarwinConfig = system: module:
    nix-darwin.lib.darwinSystem {
      system = system;
      modules =
        shared-modules
        ++ [
          (import ./darwin-defaults.nix)
          {nixpkgs.hostPlatform = system;}
          module
        ];
      specialArgs = mkSpecialArgs system;
    };
in {
  applin = makeDarwinConfig "aarch64-darwin" ./applin;
  co-applin = makeDarwinConfig "aarch64-darwin" ./co-applin;
}
