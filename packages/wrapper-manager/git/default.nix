{
  pkgs,
  inputs',
  lib,
  ...
}: let
  myGit = pkgs.gitFull;
in {
  wrappers.git = {
    # basePackage = inputs'.git-args.packages.default.override {
    #   git = myGit;
    # };
    basePackage = myGit;
    extraPackages = [
      pkgs.git-extras
      pkgs.git-lfs
      myGit
    ];
    env.GIT_CONFIG_GLOBAL.value = ./gitconfig;
    env.GIT_CLONE_FLAGS.value = "--recursive --filter=blob:none";
    # postBuild = ''
    #   # export PATH=$out/bin/git:$PATH;
    #   $out/bin/git-lfs install
    # '';
  };
}
