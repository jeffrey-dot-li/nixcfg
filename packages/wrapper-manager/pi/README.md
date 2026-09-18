# Pi

`default.nix` packages the upstream standalone Pi release and the default
third-party Pi packages. Pi packages are pinned Git revisions built with
`buildNpmPackage`; Pi supplies their SDK peer dependencies, while Nix installs
only their runtime dependencies. Dependency lifecycle scripts are disabled.

## Managed packages

The current Nix-managed Pi packages are:

- `pi-subagents`
- `pi-web-access`

The Pi configuration directory must remain writable because it also contains
authentication, sessions, model configuration, and user preferences. The
wrapper therefore does not replace `~/.pi/agent/settings.json` with an
immutable Nix store file. Before Pi starts, it instead merges the managed
package store paths into the existing `packages` array. It preserves unrelated
settings and packages, and replaces stale Nix paths or `npm:` entries for the
packages managed here. `PI_CODING_AGENT_DIR` is respected when it overrides the
default configuration directory.

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
not part of the runtime closure. The shared `postPatch` removes those entries,
including local development links, before Nix computes and installs the npm
dependency set. Keep this normalization when updating the packages unless the
upstream lockfile structure and runtime requirements have been reviewed.
