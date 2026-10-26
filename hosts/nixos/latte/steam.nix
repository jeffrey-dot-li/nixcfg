{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
  };
  programs.gamemode.enable = true;
  # NixOS sets mmap_rnd_bits to the kernel max (32) via 55-nixos-aslr-entropy.conf.
  # With that much entropy Proton's wine64-preloader can be mapped inside the
  # range its inherited seccomp filter traps, so 32->64-bit spawns die with SIGSYS
  # (broke the Ghost of Tsushima PSPC SDK install). Restore kernel defaults.
  boot.kernel.sysctl = {
    "vm.mmap_rnd_bits" = 28;
    "vm.mmap_rnd_compat_bits" = 8;
  };
  hardware.graphics = {
    extraPackages = with pkgs; [mangohud];
    extraPackages32 = with pkgs; [mangohud];
  };
  environment.systemPackages = with pkgs; [mangohud protonup-qt lutris bottles heroic];
}
