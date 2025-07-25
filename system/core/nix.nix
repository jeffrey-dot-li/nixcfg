{
  pkgs,
  lib,
  config,
  ...
}: {
  nix = {
    # gc kills ssds
    gc.automatic = false;

    # nix but cooler
    # package = pkgs.lix;

    # Make builds run with low priority so my system stays responsive
    # daemonCPUSchedPolicy = "idle";
    # daemonIOSchedClass = "idle";
    optimise.automatic = true;
    settings = {
      # flake-registry = "/etc/nix/registry.json";
      # use binary cache, its not gentoo

      builders-use-substitutes = true;
      # allow sudo users to mark the following values as trusted
      allowed-users = ["@wheel" "jeffrey" "jeffreyli"];
      trusted-users = ["@wheel" "jeffrey" "jeffreyli"];
      commit-lockfile-summary = "chore: Update flake.lock";
      accept-flake-config = true;
      keep-derivations = true;
      keep-outputs = true;
      warn-dirty = false;

      sandbox = "relaxed";
      max-jobs = "auto";
      # continue building derivations if one fails
      keep-going = true;
      log-lines = 20;
      extra-experimental-features = ["flakes" "nix-command" "recursive-nix" "ca-derivations"];
      # extra-sandbox-paths = [config.programs.ccache.cacheDir];

      experimental-features = "nix-command flakes";

      # use binary cache, its not gentoo
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  # WE DONT WANT TO BUILD STUFF ON TMPFS
  # ITS NOT A GOOD IDEA
  # systemd.services.nix-daemon = {
  #   environment.TMPDIR = "/var/tmp";
  # };

  # # this makes rebuilds little faster
  # system.switch = {
  #   enable = false;
  #   enableNg = true;
  # };
}
