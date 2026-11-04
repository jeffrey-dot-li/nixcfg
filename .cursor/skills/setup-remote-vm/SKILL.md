---
name: setup-remote-vm
description: >-
  Bootstrap Nix and this repo's fish shell environment on a fresh remote Linux
  VM (primarily Debian-based GCP instances) or a root-run Coder workspace, and
  install the Pi Coding editor extension into its VS Code / Cursor server.
  Use when the user wants to set up, provision, or migrate to a remote dev box
  whose SSH access is already configured, or set up pi in remote VS Code / Cursor.
  Coder needs a different Nix installer
  and build-user setup because its container has no systemd or mount namespaces.
---

# Setting Up a Remote VM

Bootstraps a fresh Linux VM or Coder workspace with Nix + this repo's shell
(fish). For root-run Coder containers, use the **Coder-specific path below**
instead of VM Steps 1–2; do not run the Lix daemon installer there. This is
bootstrap-only: it does not migrate project data, cloud credentials
(gcloud/gh/kube/docker auth), or copy files from an old VM — that's handled
separately (e.g. `scp`, `gcloud auth login`, `gh auth login`, regenerating
kube contexts).

## Precondition: SSH access must already be configured

This skill requires a working SSH alias already configured in `~/.ssh/config`
(or a Coder extension-managed `Include` file and matching wildcard `Host`).
It does not create or modify SSH config. If there's no entry yet, set one up
first (e.g. following the pattern of other GCP VMs in `~/.ssh/config` using
`gcloud compute start-iap-tunnel`), then verify it works before continuing:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=20 <host-alias> 'echo CONNECTED && cat /etc/os-release'
```

## Coder-specific path: root-run workspace without systemd

Use this only after confirming the exact SSH alias for the active workspace,
`id -u` is `0`, `/etc/os-release` identifies Linux, and PID 1 is `coder` (or
the workspace's container entrypoint). The Coder extension may add SSH aliases
through an `Include` file; do not guess a workspace name or connect to a
different Coder instance. Inspect first: `~/.nix-profile/bin/nix --version`,
`/nix`, `~/.config/nix/nix.conf`, `nix profile list`, and `df -h /nix /root`.
If Nix is already healthy, do not reinstall it.

Coder's root container has no systemd and disallows mount namespaces (`unshare
--mount` fails). The Lix daemon installer used on GCP VMs does **not** work
here. Install upstream Nix in single-user mode instead. This installer warns
that root is unsupported and requires an empty build-user group **during
installation**; don't copy this exception to the final build configuration:

```sh
curl -fsSL https://nixos.org/nix/install -o /tmp/nix-install-coder.sh
NIX_CONFIG='build-users-group =' bash /tmp/nix-install-coder.sh \
  --no-daemon --yes --no-channel-add
```

The installer may be rerun after a partial `/nix` installation. For later
commands in the current shell, use `~/.nix-profile/bin/nix` explicitly or
source `~/.nix-profile/etc/profile.d/nix.sh`. Keep `NIX_REMOTE=local` if an
older Coder shell profile still points at an unavailable Lix daemon.

**Before building the profile**, create unprivileged builder accounts and
configure the root-local Nix store. Only add settings that are absent; preserve
other `nix.conf` settings. On a new workspace:

```sh
getent group nixbld >/dev/null || groupadd -r nixbld
mkdir -p /var/empty
for i in 1 2 3 4; do
  getent passwd "nixbld$i" >/dev/null || \
    useradd -r -M -g nixbld -G nixbld -d /var/empty \
      -s /usr/sbin/nologin "nixbld$i"
done
```

Set these in `~/.config/nix/nix.conf` (replacing any temporary empty
`build-users-group =` line from installation):

```ini
experimental-features = nix-command flakes
build-users-group = nixbld
sandbox = false
sandbox-fallback = false
max-jobs = 2
```

Check only these settings with
`~/.nix-profile/bin/nix config show | grep -E '^(build-users-group|sandbox|sandbox-fallback|max-jobs|experimental-features) ='`
and verify `getent group nixbld`; do not dump other config (it may contain
credentials).
Because Coder blocks mount namespaces, **sandboxing is unavailable**; builders
run as unprivileged `nixbld` users, but builds are not isolated from the
container. Build only trusted flakes. If a previous unsandboxed root build
created `/homeless-shelter`, inspect it and move it to a private backup under
`/root/.cache/` with mode `0700` before retrying; don't blindly delete
unknown contents. A
non-root builder then cannot recreate it at the filesystem root.

### Add the Cachix binary cache before installing the profile

Coder's overlay discards `/etc` and `/nix` on every workspace restart, so this
substituter must be re-added on each bootstrap. Do it **before** installing the
profile, and write it directly rather than with `cachix use`: the `cachix`
binary only arrives with the profile you are about to install. The public key
below is public data, not a credential.

```sh
if ! grep -q 'jeffrey-dot-li.cachix.org' /etc/nix/nix.conf 2>/dev/null; then
  mkdir -p /etc/nix
  cat >> /etc/nix/nix.conf <<'NIXEOF'
substituters = https://cache.nixos.org https://jeffrey-dot-li.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= jeffrey-dot-li.cachix.org-1:51yl0v8t0p7246iaELLSQ4m1Lq2iYWANpyewFgrqJhM=
NIXEOF
fi

~/.nix-profile/bin/nix config show | grep -E '^(substituters|trusted-public-keys) ='
```

Without this, the profile install compiles `tflint`'s Go modules locally and
fails intermittently on `proxy.golang.org` stream errors (observed on a fresh
container: 129 of 133 locally-built outputs were already in the cache, so the
retry succeeds only because of what the cache already held). Pulling needs no
auth token; the cache is public and GitHub Actions pushes `.#default` for
`x86_64-linux`, `aarch64-linux`, and `aarch64-darwin` to it on `main`.

Install the flake's default profile from GitHub (this uses the committed
revision, not uncommitted changes in a local checkout):

```sh
~/.nix-profile/bin/nix profile add github:jeffrey-dot-li/nixcfg#default --priority 4
~/.nix-profile/bin/nix profile list
~/.nix-profile/bin/pi --version
~/.nix-profile/bin/deno --version
```

The existing Coder `.profile` may already initialize a shell, and the Nix
installer appends its own shell hooks. Inspect before editing `.profile`,
`.bashrc`, or `~/.config/fish/config.fish`; do not overwrite Cursor/Coder
bootstrap or credential sourcing. Check plain SSH *and* Cursor's integrated
terminal separately. `/root` may be on a persistent PVC while `/nix` lives on
the container overlay: a **recreated** workspace can lose the store and need
bootstrap again. Do not symlink or bind-mount `/nix` to the PVC without an
explicit persistence design.

## Step 1: Install Nix (ordinary GCP/Debian VM)

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

## Step 3: Make fish the interactive shell (ordinary VM; inspect first on Coder)

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

bash only auto-sources `~/.profile` for **login** shells. A plain
`ssh host` (no command) starts a login shell, so the above works
out of the box. But Cursor/VS Code Remote-SSH's integrated terminal panel
spawns an **interactive, non-login** bash for the terminal, which only reads
`~/.bashrc` — so without the below, that terminal stays in bash even though
plain `ssh` correctly drops into fish. Append this to `~/.bashrc` too (safe
to source unconditionally: `.profile` guards against double-sourcing and
only execs into fish when a real tty is attached):

```sh
if [ -f "$HOME/.profile" ]; then
	. "$HOME/.profile"
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
- `nix profile list` shows `nixcfg` (and `cachix` on the ordinary VM path).
- Non-interactive commands still work in plain bash: `ssh <host-alias> 'echo $-'` should not exec fish.
- If accessed via Cursor/VS Code Remote-SSH, open a terminal panel there too
  and confirm it drops into fish (not just plain `ssh` from a local terminal)
  — this exercises the `.bashrc` path, not just `.profile`.

## Step 5: Pi Coding extension in remote VS Code / Cursor

Pi Coding (`jeffrey-dot-li.pi-coding`) is our fork of
[dcalsky/pi-vscode](https://github.com/dcalsky/pi-vscode), at
<https://github.com/jeffrey-dot-li/pi-vscode>. It runs the real Nix-wrapped
`pi` TUI in a native terminal editor, with a session list in the secondary
(right) sidebar, per-session working/waiting status, a tone when a session
starts waiting, and reopening of open sessions after a window reload. It is
packaged as `.#pi-vscode` (`packages/pkgs/pi-vscode/default.nix`), which
outputs the unpacked extension, a VSIX, and `pi-vscode-install`.

**Why remote needs its own install.** Under Remote-SSH the window runs on the
laptop but extensions with `extensionKind: workspace` (this one) run in the
editor *server* on the VM, from the VM's own extensions dir
(`~/.vscode-server/extensions` or `~/.cursor-server/extensions`). The editors
module (`packages/wrapper-manager/editors`) only links curated extensions
into the *local* editors, and the fork is not on any marketplace, so the VS
Code "Install in SSH" / `remote.SSH.defaultExtensions` paths do not apply.
The fork's publisher is renamed to `jeffrey-dot-li` on purpose: never also
install upstream `EthanChow.pi-coding`, which registers the same `piAgent.*`
commands and would be what the marketplace pulls in instead.

1. **Connect once** with the editor (VS Code and/or Cursor) via Remote-SSH so
   its server exists on the VM:
   - VS Code: `~/.vscode-server/cli/servers/Stable-<commit>/server/bin/code-server`
   - Cursor: `~/.cursor-server/bin/linux-x64/<commit>/bin/cursor-server`

2. **Install the extension** from the profile (installed in Step 2, so
   `pi-vscode-install` is on PATH; run `nix profile upgrade nixcfg --refresh`
   first if the profile predates `pi-vscode`):

   ```sh
   pi-vscode-install
   ls -d ~/.vscode-server/extensions/jeffrey-dot-li.pi-coding-* \
         ~/.cursor-server/extensions/jeffrey-dot-li.pi-coding-* 2>/dev/null
   ```

   It installs the packaged VSIX with `--force` into the newest build of every
   VS Code / Cursor server it finds (falling back to `cursor`/`code` on PATH).
   The extensions dir is shared across server builds, so an editor update
   does not require reinstalling; a new fork revision does.

3. **Point it at the Nix pi** with a *machine* setting, merged into the
   existing file (Cursor's usually already holds the fish terminal profile;
   don't overwrite it). Do this for each editor in use:

   ```sh
   for m in ~/.vscode-server/data/Machine/settings.json ~/.cursor-server/data/Machine/settings.json; do
     [ -d "$(dirname "$(dirname "$m")")" ] || continue   # editor never connected
     mkdir -p "$(dirname "$m")"; [ -f "$m" ] || echo '{}' > "$m"
     cp "$m" "$m.bak"
     python3 - "$m" <<'EOF'
   import json, os, sys
   p = sys.argv[1]; d = json.load(open(p))
   d["piAgent.command"] = os.path.expanduser("~/.nix-profile/bin/pi")
   json.dump(d, open(p, "w"), indent=4)
   EOF
   done
   ```

   Without it the extension falls back to `which pi` in the server's
   environment, which may not include `~/.nix-profile/bin`. A machine setting
   (not a user setting) is required because the path is per-host. If the file
   has comments (JSONC), `json.load` fails: edit it by hand instead.
   Optionally copy the fish terminal profile from Cursor's machine settings
   into VS Code's so plain terminals use fish too.

4. **Verify** in the remote window: run **Developer: Reload Window**, then
   **Pi: Open** (or the terminal icon in the editor toolbar); the Pi session
   list appears in the secondary sidebar (toggle with ⌥⌘B). The Extensions
   view should list Pi Coding under **SSH: <host> – Installed**, not Local.
   Start a session, then check on the VM that it was launched by the
   extension:

   ```sh
   for p in $(pgrep -f 'pi-unwrapped|\.pi-wrapped'); do
     tr '\0' ' ' </proc/$p/cmdline | grep -- '--extension .*pi-vscode-status.ts' && echo; done
   ```

   Expect `... --session-id <id> --extension .../pi-vscode-status.ts` (plus
   `--tui-mode regular` unless `piAgent.tuiMode` is `inherit`).

**Updating the fork.** Push to `jeffrey-dot-li/pi-vscode`, bump `rev` and
`hash` in `packages/pkgs/pi-vscode/default.nix` (`npmDepsHash` too if
`package-lock.json` changed), build `nix build .#pi-vscode`, commit and push
nixcfg, then on the VM: `nix profile upgrade nixcfg --refresh &&
pi-vscode-install`, and reload the window.

**Fallback before nixcfg is pushed** (or with no profile on the VM): build
locally and copy the VSIX under a *unique* name, because a previously copied
VSIX from the Nix store is read-only and `scp` cannot overwrite it:

```sh
nix build .#pi-vscode -o result-pi-vscode
scp result-pi-vscode/share/pi-vscode/pi-coding.vsix <host-alias>:/tmp/pi-coding-$(date +%s).vsix
# then on the VM, per server:  <server-cli> --install-extension /tmp/pi-coding-<ts>.vsix --force
```

The VSIX is platform-independent (node-pty ships prebuilt `pty.node` for
Linux and macOS on x64/arm64; the package skips install scripts and fixup so
those binaries are untouched), so a VSIX built on the Mac works on the VM.

**Gotchas.**

- Fullscreen TUI (`piAgent.tuiMode: inherit` with pi `tuiMode: fullscreen`):
  needs fork ≥ `1d682e5`, which replays pi's SGR mouse encoding on attach;
  older builds leave the wheel "frozen" until pi re-sends its modes.
- A CLI-installed extension may not appear in an already-open window until
  **Developer: Reload Window**, and it only activates on **Pi: Open** / its
  view, so seeing nothing before that is normal.
- Session order in the list is by last *prompt* (fork ≥ `4fe3c6e`); older
  builds sorted by file mtime and reshuffled ties every refresh.

## Out of scope (handle separately per-VM)

- `gcloud auth login` / `gh auth login` for fresh credentials.
- Regenerating `~/.kube/config` contexts (cluster-specific, don't copy raw).
- Docker / apt packages not part of the base VM image (e.g. `build-essential`, `docker-ce`, `clang`) — reinstall via `apt` as needed.
- Copying project data / dotfiles not covered above — use `scp`/`rsync`.
