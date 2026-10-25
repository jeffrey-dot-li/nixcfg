{
  description = "My NixOS configuration";

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
        inputs.treefmt-nix.flakeModule
      ];

      perSystem = {
        config,
        # pkgs,
        lib,
        system,
        inputs',
        ...
      }: let
        nixpkgsConfig = import ./nixpkgsConfig.nix {
          inherit lib inputs;
        };
        pkgs = import inputs.nixpkgs ({
            inherit system;
          }
          // nixpkgsConfig);

        packages = import ./packages {
          inherit config pkgs lib system inputs inputs';
        };
      in {
        _module.args.pkgs = pkgs;

        treefmt = {
          programs.alejandra.enable = true;
          # Don't touch encrypted secrets.
          settings.excludes = [
            "secrets/*.age"
          ];
        };
        formatter = config.treefmt.build.wrapper;

        packages =
          packages
          // {
            # Export shell as default package.
            default = packages.profile;
          };
        devShells.default = pkgs.mkShell {
          # This is for this project development. Don't depend on this devShell in another devShell,
          # Just install the package yourself.
          packages = [
            # lua-language-server
            # config.packages.stylua
            # taplo
          ];
          # This is what actually calls nucleus in the shell. Without this, even if shell is in buildInputs, it will run bash.
          # Don't call this here, because with direnv this will recursive build a ton of direnvs.
          # shellHook = ''
          #   fish
          # '';
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

    agenix.url = "github:ryantm/agenix";

    wrapper-manager = {
      url = "git+https://codeberg.org/viperML/wrapper-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # a tree-wide formatter
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };
}
# see also:
# - https://github.com/notashelf/nyx
# - https://github.com/fufexan/dotfiles/
# - https://github.com/n3oney/nixus
# (I love you guys)

