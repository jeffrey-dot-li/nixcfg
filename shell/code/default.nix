{
  inputs,
  pkgs,
  lib,
  ...
}: (
  pkgs.vscode
  # pkgs.vscode-with-extensions.override {
  # TODO:
  # - Make extensions declarative.
  # - Switch to vscodium maybe?
  # Although vscodium doesn't support LaTex, Liveshare, Copilot, and Remote SSH out of the box so that is a problem
  # - Make settings / hotkeys declarative, put full VSCode settings in this file.
  # (I.E. Have this build copy the settings.json file to the right place)
  # vscode = pkgs.vscodium;
  # vscodeExtensions = with pkgs.vscode-extensions;
  #   [
  #     bbenoist.nix
  #     ms-python.python
  #     ms-azuretools.vscode-docker
  #     ms-vscode-remote.remote-ssh
  #   ]
  #   ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
  #     {
  #       name = "remote-ssh-edit";
  #       publisher = "ms-vscode-remote";
  #       version = "0.47.2";
  #       sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
  #     }
  #   ];
  #}
)
