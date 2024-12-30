{
  description = "My NixOS configuration";
  # https://dotfiles.sioodmy.dev

  outputs = {flake-parts, ...} @ inputs:
  # For some reason, if you don't take `withSystem` here as an explicit argument,
  # then the `withSystem` field is not filled in the `inputs'` object.
    flake-parts.lib.mkFlake {inherit inputs;} ({withSystem, ...} @ inputs': {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.treefmt-nix.flakeModule
      ];

      perSystem = {
        config,
        pkgs,
        lib,
        system,
        inputs',
        ...
      }: let
        packageConfiguration = import ./packages {
          inherit config pkgs lib system inputs inputs';
        };
      in {
        _module.args.pkgs = packageConfiguration._module.args.pkgs;
        packages = packageConfiguration.packages;
        devShells.default = pkgs.mkShell {
          packages = [
            packageConfiguration.packages.fish
          ];
          # This is what actually calls nucleus in the shell. Without this, even if shell is in buildInputs, it will run bash.
          shellHook = ''
            fish
          '';
        };
      };

      flake =
        (import ./hosts inputs')
        // {
        };
    });

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
    };
    in-nix = {
      url = "github:viperML/in-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";
    nix-colors.url = "github:Misterio77/nix-colors";
    rust-overlay.url = "github:oxalica/rust-overlay";

    wrapper-manager = {
      url = "github:viperML/wrapper-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # a tree-wide formatter
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homix = {
      url = "github:sioodmy/homix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    mkalias = {
      url = "github:reckenrode/mkalias";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    nil = {
      url = "github:oxalica/nil?ref=main";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };
}
# see also:
# - https://github.com/notashelf/nyx
# - https://github.com/fufexan/dotfiles/
# - https://github.com/n3oney/nixus
# (I love you guys)

