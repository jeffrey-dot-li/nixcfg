{
  # This is the everything package. This is the shell env that I am shipping basically.
  inputs',
  pkgs,
  #
  lib,
  symlinkJoin,
  #
  nix-index,
  fish,
  elf-info,
  gh,
  unar,
  hexyl,
  du-dust,
  magic-wormhole-rs,
  fd,
  libarchive,
  dogdns,
  # Use custom git
  # git
  difftastic,
  devenv,
  # elfutils-cli,
  # lurk,
  fq,
  nixfmt-rfc-style,
  # psmisc,
  starship,
  # cd with memory
  zoxide,
  # better cat
  bat,
  tmux,
  nvim,
  # TODO: Customize: https://github.com/NotAShelf/microfetch
  fastfetch,
  htop,
  fzf,
  # Search
  ripgrep,
  less,
  # Better ls
  eza,
  # I'll keep alejandra here just because I assume that whereever you are working you will need to edit nix files.
  # I.E. to use this shell, you need a flake.nix, so you need to format that nix anyways.
  alejandra,
  direnv,
  nix-direnv,
  xdg-utils,
  nil,
  jq,
  # go
  go,
  pre-commit,
  # On gpu, need to use system c++ otherwise transformer-engine[jax] won't build
  # gcc,
  # pipx,
  kubectl,
} @ args:
symlinkJoin {
  name = "env";
  paths =
    (builtins.filter lib.isDerivation (builtins.attrValues args))
    ++ [
      (
        pkgs.google-cloud-sdk.withExtraComponents [
          pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
        ]
      )
      # inputs'.nil.packages.default
      # inputs'.nh.packages.default
      # inputs'.hover-rs.packages.default
      # inputs'.guix-search.packages.default
    ];
}
