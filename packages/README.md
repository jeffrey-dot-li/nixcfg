# Packages

This directory defines the packages exported by the flake. It supports
self-configuring packages, packages built with `wrapper-manager`, and the
default shell environment.

## Directory structure

```text
packages/
├── default.nix          # Discovers and combines all package definitions
├── profile/             # Default package installed by `nix profile install .`
├── pkgs/                # Self-contained or self-configuring packages
│   └── nvim/
└── wrapper-manager/     # Packages configured through wrapper-manager
    ├── fish/
    ├── git/
    └── kitty/
```

## Package discovery

Every immediate subdirectory of `pkgs/` is discovered automatically and
evaluated with `callPackage`. A package such as:

```text
packages/pkgs/example/default.nix
```

is therefore exported as:

```text
packages.<system>.example
```

It can be built or installed with:

```sh
nix build .#example
nix profile install .#example
```

Adding a normal single-output package does not require editing
`packages/default.nix`.

The `callPackage` scope contains both nixpkgs and the other custom packages in
this directory. This allows one custom package to request another by function
argument.

Avoid requesting an upstream package with the same name as the directory being
defined. For example, a hypothetical `pkgs/ripgrep/default.nix` should use
`pkgs.ripgrep` rather than a function argument named `ripgrep`; the latter can
recursively resolve to the custom package itself.

## Self-configuring packages

Packages under `pkgs/` should bundle their configuration when practical. For
example, the Neovim package builds its nvf configuration into the resulting
package. This keeps it portable across nix-darwin, NixOS, and direct profile
installation.

The Neovim definition is a special case because it returns both `nvim` and
`nvim-min`. Those outputs are exported explicitly in `packages/default.nix`.

## wrapper-manager packages

Every immediate subdirectory of `wrapper-manager/` is loaded as a
`wrapper-manager` module. The packages produced by those modules are merged
with the packages from `pkgs/`.

Use this directory when configuration depends on `wrapper-manager`; otherwise,
prefer a self-contained package under `pkgs/`.

Kitty is managed here because its configuration is selected through the
`KITTY_CONFIG_DIRECTORY` environment variable. Its module also wraps the
executable inside `$out/Applications/kitty.app` on Darwin because launching the
app through Finder does not invoke its `$out/bin` wrapper.

## Default profile

`profile/default.nix` builds the combined command-line environment. The flake
exports it as `packages.<system>.default`, so:

```sh
nix profile install .
```

installs only `profile` and its dependencies. It does not build every package
exported by the flake. To install another package directly, select its flake
attribute, for example:

```sh
nix profile install .#kitty
```

The nix-darwin and NixOS configurations currently add
`builtins.attrValues self'.packages` to `environment.systemPackages`. As a
result, system rebuilds install every exported package, including Kitty.

## Git-backed flakes

Nix excludes untracked files when evaluating a flake from a Git working tree.
After adding a new package directory, stage it before evaluating or rebuilding:

```sh
git add packages/pkgs/example
```

The files do not need to be committed for a local rebuild, but they must be
known to Git.
