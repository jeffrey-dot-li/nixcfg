# Known issue: pi-vscode fullscreen footer drawn at the top

Status: **unresolved, went away by itself** (2026-11-04). This note records what was seen and what
was ruled out, so the next investigation can pick up from here.

## Symptom

In the Pi Coding VS Code extension (`jeffrey-dot-li/pi-vscode`, local macOS VS Code 1.142), with
`piAgent.tuiMode: "inherit"` and Pi `tuiMode: "fullscreen"`, the Pi terminal pane looked
**rotated down by two rows**:

- rows 1–2: the pi-footer status lines (model / context bar, then cwd / git / MCP), which belong
  at the bottom of the dock;
- row 3: Pi's sticky prompt header (`… [click to jump]`), which belongs on row 1;
- then the transcript, and at the very bottom the editor box, with **no footer below it**.

So the whole frame was shifted down by the footer's height (2 rows), and the footer wrapped to
the top. It was not the status bar being placed at the top on purpose.

It persisted across `/reload` and across closing and reopening the session from the list (a new
Pi process). Some time later it was gone. The likely trigger was a pane resize, but that was not
confirmed.

## Timeline

- pi 0.85.1 → 1.5.0 plus package bumps (pi-footer 0.1.4 → 0.1.6, pi-cc-extensions 0.8.71 → 1.0.14,
  …): rendering was **normal**.
- `nix switch` with pi-vscode `8ee6358` ("Session list: opened sessions (pinnable) by default"):
  the symptom **appeared**. That commit touches only the session list, the persisted opened list
  and when sessions start. It does not touch `native-terminal.ts`, `terminal-replay.ts` or the
  resize code. Its one runtime change is that **sessions now start on click**, attached to an
  already open Pi terminal editor, instead of starting in the background at window open.

## Ruled out

- **Pi 1.5's own layout.** In a plain terminal (detached tmux pane, fullscreen) the footer is at
  the bottom.
- **pi-footer 0.1.6.** Its diff from 0.1.4 only adds a `footer.separator` option and renames the
  repo. It still uses `ctx.ui.setFooter()`. No positioning change.
- **Pi's output stream.** The raw fullscreen output uses only absolute positioning: CUP
  (`CSI r;c H`), EL (`CSI K`), ED (`CSI J`), `?1049h`, `?7l` (autowrap off), `?2026` synchronized
  output, mouse modes. There are no scroll regions (DECSTBM), scroll up/down (SU/SD), reverse index
  or relative newline layout, so Pi itself cannot rotate the frame.
- **Size mismatch.** The session's pty was 56×97 (`stty -F /dev/<pi tty> size`; find the tty with
  `ps -o tty= -p <pi pid>`). That matches the rows visible in the pane.
- **The extension's replay and attach path, emulated headless.** node-pty plus the extension's
  `TerminalReplay` plus `@xterm/headless`, with a "VS Code" terminal fed exactly what
  `PiPseudoterminal.restore()` sends: `ESC c ESC[3J` + snapshot, then output with
  sequence > snapshot.sequence. The session started at 80×24 and was attached immediately and
  150 ms after spawn at the pane size. Runs used a copy of a long session, a prompt wrapping to
  several editor rows, and resizes 44 → 42 → 40 rows. In every case the attached screen matched
  Pi's own screen row for row (0 differing rows).

What remains is something that only happens in **VS Code's real terminal**: the xterm.js
renderer, its resize and reflow timing, or how the terminal editor reports dimensions while the
editor group is being created on first click.

## Next steps if it comes back

1. **Plain VS Code terminal:** run `pi --tui-mode fullscreen` in a normal integrated terminal.
   If the footer moves to the top there too, it is VS Code + pi 1.5, not the extension.
2. **New session:** press ⌘⇧B and send one prompt. Is it wrong from the first frame, or does it
   go wrong later (after a resize, after switching sessions, after focusing the pane)?
3. **Resize:** drag the pane edge. A resize makes Pi redraw the whole screen at the new size. If
   it stays rotated after that, VS Code is applying something Pi does not see.
4. **Compare dimensions:** `stty -F /dev/<pi tty> size` against the rows actually visible.
5. **Capture bytes.** If 1–4 point at the extension, add an opt-in debug mode to pi-vscode that
   appends (a) raw pty output with sequence numbers and (b) every `writeEmitter.fire()` payload,
   plus `open` and `setDimensions` sizes, to files. Replay (b) into `@xterm/headless` at the
   reported size to find the sequence that rotates the frame.

## Probe used

Run from a pi-vscode checkout after `npm ci --ignore-scripts && npm run compile`:

```sh
PI_BIN=$(readlink -f $(which pi)) PI_ARGS="--session /tmp/copy.jsonl --tui-mode fullscreen" \
  ATTACH=0 C=100 R=40 TYPE="a prompt long enough to wrap" node attach-probe.cjs
```

```js
// attach-probe.cjs: mimics PiPseudoterminal attach and replay; prints rows that differ
// between Pi's own screen and the "VS Code" terminal.
const pty = require(process.cwd() + "/node_modules/node-pty");
const { TerminalReplay } = require(process.cwd() + "/out/terminal-replay.js");
const { Terminal } = require(process.cwd() + "/node_modules/@xterm/headless");
const [C, R] = [Number(process.env.C || 100), Number(process.env.R || 40)];
const attachAt = Number(process.env.ATTACH || 0);
const replay = new TerminalReplay(80, 24, 1000);
const live = new Terminal({ cols: 80, rows: 24, allowProposedApi: true });
const vs = new Terminal({ cols: C, rows: R, allowProposedApi: true });
const pending = []; let opened = false;
const p = pty.spawn(process.env.PI_BIN, process.env.PI_ARGS.split(" "), { cols: 80, rows: 24, cwd: "/tmp", env: process.env });
p.onData((d) => { const seq = replay.write(d); live.write(d); if (opened) vs.write(d); else pending.push([seq, d]); });
setTimeout(async () => {
  p.resize(C, R); replay.resize(C, R); live.resize(C, R);
  const snap = await replay.snapshot();
  vs.write("\x1bc\x1b[3J" + snap.data); opened = true;
  for (const [seq, d] of pending.splice(0)) if (seq > snap.sequence) vs.write(d);
}, attachAt);
setTimeout(() => { if (process.env.TYPE) p.write(process.env.TYPE); }, attachAt + 3000);
setTimeout(() => live.write("", () => vs.write("", () => {
  const rows = (t) => Array.from({ length: t.rows }, (_, i) => t.buffer.active.getLine(t.buffer.active.viewportY + i)?.translateToString(true) ?? "");
  const a = rows(live), v = rows(vs); let n = 0;
  a.forEach((row, i) => { if (row !== v[i]) { n++; console.log(`row ${i}\n  pi: ${row}\n  vs: ${v[i]}`); } });
  console.log(`DIFFERING ROWS: ${n}`); p.kill(); process.exit(0);
})), attachAt + 6000);
```

Use a **copy** of a session file (`cp "$PI_SESSION_FILE" /tmp/copy.jsonl`) so the probe does
not append to a real session.
