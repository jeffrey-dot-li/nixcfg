{
  #
  inputs',
  lib,
  # symlinkJoin,
  pkgs,
  ...
}: let
  fish = lib.callPackageWith pkgs ./fish.nix {inherit (pkgs) fish;};
  shellPackages =
    pkgs.symlinkJoin
    {
      name = "shell-tools";
      # These tools are shell specific, come out of the box and configure devShell.
      # Other tools are system specific: I.E. git, you only need one install and it should be installed at the system level.
      # Other tools are project specific: I.E. uv / cargo, you don't necessarily want to be bringing these around everywhere.
      paths = with pkgs; [
        starship
        # cd with memory
        zoxide
        # better cat
        bat
        tmux
        nvim
        neofetch
        htop
        fzf
        # Search
        ripgrep
        neofetch
        # Better ls
        eza
        # I'll keep alejandra here just because I assume that whereever you are working you will need to edit nix files.
        # I.E. to use this shell, you need a flake.nix, so you need to format that nix anyways.
        alejandra
        direnv
        nix-direnv
      ];
    };
in {
  wrappers.fish = {
    basePackage = fish;
    pathAdd = [
      # Add shellPackages to shell path. This is necessary for `nix-develop`
      shellPackages
    ];
    extraPackages = [
      shellPackages
    ];
  };
}
