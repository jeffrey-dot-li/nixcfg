{
  inputs,
  pkgs,
  lib,
  self',
  ...
}: {
  programs.zsh.enable = true;
  # services.nix-daemon.enable = true;
  # system.stateVersion = 4;

  environment.systemPackages =
    builtins.attrValues self'.packages;
  environment.variables = {
    SHELL_PATH = "${self'.packages.fish}/bin/fish";
    EDITOR = "nvim";
  };
  environment.shells = ["${self'.packages.fish}/bin/fish"];
  # security.pam.enableSudoTouchIdAuth = true;
}
