{pkgs, ...}: let
  ree = "";
in (with pkgs; [
  fish
  bat
  starship
  zoxide
  uv
  cargo
])
