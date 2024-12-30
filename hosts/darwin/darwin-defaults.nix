{
  inputs,
  pkgs,
  lib,
  self',
  ...
}: {
  programs.zsh.enable = true;
  services.nix-daemon.enable = true;
  system.stateVersion = 4;
  nix.settings = {
    experimental-features = "nix-command flakes";
  };
  environment.systemPackages = builtins.attrValues self'.packages;
  environment.variables = {
    SHELL_PATH = "${self'.packages.fish}/bin/fish";
    EDITOR = "nvim";
  };
  environment.shells = ["${self'.packages.fish}/bin/fish"];
  # environment.loginShell = "${shellWrapper}/bin/nucleus -l"; # This does nothing except for tmux (see https://github.com/LnL7/nix-darwin/issues/361)
  security.pam.enableSudoTouchIdAuth = true;
}
