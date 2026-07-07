{
  pkgs,
  inputs',
  lib,
  ...
}: let
  myGit = pkgs.gitFull;
  globalGitignore = pkgs.writeText ".gitignore_global" (lib.fileContents ./.gitignore_global);
  # We want our own (wrapped) git binary, but git should still shell out to
  # the *system* ssh (/usr/bin/ssh) rather than whatever `ssh` resolves to on
  # $PATH: GUI apps and other tools often don't inherit a full $PATH, and the
  # system ssh already has the right integration (ssh-agent socket, Kerberos,
  # host-specific config, etc.) for that machine. This one static config is
  # shared across nix-darwin, NixOS, and plain `nix profile install`
  # (flake-based) deployments on foreign Linux distros, so it can't just
  # branch on `pkgs.stdenv.isDarwin` at build time - true NixOS systems have
  # no /usr/bin/ssh at all, while Darwin and foreign-distro (e.g. Debian VM)
  # installs do. Check for it at runtime instead, falling back to $PATH's
  # `ssh` when it's absent (NixOS).
  sshWrapper = pkgs.writeShellScript "git-ssh-wrapper" ''
    if [ -x /usr/bin/ssh ]; then
      exec /usr/bin/ssh "$@"
    else
      exec ssh "$@"
    fi
  '';
  sshCommandLine = "sshCommand = ${sshWrapper}";
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
