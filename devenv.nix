{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  cachix.push = "jeffrey-dot-li";

  packages = [
    pkgs.git
  ];

  git-hooks.hooks.nix-fmt = {
    enable = true;
    name = "nix fmt (treefmt + alejandra)";
    entry = "nix fmt --";
    files = "\\.nix$";
    language = "system";
  };
}
