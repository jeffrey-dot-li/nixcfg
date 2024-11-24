{
  inputs,
  pkgs,
  lib,
  ...
}: let
  user = "jeffrey";
in {
  users.knownUsers = [user];
  nix.settings = {
    allowed-users = ["@wheel" user];
    trusted-users = ["@wheel" user];
  };
  networking.hostName = "applin";
  users.users."${user}" = {
    home = "/Users/${user}";
    shell = pkgs.zsh;
    # HACK.
    # If we set to bin/nucleus by default, it can't read system environment variables properly (So `nix` will not be defined)
    # We set it to zsh, and then load the shellWrapper in the ~/.profile from the $SHELL_PATH environment variable
    uid = 501;
  };
}
