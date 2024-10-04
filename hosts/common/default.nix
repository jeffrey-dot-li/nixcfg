# Common configuration for all hosts
{
  lib,
  inputs,
  pkgs,
  config,
  ...
}: {
  nixpkgs = {
    # You can add overlays here
    #overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
     # outputs.overlays.additions
     # outputs.overlays.modifications
    #  outputs.overlays.stable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
   # ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {

      # nix but cooler
      # package = pkgs.lix;
    settings = {
      experimental-features = "nix-command flakes recursive-nix ca-derivations";
      trusted-users = [
        "root"
        "jeffrey"
      ]; # Set users that are allowed to use the flake command
          # use binary cache, its not gentoo
      builders-use-substitutes = true;
            # allow sudo users to mark the following values as trusted
      #allowed-users = ["@wheel"];
      #trusted-users = ["@wheel"];

            warn-dirty = false;

	          # continue building derivations if one fails
      keep-going = true;
      log-lines = 20;
	      # use binary cache, its not gentoo
    substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
        "https://nyx.chaotic.cx"
      ];

            trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      ];
      };

    gc = {
      # gc kills ssds
      automatic = false;
      options = "--delete-older-than 30d";
    };
    optimise.automatic = true;
    registry =
      (lib.mapAttrs (_: flake: {inherit flake;}))
      ((lib.filterAttrs (_: lib.isType "flake")) inputs);
    nixPath = ["/etc/nix/path"];
  };
}
