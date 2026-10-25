{
  nixpkgs,
  shared-modules,
  inputs,
  mkSpecialArgs,
}
: let
  makeNixosConfig = system: module:
    nixpkgs.lib.nixosSystem {
      system = system;
      modules =
        shared-modules
        ++ [
          (import ./nixos-defaults.nix)
          {nixpkgs.hostPlatform = system;}
          inputs.agenix.nixosModules.default
          module
        ];
      specialArgs = mkSpecialArgs system;
    };
in {
  latte = makeNixosConfig "x86_64-linux" ./latte;
}
