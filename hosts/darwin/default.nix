{
  nix-darwin,
  shared-modules,
  inputs,
}
: let
  darwin-defaults = import ./darwin-defaults.nix;
  makeDarwinConfig = system: module:
    nix-darwin.lib.darwinSystem {
      system = system;
      modules =
        shared-modules
        ++ [
          darwin-defaults
          {nixpkgs.hostPlatform = system;}
          module
        ];
      specialArgs = {inherit inputs;};
    };
in {
  applin = makeDarwinConfig "aarch64-darwin" ./applin;
  co-applin = makeDarwinConfig "aarch64-darwin" ./co-applin;
}
