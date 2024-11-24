{
  inputs,
  pkgs,
  lib,
  ...
}: let
  user = "jeffrey";
  shellWrapper = pkgs.callPackage ../../shell {inherit pkgs inputs lib;};
in {
  programs.zsh.enable = true;
  services.nix-daemon.enable = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  users.knownUsers = [user];

  networking.hostName = "applin";
  nix.settings.experimental-features = "nix-command flakes";
  system.stateVersion = 4;
  users.users."${user}" = {
    home = "/Users/${user}";
    shell = pkgs.zsh;
    # HACK.
    # If we set to bin/nucleus by default, it can't read system environment variables properly (So `nix` will not be defined)
    # We set it to zsh, and then load the shellWrapper in the ~/.profile from the $SHELL_PATH environment variable
    uid = 501;
  };

  environment.variables = {
    SHELL_PATH = "${shellWrapper}/bin/nucleus";
    EDITOR = "nvim";
  };
  environment.shells = ["${shellWrapper}/bin/nucleus"];
  # environment.loginShell = "${shellWrapper}/bin/nucleus -l"; # This does nothing except for tmux (see https://github.com/LnL7/nix-darwin/issues/361)
  security.pam.enableSudoTouchIdAuth = true;
}
