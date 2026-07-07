{
  pkgs,
  inputs',
  lib,
  ...
}: let
  myGit = pkgs.gitFull;
  globalGitignore = pkgs.writeText ".gitignore_global" (lib.fileContents ./.gitignore_global);
  # macOS GUI apps often don't inherit $PATH, so ssh can't be found unless given
  # an absolute path there. NixOS has no /usr/bin/ssh, so leave it unset there
  # and let git resolve `ssh` from $PATH instead.
  sshCommandLine = lib.optionalString pkgs.stdenv.isDarwin "sshCommand = /usr/bin/ssh";
  gitConfigContent =
    lib.strings.replaceStrings ["$GLOBAL_GITIGNORE" "$SSH_COMMAND_LINE"] [(toString globalGitignore) sshCommandLine] (lib.fileContents ./gitconfig);
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
