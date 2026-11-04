// node tests/background-task-adopt.mjs <patched pi-background-task store path>
// Integration test for the adopt patch: a real TaskRegistry (tmux backend) takes
// over a process this script started, the way the bash tool hands one off.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createWriteStream, existsSync, mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const source = resolve(process.argv[2] ?? "");
if (!existsSync(join(source, "dist/adopted-runner.js"))) throw new Error(`not a patched pi-background-task: ${source}`);
const state = mkdtempSync(join(tmpdir(), "pi-bg-adopt-test-"));
process.env.PI_BACKGROUND_TASK_STATE_DIR = join(state, "state");
// Load registry.js directly (it needs no Pi packages). index.js imports Pi's
// TUI and SDK packages, so its branchTaskIds is evaluated from source below.
const pkg = source;
const { TaskRegistry } = await import(pathToFileURL(join(pkg, "dist/registry.js")).href);
const indexSource = readFileSync(join(pkg, "dist/index.js"), "utf8");
const branchTaskIdsSource = /export function branchTaskIds[\s\S]*?\n}\n/.exec(indexSource)?.[0];
assert.ok(branchTaskIdsSource, "branchTaskIds found in index.js");
const branchTaskIds = new Function(`${branchTaskIdsSource.replace("export ", "")}; return branchTaskIds;`)();
const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

/** Start a command as the bash backend does and return its hand-off files. */
function startCommand(command) {
  const dir = mkdtempSync(join(tmpdir(), "pi-bash-"));
  const output = join(dir, "output");
  const exit = join(dir, "exit.json");
  const sink = createWriteStream(output, { flags: "a" });
  const child = spawn("/bin/bash", ["-c", command], { detached: true, stdio: ["ignore", "pipe", "pipe"] });
  child.stdout.on("data", (chunk) => sink.write(chunk));
  child.stderr.on("data", (chunk) => sink.write(chunk));
  child.once("close", (code, signal) => sink.end(() => {
    writeFileSync(`${exit}.tmp`, JSON.stringify({ exitCode: code, signal }));
    renameSync(`${exit}.tmp`, exit);
  }));
  return { child, dir, output, exit };
}

const registry = new TaskRegistry(join(state, "project"), "run_adopt_test", join(pkg, "dist/runner.js"), "session-1", () => new Set());
const completions = [];
registry.on("completion", (task) => completions.push(task));
try {
  await registry.initialize();

  // 1. Hand-off mid-run: output from before and after the hand-off lands in the
  //    task log, and the real exit status becomes the task result.
  const run = startCommand("echo before; sleep 1.5; echo after; exit 7");
  await sleep(300);
  const task = await registry.adopt({
    pid: run.child.pid, command: "demo", name: "demo", cwd: state,
    output: run.output, exit: run.exit, startedAt: new Date().toISOString(), notifyOnCompletion: true,
  });
  assert.equal(task.status, "running");
  assert.ok(task.logPath.startsWith(state), "state stays in the test directory");
  assert.ok((await registry.list("session")).some((t) => t.taskId === task.taskId), "visible in the starting session");
  const waited = await registry.wait([task.taskId], "all", 10);
  const done = waited.completed[0];
  assert.equal(done.status, "failed");
  assert.equal(done.exitCode, 7);
  const log = (await registry.logs(task.taskId, 0, 64 * 1024)).text.replace(/\r/g, "");
  assert.match(log, /before\nafter\n/);
  await sleep(200);
  assert.ok(!existsSync(run.dir), "hand-off directory removed after completion");
  assert.ok(completions.some((t) => t.taskId === task.taskId), "completion event emitted");
  await assert.rejects(registry.send(task.taskId, { text: "x" }), /not running|no terminal input/);

  // 2. task_kill on an adopted task stops the command's whole process group.
  const long = startCommand("echo $$; sleep 60 & wait");
  await sleep(200);
  const pid = long.child.pid;
  const killable = await registry.adopt({
    pid, command: "long", name: "long", cwd: state,
    output: long.output, exit: long.exit, startedAt: new Date().toISOString(), notifyOnCompletion: true,
  });
  await assert.rejects(registry.send(killable.taskId, { text: "x" }), /no terminal input/);
  const killed = await registry.terminate(killable.taskId);
  assert.equal(killed.status, "cancelled", JSON.stringify(killed));
  await sleep(300);
  assert.throws(() => process.kill(-pid, 0), { code: "ESRCH" }, "process group is gone");

  // 3. A successful hand-off completes normally.
  const ok = startCommand("sleep 0.5; echo fine");
  const adoptedOk = await registry.adopt({
    pid: ok.child.pid, command: "ok", name: "ok", cwd: state,
    output: ok.output, exit: ok.exit, startedAt: new Date().toISOString(), notifyOnCompletion: true,
  });
  const okDone = (await registry.wait([adoptedOk.taskId], "all", 10)).completed[0];
  assert.equal(okDone.status, "completed");
  assert.equal(okDone.exitCode, 0);

  // 4. Branch visibility: a bash tool result carrying backgroundTaskId counts,
  //    like a task_start result.
  const ids = branchTaskIds({ getBranch: () => [
    { type: "message", message: { role: "toolResult", toolName: "bash", details: { backgroundTaskId: "bg_a" } } },
    { type: "message", message: { role: "toolResult", toolName: "bash", details: {} } },
    { type: "message", message: { role: "toolResult", toolName: "task_start", details: { taskId: "bg_b" } } },
  ] });
  assert.deepEqual([...ids].sort(), ["bg_a", "bg_b"]);

  console.log("PASS: adopt mid-run (full log, exit status, cleanup, completion event, no input), kill stops the group, success, branch visibility");
} finally {
  await registry.shutdown(true).catch(() => undefined);
  rmSync(state, { recursive: true, force: true });
}
