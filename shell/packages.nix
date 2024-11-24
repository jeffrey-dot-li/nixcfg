{
  inputs,
  pkgs,
  lib,
  ...
}: let
  gdk = pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
    gke-gcloud-auth-plugin
  ]);
  nvim = import ./nvim {inherit inputs pkgs lib;};
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
  vscodium
  nvim
])
