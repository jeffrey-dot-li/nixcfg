{
  inputs,
  pkgs,
  ...
}: let
  user = "jeffrey";
  shellWrapper = let
    colors = inputs.nix-colors.colorSchemes.catppuccin-frappe.palette;
  in
    pkgs.callPackage ../../shell {inherit pkgs inputs colors;};
in {
  programs.zsh.enable = true;
  services.nix-daemon.enable = true;
  nixpkgs.hostPlatform = "aarch64-darwin";
  environment.systemPackages = with pkgs; [
    cargo
    alejandra
  ];
  users.knownUsers = [user];

  networking.hostName = "applin";
  nix.settings.experimental-features = "nix-command flakes";
  system.stateVersion = 4;
  users.users."${user}" = {
    home = "/Users/${user}";
    shell = "${shellWrapper}/bin/nucleus";
    uid = 501;
  };
  environment.shells = ["${shellWrapper}/bin/nucleus"];
  security.pam.enableSudoTouchIdAuth = true;
}
