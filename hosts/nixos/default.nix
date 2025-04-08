{
  nixpkgs,
  shared-modules,
  inputs,
  mkSpecialArgs,
}
: let
  # darwin-defaults = import ./darwin-defaults.nix;
  makeNixosConfig = system: module:
    nixpkgs.lib.nixosSystem {
      system = system;
      modules =
        shared-modules
        ++ [
          (import ./nixos-defaults.nix)
          {nixpkgs.hostPlatform = system;}
          module
        ];
      specialArgs = mkSpecialArgs system;
    };
in {
  latte = makeNixosConfig "x86_64-linux" ./latte;
}
