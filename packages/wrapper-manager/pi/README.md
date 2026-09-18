# Pi

`default.nix` packages the upstream standalone Pi release and the default
third-party Pi packages. Pi packages are pinned Git revisions built with
`buildNpmPackage`; Pi supplies their SDK peer dependencies, while Nix installs
only their runtime dependencies. Dependency lifecycle scripts are disabled.

## Managed packages

The current Nix-managed Pi packages are:

- `pi-subagents`
- `pi-web-access`
- `pi-mcp-adapter`
- `pi-cc-extensions`
- `@juicesharp/rpiv-ask-user-question`
- `@juicesharp/rpiv-todo`

The Pi configuration directory must remain writable because it also contains
authentication, sessions, model configuration, and user preferences. The
wrapper therefore does not replace `~/.pi/agent/settings.json` with an
immutable Nix store file. Before Pi starts, it instead merges the managed
package store paths into the existing `packages` array. It preserves unrelated
settings and packages, and replaces stale Nix paths or `npm:` entries for the
packages managed here. `PI_CODING_AGENT_DIR` is respected when it overrides the
default configuration directory.

The wrapper similarly merges the following queue controls into writable
`keybindings.json`, preserving unrelated custom bindings:

- `Enter`: submit normally when idle; queue a follow-up while the agent is busy
- `Ctrl+Enter` or `Option+Enter`: submit normally when idle; steer the current
  run while the agent is busy
- `Ctrl+Q` or `Option+Up`: restore queued messages to the editor
- `Escape`: Pi's existing immediate interrupt binding; it also restores queued
  messages to the editor

`Ctrl+Q` is provided because integrated terminals may intercept or incorrectly
encode `Option+Up` before Pi receives it.

## Updating packages

Do not update managed packages with `pi update --extensions`; their versions
are owned by Nix. To update one:

1. Change its version and pinned commit in `default.nix`.
2. Update the source `hash` and `npmDepsHash` values.
3. Build and verify Pi:

   ```sh
   nix build .#pi
   ./result/bin/pi list
   ```

Use `lib.fakeHash` temporarily for a changed hash and copy the `got:
sha256-...` value from the failed build.

The package lockfiles include development and host peer dependencies that are
not part of the runtime closure. The package normalization removes those
entries, including unneeded local development links, before Nix computes and
installs the npm dependency set. Keep this normalization when updating the
packages unless the upstream lockfile structure and runtime requirements have
been reviewed.
