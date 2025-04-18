{
  pkgs,
  inputs',
  lib,
  ...
}: let
  myGit = pkgs.gitFull;
  globalGitignore = pkgs.writeText ".gitignore_global" (lib.fileContents ./.gitignore_global);
  gitConfigContent =
    lib.strings.replaceStrings ["$GLOBAL_GITIGNORE"] [(toString globalGitignore)] (lib.fileContents ./gitconfig);
  gitConfig = pkgs.writeText "gitconfig" gitConfigContent;
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
    env.GIT_CONFIG_GLOBAL.value = toString gitConfig;
    env.GIT_CLONE_FLAGS.value = "--recursive --filter=blob:none";
    # postBuild = ''
    #   # export PATH=$out/bin/git:$PATH;
    #   # $out/bin/git-lfs install
    # '';
  };
}
