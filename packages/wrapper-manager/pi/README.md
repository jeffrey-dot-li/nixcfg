# Pi

`default.nix` packages the upstream standalone Pi release and the default
third-party Pi packages. Packages are pinned to immutable Git revisions or npm
release archives. Pi supplies their SDK peer dependencies, while Nix installs
only required runtime files. Dependency lifecycle scripts are disabled.

## Managed packages

The current Nix-managed Pi packages are:

- local `pi-managed-resources` agents and extensions
- `pi-background-task`
- `pi-subagents`
- `pi-web-access`
- `pi-mcp-adapter`
- `pi-cc-extensions`
- `@juicesharp/rpiv-ask-user-question`
- `@juicesharp/rpiv-todo`

`pi-background-task` provides tmux-backed, non-blocking background terminals.
Agents use `task_start`, `task_status`, `task_logs`, `task_send`, `task_wait`,
and `task_kill`; `/bg-tasks` opens the live task dashboard. Output is captured
to durable, byte-pageable logs, completion notifications wake Pi by default,
and task visibility follows the current session tree across reload, resume,
and fork operations. A real Pi quit cancels jobs owned by that runtime.
Runtime files are kept outside project trees under
`${XDG_STATE_HOME:-~/.local/state}/pi/background-tasks/projects/<cwd-hash>/`,
so repositories do not need package-specific ignore rules. Set
`PI_BACKGROUND_TASK_STATE_DIR` to override the global state root.

The Nix package carries a small UX patch. Agent-launched jobs require a short
human-readable `name` in addition to the command. Dashboard rows display
`name — command`, and `x` stops the selected running task. Enter expands live
output, `r` refreshes, and Escape or `q` closes the dashboard. The wrapper adds
`tmux` and Node to Pi's `PATH` and directs the detached runner to Nix's Node
binary (the standalone Pi executable cannot act as a Node interpreter). Users
do not need to manage tmux sessions manually.

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

- `Enter`: submit normally while idle; while the agent is busy, recognized
  commands execute immediately and all model-bound input (ordinary prompts,
  skills, and prompt templates) is rerouted to the follow-up queue
- `Ctrl+Enter`, `Shift+Enter`, or `Ctrl+J`: insert a newline
- `Option+Enter`: queue a steering message while the agent is busy, delivered
  after the current assistant turn finishes its tool calls
- `Ctrl+Q` or `Option+Up`: restore queued messages to the editor
- `Escape`: Pi's existing immediate interrupt binding; it also restores queued
  messages to the editor

`Ctrl+Q` is provided because integrated terminals may intercept or incorrectly
encode `Option+Up` before Pi receives it.

The wrapper also merges `bash` into `excludeRenderers` in writable
`claude-code-style.json`. This keeps `pi-cc-extensions` from replacing Bash's
renderer, so the managed `expand-bash-command.ts` renderer owns the complete
command display. A single `Ctrl+O` then expands the full command and output
instead of opening pi-cc's separately truncated Input/Output preview, whose
second-level expansion is mouse-only in fullscreen mode.

The managed `queue-input-follow-up.ts` extension swaps Pi's two busy-input
routes: ordinary Enter submissions become follow-ups, while the explicit
Option+Enter action becomes steering. Built-in and extension commands are
dispatched before the input event, so they remain immediate; ordinary prompts,
skills, and prompt templates wait until the active task settles unless sent
with Option+Enter.

The managed `load-local-agents.ts` extension searches upward from Pi's working
directory for the Git root and appends a non-empty root `agents.local.md` or
`AGENTS.local.md` to the system prompt on every agent turn. These private local
instructions layer after Pi's standard `AGENTS.md` context, work when Pi starts
from a repository subdirectory, and are globally ignored by the managed Git
configuration.

The managed `static-working-indicator.ts` extension replaces Pi's animated
working spinner with a static dot. Cursor invalidates integrated-terminal link
decorations on each redraw, causing hovered file references and URLs to flicker
and become difficult to click while Pi is busy. Streaming text can still cause
necessary redraws, but idle thinking and tool execution no longer repaint just
to animate the spinner.

The managed `guard-invalid-slash.ts` input extension prevents accidental
submission of mistyped slash commands. In the interactive editor, input that
starts with `/` is submitted normally only when Pi recognizes the command. An
unknown command is not added to the conversation or queue, and its text stays
in the editor for correction. Normal prompts and non-interactive RPC, print,
and JSON input retain Pi's standard behavior.

## Validating Pi toolchain changes

A Nix build proves packaging, but it does not prove that a changed tool chain
works in a live Pi runtime. `/reload` is also insufficient when the change
affects wrapper environment variables, executable lookup, startup hooks, or
extension module state. The current parent process may retain stale state.

This project authorizes a bounded Playbook-tier subagent for runtime validation
when Pi tools, extensions, package wiring, or tool schemas change. After
`nix build .#pi`, use one fresh-context `delegate` child as the test operator.
The child must launch the newly built `./result/bin/pi` as a separate process,
exercise exactly one named capability, and report the result to the parent. Use
a disposable/no-session runtime where practical, and do not let the validation
child edit the implementation under test.

Give the child a narrow acceptance contract containing:

- the single behavior to test and its expected observable result;
- the exact new Pi executable/package path to exercise;
- required setup and cleanup, including terminating spawned processes;
- bounded evidence to return: tool result, completion event, relevant log tail,
  and exit/status information;
- a requirement to report failure honestly rather than infer success from
  registration, type checking, or a successful Nix build.

For asynchronous tools, validate the complete lifecycle: start, live
inspection when relevant, terminal completion, automatic wake-up/delivery, and
cleanup. Use native completion notifications or bounded wait primitives rather
than sleep-and-poll loops. The parent retains acceptance authority, applies any
fixes, and reruns the focused validation in another fresh Pi process. Keep this
test to one child and one capability unless the operator explicitly requests a
broader delegated test matrix.

## Subagent model tiers

The wrapper merges a managed `subagents.agentOverrides` block into writable
`settings.json`. Unrelated subagent settings and per-role fields are preserved,
while Nix owns the model and thinking fields listed below. Explicit per-run
model arguments still take precedence; this configuration does not impose a
`modelScope` restriction.

| Class | Roles | Model | Thinking |
| --- | --- | --- | --- |
| Monitor | `monitor` | `agent-control-plane/gpt-6-luna` | `low` |
| Playbook | `scout` | `agent-control-plane/gpt-6-luna` | `low` |
| Playbook | `delegate` | `cohere-oss-v2/deepseek-v4-1-flash` | `high` |
| Working | `worker`, `reviewer`, `researcher`, `evidence-auditor` | `agent-control-plane/gpt-6-sol` | `medium` |
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
