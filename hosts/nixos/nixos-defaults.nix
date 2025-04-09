{
  inputs,
  pkgs,
  lib,
  self',
  ...
}: {
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
  services.vscode-server.enable = true;
}
