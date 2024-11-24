{
  description = "My NixOS configuration";
  # https://dotfiles.sioodmy.dev

  outputs = {flake-parts, ...} @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} ({...}: {
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
        ...
      }: {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            config.treefmt.build.wrapper
            (pkgs.callPackage ./shell {inherit pkgs inputs lib;})
          ];
          shellHook = ''
            nucleus
          '';
        };

        # configure treefmt
        treefmt = {
          projectRootFile = "flake.nix";
          programs = {
            alejandra.enable = true;
            black.enable = true;
            deadnix.enable = false;
            shellcheck.enable = true;
            shfmt = {
              enable = true;
              indent_size = 4;
            };
          };
        };
      };

      flake =
        (import ./hosts inputs)
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

    agenix.url = "github:ryantm/agenix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";
    nix-colors.url = "github:Misterio77/nix-colors";

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
  };
}
# see also:
# - https://github.com/notashelf/nyx
# - https://github.com/fufexan/dotfiles/
# - https://github.com/n3oney/nixus
# (I love you guys)

