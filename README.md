
```sh
sudo nixos-rebuild switch --flake .#appletun
sudo nix run nix-darwin -- switch --flake '.#applin' --show-trace
darwin-rebuild switch --flake .\#applin --option extra-sandbox-paths /nix/store
nix profile install
# List with
nix profile list
# Remove with
nix profile remove
```

# Get default shell working:

## Mac OS

### Install Nix:
Install Nix with https://nixcademy.com/posts/nix-on-macos/ guide: https://github.com/DeterminateSystems/nix-installer

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Run configuration script:
```sh
nix run nix-darwin -- switch --flake .\#applin
```

### Test it works
```sh
nix flake update
darwin-rebuild switch --flake .\#applin --option extra-sandbox-paths /nix/store --option sandbox relaxed
```
 - Note: the extra option is to make sure it doesn't exceed max sandbox size, not 100% sure why it does this but it wil exceed when building latex. See https://github.com/NixOS/nix/issues/4119#issuecomment-2561973914.

At this point `nvim` should also be configured. 
Shell environment variable should be set in both `$SHELL_PATH` and `cat /etc/shells` (it will resolve to something like `/nix/store/js5ylmh31vk4zr23vs9jasj1s51rz43f-wrapper-manager/bin/nucleus`).

Last just configure system to use it as default shell in `~/.profile`:
```sh
#! /bin/bash

eval "$(/opt/homebrew/bin/brew shellenv)"
code() { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args "$argv"; }
echo "HI FROM PROFILE $__USER_SHELL_SOURCED"

if [ "$__USER_SHELL_SOURCED" = "1" ]; then
	return
fi
__USER_SHELL_SOURCED=1
if [ -n "${SHELL_PATH}" ]; then
	export SHELL="$SHELL_PATH"
	exec $SHELL
else
	echo "Error: SHELL_PATH is not defined" >&2
	echo "Default shell is $(dscl . -read /Users/"$USER" UserShell | sed 's/UserShell: //')"
fi
```

Finally, in `~/.zprofile` just source the `~/.profile`:
```sh
source ~/.profile
```

Note that this relies on the default shell being loaded to be zsh.
This is because if we set to bin/nucleus by default, it can't read system environment variables properly (So `nix` will not be defined).
We set it to zsh, and then load the shellWrapper in the ~/.profile from the $SHELL_PATH environment variable.

When opening terminal, should see something like 
```
Last login: Sun Nov  3 21:55:05 on ttys021
HI FROM ./~ZSHENV
HI FROM ZPROFILE 
HI FROM PROFILE 
HI FROM FISH CONFIG
Welcome to fish, the friendly interactive shell
Type help for instructions on how to use fish
~ on ☁️  jeffreyli@cohere.com 
```

Use `chsh -s /bin/zsh` to set the default shell to zsh.
Use `dscl . -read ~/ UserShell` to check the current shell.

Note also that kitty for some reason doesn't always update to shell defined by `dscl . -read ~/ UserShell` immediately. I don't know why there is a desync against default terminal program on Mac. Always check default terminal program on Mac to see what shell is actually being used.

## Updating
```sh
nix flake update
```

## Use this Shell as a dependency:
### Deprecated! Don't do this, just use direnv + whatever flake.nix you wnat to use
### TODO: Write a guide on how to use direnv with nix flakes

The correct pattern is, in another project, create a `flake.nix` that uses that projects dependencies (node, python, etc).
To use this shell as the base, add the following:

```nix
# Template from https://github.com/the-nix-way/dev-templates/blob/main/README.md
# Run `nix develop`
{
  description = "A Nix-flake-based development environment";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
    # Add your base development environment as an input
    base-dev.url = "github:jeffrey-dot-li/nixcfg";
  };

  outputs = {
    self,
    nixpkgs,
    base-dev,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [self.overlays.default];
          };
        });
  in {
    overlays.default = final: prev: rec {
			# Add your project's dependency overrides here:
    };

    devShells = forEachSupportedSystem ({pkgs}: {
      default = pkgs.mkShell {
        inputsFrom = [base-dev.devShells.${pkgs.system}.default];
        packages = with pkgs; [...]; # Add your project's dependencies here (e.g. `nodejs-18_x`)
        shellHook = ''
					... # Add your project's shellHook here
        '';
      };
    });
  };
}
```


## Debian:
### Install:

Install nix, clone repo. (TODO: Add instructions for installing nix on Debian) 

### Setup:
```sh
#TODO: add documentation to make sure experimental features are enabled
# experimental-features = nix-command flakes

# Then install:
pushd nixcfg
nix profile install
# Don't need to install direnv separately, comes with the shell package.
# Run:
direnv allow
# Upgrade:
nix profile upgrade "nixcfg"
```

This will install into `~/.nix-profile/bin`. Can list with `nix profile list` and remove with `nix profile remove`.

### Path configuration:

```sh
# Set default shell to fish
# Note: This is broken for some reason on GCP. 
# See https://stackoverflow.com/questions/52768537/how-to-change-default-shell-in-a-gce-vm-instance
chsh -s ~/.nix-profile/bin/fish

# If you can't do that, just stick this in like .bashrc or something
~/.nix-profile/bin/fish
```



# Cleaning out old builds:
TODO: add these as aliases 

```sh
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations 123
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +5 # keeps the last 5 generations
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations 30d # keeps the last 30 days
```

TODO: Document how to clean nix garbage after rebuilds.
```sh
nix-store --gc
```




# COMMON ERRORS:

## Git: `No user exists for uid xxxx`
-> https://discourse.nixos.org/t/unable-to-use-nixpkgs-git-on-rhel-7/12598

```sh
sudo apt install nscd
sudo systemctl enable nscd
sudo systemctl start nscd
```