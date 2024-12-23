{
  inputs,
  pkgs,
  lib,
  ...
}: let
  # Gcloud should not be in dev-shell packages. Dev-Shell packages should be dev-only related
  # (I.E. stuff that is does not need to be persistent in the system, that you only need to use in the shell)
  # When we have gcloud in shell packages, then it will not be included in $PATH of system, alot of programs
  # look for gcloud in $PATH.
  # Also, project specific packages (node, etc) should not be in dev-shell packages.
  # They should be in the project's flake.nix file, and pull this shell as a flake dependency.
  nvim = import ./nvim {inherit inputs pkgs lib;};
  code = import ./code {inherit inputs pkgs lib;};
in (with pkgs; [
  fish
  bat
  starship
  zoxide
  uv
  # Always use latest version of rust
  # https://github.com/oxalica/rust-overlay
  # rust-bin.selectLatestNightlyWith (toolchain: toolchain.default) # or `toolchain.minimal`
  # rust-bin.stable."1.48.0".default
  # TODO: Probably use https://github.com/cargo2nix/cargo2nix for my rust repos
  (rust-bin.beta.latest.default.override {
    extensions = ["rust-src"];
  })
  # (rust-bin.selectLatestNightlyWith (toolchain: toolchain.default)) # or `toolchain.minimal`
  tmux
  # rustup
  code
  nvim
  alejandra
  neofetch
  lazygit
  htop
  # Probably put lean in a project flake.nix file instead.
  elan
])
