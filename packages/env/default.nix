{
  inputs',
  #
  lib,
  symlinkJoin,
  #
  # TODO: Configure direnv
  direnv,
  nix-index,
  eza,
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
  git,
  difftastic,
  # elfutils-cli,
  # lurk,
  fq,
  alejandra,
  vscode,
  nixfmt-rfc-style,
  # psmisc,
} @ args:
symlinkJoin {
  name = "env";
  paths =
    (builtins.filter lib.isDerivation (builtins.attrValues args))
    ++ [
      inputs'.nil.packages.default
      # inputs'.nh.packages.default
      # inputs'.hover-rs.packages.default
      # inputs'.guix-search.packages.default
    ];
}
