{
  pkgs,
  inputs,
  lib,
  ...
}: let
  toml = pkgs.formats.toml {};
  starship-settings = import ./starship.nix;
  aliases = import ./aliases.nix {inherit pkgs;};
  fishconfig = import ./fish {inherit pkgs aliasesStr;};
  packages = import ./packages.nix {inherit inputs pkgs lib;};
  aliasesStr =
    pkgs.lib.concatStringsSep "\n"
    (pkgs.lib.mapAttrsToList (k: v: "alias ${k}=\"${v}\"") aliases);
in (inputs.wrapper-manager.lib {
  # A convenience shorthand for (wrapper-manager.lib {...}).config.build.toplevel is available through:
  # wrapper-manager.lib.build {}, which is probably what you want in 99% of the cases.
  inherit pkgs;
  modules = [
    {
      wrappers = {
        nucleus = {
          basePackage = pkgs.fish;
          pathAdd = packages;
          env = {
            STARSHIP_CONFIG.value = toml.generate "starship.toml" starship-settings;
            FISH_CONFIG.value = "${fishconfig}";
          };
          extraPackages = [
            pkgs.vscode
          ];
          # This adds the
          # extraWrapperFlags = "--prefix PATH : $out/bin";
          flags = [
            "-C"
            "source ${fishconfig}"
          ];
          renames = {
            "fish" = "nucleus";
          };
        };
      };
      # Equivalent to adding { nvim = configs.nvim; } inside wrappers.
    }
  ];
})
# .overrideAttrs (old: {
#   passthru = {
#     shellPath = "/bin/nucleus";
#   };
# })

