{
  inputs,
  pkgs,
  lib,
  self',
  config,
  ...
}: {
  environment.systemPackages =
    # TODO: Add kitty configuration
    builtins.attrValues self'.packages ++ [pkgs.kitty pkgs.proton-pass];
  programs.ccache.enable = true;
  programs.fish.enable = true;
  nix.settings.extra-sandbox-paths = [config.programs.ccache.cacheDir];

  environment.variables = {
    # I'm not sure which one of these is the thing that actually makes it work (could also be `users.user.shell`).
    # Sometimes this require a reboot for it to take effect.

    # We need to keep the login shell as bash for some reason.
    # If we set it to fish then it does use fish as login
    # but it is broken and doesn't load config on login

    # These guys actually don't do anything. I think envrionment.shells does something,
    # and user.user.shell does something.
    SHELL_PATH = "${self'.packages.fish}/bin/fish";
    EDITOR = "nvim";
    SHELL = "fish";
  };
  programs.bash = {
    enable = true;
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${self'.packages.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };
  environment.shells = [pkgs.bash];
  services.vscode-server.enable = true;
}
