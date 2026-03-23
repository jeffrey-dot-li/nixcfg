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
          inputs.vscode-server.nixosModules.default
          (import ./nixos-defaults.nix)
          {nixpkgs.hostPlatform = system;}
          inputs.agenix.nixosModules.default
          module
          # https://git.lix.systems/lix-project/nixos-module/pulls/105
          inputs.lix-module.nixosModules.default
        ];
      specialArgs = mkSpecialArgs system;
    };
in {
  latte = makeNixosConfig "x86_64-linux" ./latte;
}
