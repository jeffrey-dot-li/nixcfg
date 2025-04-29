{
  inputs,
  pkgs,
  lib,
  self',
  ...
}: {
  programs.zsh.enable = true;
  # Version of nix-darwin used. Don't change this.
  system.stateVersion = 4;
  ids.gids.nixbld = 350;

  environment.systemPackages =
    builtins.attrValues self'.packages;
  environment.variables = {
    SHELL_PATH = "${self'.packages.fish}/bin/fish";
    EDITOR = "nvim";
  };
  environment.shells = ["${self'.packages.fish}/bin/fish"];
  # environment.loginShell = "${shellWrapper}/bin/nucleus -l"; # This does nothing except for tmux (see https://github.com/LnL7/nix-darwin/issues/361)
  security.pam.services.sudo_local.touchIdAuth = true;
}
