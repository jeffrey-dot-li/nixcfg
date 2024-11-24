{
  inputs,
  pkgs,
  lib,
  ...
}: let
  shellWrapper = pkgs.callPackage ../../shell {inherit pkgs inputs lib;};
in {
  programs.zsh.enable = true;
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
  system.stateVersion = 4;

  environment.variables = {
    SHELL_PATH = "${shellWrapper}/bin/nucleus";
    EDITOR = "nvim";
  };
  environment.shells = ["${shellWrapper}/bin/nucleus"];
  # environment.loginShell = "${shellWrapper}/bin/nucleus -l"; # This does nothing except for tmux (see https://github.com/LnL7/nix-darwin/issues/361)
  security.pam.enableSudoTouchIdAuth = true;
}
