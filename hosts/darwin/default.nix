{
  nix-darwin,
  shared-modules,
  inputs,
  mkSpecialArgs,
}
: let
  makeDarwinConfig = system: module:
    nix-darwin.lib.darwinSystem {
      system = system;
      modules =
        shared-modules
        ++ [
          (import ./darwin-defaults.nix)
          {nixpkgs.hostPlatform = system;}
          inputs.lix-module.darwinModules.default
          ({lib, ...}: {
            # Lix's daemon-backed install checks are unreliable in Darwin sandboxes.
            # Keep its normal checks enabled while allowing system rebuilds to finish.
            nixpkgs.overlays = lib.mkAfter [
              (_final: prev: {
                lix = prev.lix.overrideAttrs (_old: {
                  doInstallCheck = false;
                });
              })
            ];
          })
          module
        ];
      specialArgs = mkSpecialArgs system;
    };
in {
  applin = makeDarwinConfig "aarch64-darwin" ./applin;
  co-applin = makeDarwinConfig "aarch64-darwin" ./co-applin;
}
