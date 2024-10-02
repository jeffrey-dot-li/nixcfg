{
  description = ''
    For questions just DM me on X: https://twitter.com/@m3tam3re
    There is also some NIXOS content on my YT channel: https://www.youtube.com/@m3tam3re

    One of the best ways to learn NIXOS is to read other peoples configurations. I have personally learned a lot from Gabriel Fontes configs:
    https://github.com/Misterio77/nix-starter-configs
    https://github.com/Misterio77/nix-config

    Please also check out the starter configs mentioned above.
  '';

  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.11";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = {
    self,
    agenix,
    home-manager,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages =
      forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    overlays = import ./overlays {inherit inputs;};
    nixosConfigurations = {
      appletun = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/appletun
          agenix.nixosModules.default
        ];
      };
    };
    homeConfigurations = {
      "jeffrey@appletun" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."aarch64-linux";
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [./home/jeffrey/appletun.nix];
      };
    };
  };
}
