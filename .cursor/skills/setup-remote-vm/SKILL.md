---
name: setup-remote-vm
description: >-
  Bootstrap Nix and this repo's fish shell environment on a fresh remote Linux
  VM (primarily Debian-based GCP Compute Engine instances) that is already
  reachable via an entry in ~/.ssh/config. Use when the user wants to set up,
  provision, or migrate to a new remote VM/dev box whose SSH access is
  already configured.
---

# Setting Up a Remote VM

Bootstraps a fresh Linux VM with Nix + this repo's shell (fish). This is
bootstrap-only: it does not migrate project data, cloud credentials
(gcloud/gh/kube/docker auth), or copy files from an old VM — that's handled
separately (e.g. `scp`, `gcloud auth login`, `gh auth login`, regenerating
kube contexts).

## Precondition: SSH access must already be configured

This skill requires a working `Host` entry for the VM already present in
`~/.ssh/config` — it does not create or modify SSH config. If there's no
entry yet, set one up first (e.g. following the pattern of other GCP VMs in
`~/.ssh/config` using `gcloud compute start-iap-tunnel`), then verify it
works before continuing:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=20 <host-alias> 'echo CONNECTED && cat /etc/os-release'
```

## Step 1: Install Nix

On the remote VM:

```sh
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

Reconnect (new shell needed to pick up `~/.local/bin/env`).

## Step 2: Bootstrap this repo's shell via Cachix

```sh
nix profile install nixpkgs#cachix
cachix use jeffrey-dot-li

nix profile install github:jeffrey-dot-li/nixcfg --priority 4
```

This installs the `default` package from this flake (the fish-based shell
wrapper + toolset) directly from GitHub — no need to clone the repo onto the
VM for this step. Update later with:

```sh
nix profile upgrade nixcfg --refresh
```

## Step 3: Make fish the interactive shell

`chsh` to a Nix-store path is unreliable on GCP images (PAM/`/etc/shells`
issues), so don't rely on it. Instead, `~/.profile` execs into fish only for
interactive human sessions, and stays out of the way for automation
(Cursor remote-server bootstrap, `ssh host '<cmd>'`, `scp`/`rsync`). Write
this to `~/.profile` on the remote VM if not already present:

```sh
#! /bin/bash

if [ "$__USER_SHELL_SOURCED" = "1" ]; then
	return
fi
__USER_SHELL_SOURCED=1

# Make nix / user tools available on PATH for every shell, including
# non-interactive ones used by automation and Cursor's remote-server setup.
if [ -f "$HOME/.local/bin/env" ]; then
	. "$HOME/.local/bin/env"
fi

# Only a human opening an interactive session should be dropped into fish.
# Key off interactivity ($- contains 'i') rather than login-ness, since
# non-interactive invocations must fall through to plain bash untouched.
case "$-" in
	*i*) : ;;        # interactive -> continue below
	*)   return ;;   # non-interactive -> stop here, stay in bash
esac

if [ -t 0 ] && [ -t 1 ]; then
	: "${SHELL_PATH:=$(command -v fish)}"
	if [ -n "$SHELL_PATH" ]; then
		export SHELL="$SHELL_PATH"
		exec "$SHELL" -l
	fi
fi
```

## Step 3.5: Fish config.fish boilerplate

The nix-managed fish wrapper (`packages/wrapper-manager/fish/default.nix`)
sources `~/.config/fish/config.fish` at the end of its interactive setup, so
write this boilerplate there:

```fish
fish_add_path --move --prepend ~/.nix-profile/bin
fish_add_path --move --prepend /nix/var/nix/profiles/default/bin
fish_add_path --move --prepend /run/current-system/sw/bin

if status is-interactive
    echo "HI FROM FISH CONFIG"
end
```

`HOMEBREW_GIT_PATH` does **not** need to be set here — it's exported
automatically by `packages/wrapper-manager/fish/default.nix` as a build-time
Nix store path (`${lib.getExe pkgs.gitFull}`), which is valid regardless of
whether this package ended up on the machine via a nix-darwin/NixOS system
closure or a plain `nix profile install` on a generic Linux VM. No
per-machine override or runtime `command -v git` resolution needed.

Do **not** add secrets (API keys, tokens) directly to this file — it's fine
to keep VM/company-specific tool config (e.g. `brew shellenv`, project
aliases) here, but secrets belong in a separate untracked, `chmod 600` file
(e.g. `~/.config/fish/conf.d/secrets.fish`) sourced conditionally, or in this
repo's `agenix` secrets if they need to be reproducible across machines.

## Step 4: Verify

Reconnect via the SSH host alias and confirm:

- `echo $SHELL` reports the fish path and an interactive session drops into
  fish.
- `nix profile list` shows `cachix` and `nixcfg`.
- Non-interactive commands still work in plain bash: `ssh <host-alias> 'echo $-'` should not exec fish.

## Out of scope (handle separately per-VM)

- `gcloud auth login` / `gh auth login` for fresh credentials.
- Regenerating `~/.kube/config` contexts (cluster-specific, don't copy raw).
- Docker / apt packages not part of the base VM image (e.g. `build-essential`, `docker-ce`, `clang`) — reinstall via `apt` as needed.
- Copying project data / dotfiles not covered above — use `scp`/`rsync`.
