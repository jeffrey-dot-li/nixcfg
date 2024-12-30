sudo nixos-rebuild switch --flake .#appletun
sudo nix run nix-darwin -- switch --flake '.#applin' --show-trace
nix profile install