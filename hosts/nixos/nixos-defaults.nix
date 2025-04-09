{
  inputs,
  pkgs,
  lib,
  self',
  ...
}: {
  # programs.zsh.enable = true;
  # services.nix-daemon.enable = true;
  # system.stateVersion = 4;

  environment.systemPackages =
    builtins.attrValues self'.packages;

  environment.variables = {
    # I'm not sure which one of these is the thing that actually makes it work (could also be `users.user.shell`).
    # Sometimes this require a reboot for it to take effect.
    SHELL_PATH = "${self'.packages.fish}/bin/fish";
    EDITOR = "nvim";
    SHELL = "fish";
  };
  environment.shells = [self'.packages.fish];
  # security.pam.enableSudoTouchIdAuth = true;
}
