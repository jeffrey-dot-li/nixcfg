{
  inputs,
  pkgs,
  lib,
  self',
  ...
}: {
  programs.zsh.enable = true;
  services.nix-daemon.enable = true;
  # Version of nix-darwin used. Don't change this.
  system.stateVersion = 4;

  environment.systemPackages =
    builtins.attrValues self'.packages;
  environment.variables = {
    SHELL_PATH = "${self'.packages.fish}/bin/fish";
    EDITOR = "nvim";
  };
  environment.shells = ["${self'.packages.fish}/bin/fish"];
  # environment.loginShell = "${shellWrapper}/bin/nucleus -l"; # This does nothing except for tmux (see https://github.com/LnL7/nix-darwin/issues/361)
  security.pam.enableSudoTouchIdAuth = true;
}
