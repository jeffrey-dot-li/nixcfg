# Pi

`default.nix` packages the upstream standalone Pi release and the default
third-party Pi packages. Pi packages are pinned Git revisions built with
`buildNpmPackage`; Pi supplies their SDK peer dependencies, while Nix installs
only their runtime dependencies. Dependency lifecycle scripts are disabled.

## Managed packages

The current Nix-managed Pi packages are:

- local `pi-managed-resources` agents and extensions
- `pi-bg`
- `pi-subagents`
- `pi-web-access`
- `pi-mcp-adapter`
- `pi-cc-extensions`
- `@juicesharp/rpiv-ask-user-question`
- `@juicesharp/rpiv-todo`

`pi-bg` adds a non-blocking `bg` tool and `/bg` command for spawning,
inspecting, and stopping arbitrary background shell jobs. Jobs can queue their
result or wake the parent session on completion, and retained logs are stored
under the Pi agent directory. It is pinned and installed by Nix like the other
managed packages.

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

- `Enter`: submit normally; while the agent is busy, ordinary prompts steer the
  current run, recognized commands execute immediately, and skill commands are
  rerouted by the managed extension to the follow-up queue
- `Ctrl+Enter`, `Shift+Enter`, or `Ctrl+J`: insert a newline
- `Option+Enter`: queue a follow-up while the agent is busy
- `Ctrl+Q` or `Option+Up`: restore queued messages to the editor
- `Escape`: Pi's existing immediate interrupt binding; it also restores queued
  messages to the editor

`Ctrl+Q` is provided because integrated terminals may intercept or incorrectly
encode `Option+Up` before Pi receives it.

The managed `queue-skills-follow-up.ts` input extension recognizes commands
whose Pi command source is `skill`. When a skill is submitted interactively
while an agent is busy, it resubmits the unexpanded skill invocation as a
follow-up and lets Pi perform normal skill expansion there. Built-in and
extension commands continue through Pi's immediate command dispatch, while
ordinary prompts retain normal steering behavior.

The managed `guard-invalid-slash.ts` input extension prevents accidental
submission of mistyped slash commands. In the interactive editor, input that
starts with `/` is submitted normally only when Pi recognizes the command. An
unknown command is not added to the conversation or queue, and its text stays
in the editor for correction. Normal prompts and non-interactive RPC, print,
and JSON input retain Pi's standard behavior.

## Subagent model tiers

The wrapper merges a managed `subagents.agentOverrides` block into writable
`settings.json`. Unrelated subagent settings and per-role fields are preserved,
while Nix owns the model and thinking fields listed below. Explicit per-run
model arguments still take precedence; this configuration does not impose a
`modelScope` restriction.

| Class | Roles | Model | Thinking |
| --- | --- | --- | --- |
| Monitor | `monitor` | `agent-control-plane/north-mini-code-1-0` | `low` |
| Playbook | `scout` | `agent-control-plane/gpt-5.6-luna` | `low` |
| Playbook | `delegate` | `agent-control-plane/gpt-5.6-luna` | `medium` |
| Working | `worker`, `reviewer`, `researcher`, `evidence-auditor` | `agent-control-plane/gpt-5.6-sol` | `medium` |
| Highest | `oracle` | `agent-gateway-dev/us.openai.gpt-6-astra` | disabled |

Astra is registered without Pi reasoning-level support, so the `oracle`
override explicitly disables `thinking` instead of inheriting the builtin
`high` value. External Claude, Codex, and Cursor CLI roles are not remapped.

The local `agents/monitor.md` definition observes exactly one already-running
task and defaults to an asynchronous run. It has `read`, `grep`, `find`, `ls`,
`bash`, and `contact_supervisor`, but no edit, write, web, MCP, or subagent
tools. It treats the first consistent snapshot as the baseline, suppresses
routine progress, reports the first
unexpected condition to the parent without diagnosis or remediation, and
otherwise reports only terminal completion. Its prompt also prohibits
exposing credentials or environment-variable values.

The monitor's read-only behavior is a prompt-enforced policy, not an operating
system sandbox. The generic `bash` tool is retained so it can inspect tmux,
processes, logs, health endpoints, resource state, and Git identity, but that
tool is technically capable of mutation. Replace it with a narrow custom tool
if capability-level read-only enforcement becomes necessary.

After rebuilding and starting a new Pi process, inspect the effective mapping
with:

```text
/subagents-models
/subagents-models monitor
```

The monitor does not launch or choose stronger agents. It reports anomalies
through `contact_supervisor`; the parent retains escalation and publication
authority.

## MCP OAuth on headless SSH hosts

`pi-mcp-adapter` stores OAuth credentials in the operating system's secure
credential store by default. A headless Linux or SSH session can have a D-Bus
session address without an available or unlocked Secret Service keyring. In
that case, authentication fails with an error similar to:

```text
Failed to read OAuth credentials from the OS secure credential store
```

Use the adapter's externally keyed encrypted-file backend on such hosts. Add
this setting to the existing global MCP configuration, normally
`~/.config/mcp/mcp.json`:

```json
{
  "settings": {
    "oauthCredentialStore": "encrypted-file"
  }
}
```

Generate a separate 32-byte key and restrict its permissions. Do not put this
key in Git, a Nix derivation, or the MCP JSON file:

```sh
mkdir -p ~/.config/pi-mcp-adapter
umask 077
openssl rand -base64 32 > ~/.config/pi-mcp-adapter/oauth-file-key
chmod 600 ~/.config/pi-mcp-adapter/oauth-file-key
```

Export the key before starting Pi. For Fish, create
`~/.config/fish/conf.d/pi-mcp-oauth.fish`:

```fish
set -l key_file "$HOME/.config/pi-mcp-adapter/oauth-file-key"
if test -r "$key_file"
    set -gx PI_MCP_ADAPTER_OAUTH_FILE_KEY (string trim < "$key_file")
end
```

For Bash or another POSIX shell, place the equivalent in the appropriate
private login-shell configuration:

```sh
key_file="$HOME/.config/pi-mcp-adapter/oauth-file-key"
if [ -r "$key_file" ]; then
  export PI_MCP_ADAPTER_OAUTH_FILE_KEY="$(tr -d '\n' < "$key_file")"
fi
```

Start a new shell, or source the new shell fragment, then authenticate:

```text
/mcp-auth <server>
```

When Pi runs over SSH, open the displayed authorization URL in a local browser.
If the final localhost callback page cannot connect, copy its entire URL from
the browser address bar and paste it into the same Pi authentication flow.
Verify the result with `/mcp reconnect <server>` and `/mcp status`.

Encrypted credentials are stored under
`~/.pi/agent/mcp-oauth-encrypted/` (or the selected
`PI_CODING_AGENT_DIR`). Back up the key separately if credentials must survive
host migration. Losing or rotating it only requires authenticating again.

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
