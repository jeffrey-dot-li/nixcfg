{
  nix-darwin,
  shared-modules,
  inputs,
}
: let
  darwin-defaults = ./darwin-defaults.nix;
  makeDarwinConfig = system: module:
    nix-darwin.lib.darwinSystem {
      system = system;
      modules = [module darwin-defaults] ++ shared-modules;
      specialArgs = {inherit inputs;};
    };
in {
  applin = makeDarwinConfig "aarch64-darwin" ./applin;
  co-applin = makeDarwinConfig "aarch64-darwin" ./co-applin;
}
