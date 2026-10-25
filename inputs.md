# Flake inputs

Every root input in `flake.nix`, what it is, and why it is here. Keep this in sync when adding or removing an input.

| Input | Source | What it is | Why we have it | Used by |
| --- | --- | --- | --- | --- |
| `nixpkgs` | `github:nixos/nixpkgs/nixos-unstable` | The Nix package collection and NixOS modules. | Base of every package and system; also provides Lix (`nix.package = pkgs.lix`). Every other input follows it. | All hosts, packages |
| `nix-darwin` | `github:LnL7/nix-darwin` | NixOS-style system configuration for macOS. | Builds the `applin` and `co-applin` Darwin systems. | `hosts/darwin` |
| `home-manager` | `github:nix-community/home-manager` | Per-user config management. | **Currently unreferenced** outside `flake.nix` (only locked); candidate for removal. | none found |
| `flake-parts` | `github:hercules-ci/flake-parts` | Module system for structuring flake outputs. | Structure of `flake.nix` (`mkFlake`, `perSystem`, `withSystem`). | `flake.nix` |
| `treefmt-nix` | `github:numtide/treefmt-nix` | Multi-language formatter wrapper (flake-parts module). | Provides `nix fmt` with `alejandra` and excludes `secrets/*.age`. | `flake.nix` |
| `nvf` | `github:notashelf/nvf` | Neovim configuration framework in Nix. | Builds the `nvim` and `nvim-min` packages. | `packages/pkgs/nvim` |
| `wrapper-manager` | `git+https://codeberg.org/viperML/wrapper-manager` | Builds wrapped programs (env, flags, config baked in) from Nix modules. | Builds the wrapped `fish`, `git`, `kitty`, `codex`, `pi`, editors, `terraform`, `tflint`. Single maintainer; update deliberately. | `packages/wrapper-manager`, `packages/default.nix` |
| `agenix` | `github:ryantm/agenix` | Age-encrypted secrets for NixOS. | Decrypts secrets on `latte` and provides the `agenix` CLI. Handles secrets, so read the diff when bumping. | `hosts/nixos`, `hosts/nixos/latte/cloudflare.nix` |

## Notes

- Lix comes from nixpkgs (`pkgs.lix`), so there is no Lix input. `flake-compat` in the lock is a dependency of `nvf`.
- Inputs pinned to a commit or tag in their URL do not move on `nix flake update`; branch-tracking ones do.
