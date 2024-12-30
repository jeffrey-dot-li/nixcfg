{
  inputs',
  #
  lib,
  symlinkJoin,
  #
  # TODO: Configure direnv
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
  git,
  difftastic,
  # elfutils-cli,
  # lurk,
  fq,
  vscode,
  nixfmt-rfc-style,
  # direnv,
  nix-direnv,
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
