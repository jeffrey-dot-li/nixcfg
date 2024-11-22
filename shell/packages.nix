{pkgs, ...}: let
  gdk = pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
    gke-gcloud-auth-plugin
  ]);
in (with pkgs; [
  fish
  bat
  starship
  zoxide
  uv
  cargo
  gdk
  tmux
  rustup
  vscode
  # (
  #   rWrapper.overridcode () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $argv ;}e {
  #     packages = with rPackages; [ggplot2 dplyr xts devtools];
  #   }
  # )
])
