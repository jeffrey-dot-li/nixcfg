# Package configuration that configures itself is pkgs/
# Package configuration reliant on wrapper manager is in wrapper-manager/
# https://github.com/viperML/dotfiles/blob/master/packages/default.nix
{
  lib,
  config,
  inputs,
  pkgs,
  system,
  inputs',
}: let
  packages = lib.fix (
    self: let
      # packages in $FLAKE/packages, callPackage'd automatically
      stage1 = lib.fix (
        self': let
          callPackage = lib.callPackageWith (pkgs // self');
          auto = lib.pipe (builtins.readDir ./pkgs) [
            (lib.filterAttrs (name: value: value == "directory"))
            (builtins.mapAttrs (name: _: callPackage ./pkgs/${name} {}))
          ];
        in
          auto
          // {
            # nix = inputs'.in-nix.packages.default.patchNix pkgs.nixVersions.nix_2_24;
            # manual overrides to auto callPackage
            # nix-index = callPackage ./nix-index {
            #   database = inputs'.nix-index-database.packages.nix-index-database;
            #   databaseDate = config.flake.lib.mkDate inputs.nix-index-database.lastModifiedDate;
            # };
            # preventing infrec
            nvim = callPackage ./pkgs/nvim {inherit inputs pkgs lib;};
            # fish = callPackage ./pkgs/fish {inherit (pkgs) fish;};
            # guix = callPackage ./guix {
            #   inherit (pkgs) guix;
            # };
          }
      );
      stage2 =
        stage1
        // (inputs.wrapper-manager.lib {
          pkgs = pkgs // stage1;
          modules = lib.pipe (builtins.readDir ./wrapper-manager) [
            (lib.filterAttrs (name: value: value == "directory"))
            builtins.attrNames
            (map (n: ./wrapper-manager/${n}))
          ];
          specialArgs = {
            inherit inputs';
          };
        })
        .config
        .build
        .packages;
      stage3 = let
        callPackage = lib.callPackageWith (pkgs // self);
        callPackageScopedWith = autoArgs: f: args: let
          res = builtins.scopedImport (autoArgs // args) f;
          override = newArgs: callPackageScopedWith (autoArgs // newArgs) f;
        in
          res // {inherit override;};

        callPackageScoped = callPackageScopedWith (pkgs // self);
      in
        stage2 // {env = callPackage ./env {inherit inputs';};};
    in
      stage3
  );
in {
  _module.args.pkgs = import inputs.nixpkgs {
    inherit system;

    overlays = [
      (import inputs.rust-overlay)
    ];

    config = {
      allowInsecurePredicate = pkg: let
        pname = lib.getName pkg;
        byName = builtins.elem pname [
          "nix"
        ];
      in
        if byName
        then lib.warn "Allowing insecure package: ${pname}" true
        else false;

      allowUnfreePredicate = pkg: let
        pname = lib.getName pkg;
        byName = builtins.elem pname [
          "vscode"
          "slack"
          "steam"
        ];
        byLicense = builtins.elem pkg.meta.license.shortName [
          "CUDA EULA"
          "bsl11"
        ];
      in
        if byName || byLicense
        then lib.warn "Allowing unfree package: ${pname}" true
        else false;
    };
  };
  packages = packages;
}
