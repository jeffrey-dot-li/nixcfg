// Node 24: node tests/bash-background.mjs [managed-resources store path]
// Exercises the backgrounding Bash backend against real processes with a short
// threshold and a recording adopt() stand-in (no Pi or tmux needed).
import assert from "node:assert/strict";
import { copyFileSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.argv[2] ? resolve(process.argv[2]) : dirname(dirname(fileURLToPath(import.meta.url)));
const temp = mkdtempSync(join(tmpdir(), "pi-bash-background-test-"));
const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
const alive = (pid) => {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
};
async function until(check, timeoutMs, what) {
  const deadline = Date.now() + timeoutMs;
  while (!check()) {
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${what}`);
    await sleep(20);
  }
}

try {
  writeFileSync(join(temp, "sdk.mjs"), `
    export const getShellConfig = () => ({ shell: "/bin/bash", args: ["-c"] });
    export const getShellEnv = () => process.env;
  `);
  const source = readFileSync(join(root, "extensions/bash-background.ts"), "utf8")
    .replace('"@earendil-works/pi-coding-agent"', '"./sdk.mjs"');
  writeFileSync(join(temp, "bash-background.mts"), source);
  const { createBackgroundingOperations, backgroundAfterSeconds } = await import(
    pathToFileURL(join(temp, "bash-background.mts")).href
  );

  assert.equal(backgroundAfterSeconds({}), 60);
  assert.equal(backgroundAfterSeconds({ PI_BASH_BACKGROUND_AFTER_SECONDS: "2.5" }), 2.5);
  assert.equal(backgroundAfterSeconds({ PI_BASH_BACKGROUND_AFTER_SECONDS: "nope" }), 60);

  const make = (adopt) => {
    const state = { adopted: [], promotions: [] };
    const ops = createBackgroundingOperations({
      afterSeconds: 0.5,
      adopt: adopt === null ? undefined : async (input) => {
        state.adopted.push(input);
        return adopt ? adopt(input) : { taskId: "bg_test", name: input.name };
      },
      onPromoted: (promotion) => state.promotions.push(promotion),
      name: (command) => command.slice(0, 20),
    });
    return { ops, state };
  };
  const collect = () => {
    const chunks = [];
    return { onData: (chunk) => chunks.push(chunk), text: () => Buffer.concat(chunks).toString() };
  };

  // 1. A fast command behaves like plain Bash and leaves nothing behind.
  {
    const { ops, state } = make();
    const out = collect();
    const result = await ops.exec("echo hi; echo err >&2; exit 4", temp, { onData: out.onData });
    assert.equal(result.exitCode, 4);
    assert.equal(out.text(), "hi\nerr\n");
    assert.equal(state.adopted.length, 0);
    assert.equal(state.promotions.length, 0);
  }

  // 2. A slow command is handed off at the threshold, keeps running, and reports
  //    its real exit status and complete output through the files it was given.
  {
    const { ops, state } = make();
    const out = collect();
    const started = Date.now();
    const result = await ops.exec("echo start; sleep 1.5; echo end; exit 3", temp, { onData: out.onData });
    const elapsed = Date.now() - started;
    assert.equal(result.exitCode, 0, "the tool call returns once handed off");
    assert.ok(elapsed >= 450 && elapsed < 1400, `returned after ${elapsed}ms`);
    assert.equal(out.text(), "start\n", "only pre-hand-off output reaches the tool call");
    assert.equal(state.promotions.length, 1);
    assert.deepEqual(state.promotions[0], { taskId: "bg_test", name: "echo start; sleep 1.", afterSeconds: 0.5 });
    const [input] = state.adopted;
    assert.ok(alive(input.pid), "command still running after the hand-off");
    assert.equal(input.notifyOnCompletion, true);
    assert.equal(input.cwd, temp);
    await until(() => existsSync(input.exit), 5000, "exit status file");
    assert.deepEqual(JSON.parse(readFileSync(input.exit, "utf8")), { exitCode: 3, signal: null });
    assert.equal(readFileSync(input.output, "utf8"), "start\nend\n", "output file holds the full stream");
    rmSync(dirname(input.output), { recursive: true, force: true });
  }

  // 3. An explicit timeout still kills (the whole process group).
  {
    const { ops, state } = make();
    const out = collect();
    await assert.rejects(ops.exec("echo $$; sleep 30", temp, { onData: out.onData, timeout: 0.4 }), /^Error: timeout:0.4$/);
    const pid = Number(out.text().trim());
    await until(() => !alive(pid), 2000, "killed shell");
    assert.equal(state.adopted.length, 0);
  }

  // 4. Without pi-background-task (or if the hand-off fails) the call is killed
  //    at the threshold, as before.
  for (const adopt of [null, () => { throw new Error("no runtime"); }]) {
    const { ops } = make(adopt);
    const out = collect();
    await assert.rejects(ops.exec("echo $$; sleep 30", temp, { onData: out.onData }), /^Error: timeout:0.5$/);
    const pid = Number(out.text().trim());
    await until(() => !alive(pid), 2000, "killed shell");
  }

  // 5. Aborting before the hand-off kills the command.
  {
    const { ops, state } = make();
    const out = collect();
    const controller = new AbortController();
    const run = ops.exec("echo $$; sleep 30", temp, { onData: out.onData, signal: controller.signal });
    await until(() => out.text().trim(), 2000, "pid output");
    controller.abort();
    await assert.rejects(run, /^Error: aborted$/);
    await until(() => !alive(Number(out.text().trim())), 2000, "killed shell");
    assert.equal(state.adopted.length, 0);
  }

  // 6. If the command exits while the hand-off is in flight, the task still gets
  //    its exit status (it then completes immediately).
  {
    const { ops, state } = make(async (input) => {
      await sleep(600);
      return { taskId: "bg_race", name: input.name };
    });
    const result = await ops.exec("sleep 0.7; exit 5", temp, { onData: () => {} });
    assert.equal(result.exitCode, 0);
    assert.equal(state.promotions[0].taskId, "bg_race");
    const [input] = state.adopted;
    await until(() => existsSync(input.exit), 3000, "exit status file");
    assert.equal(JSON.parse(readFileSync(input.exit, "utf8")).exitCode, 5);
    rmSync(dirname(input.output), { recursive: true, force: true });
  }

  console.log("PASS: fast commands, hand-off at threshold with full output and exit status, explicit timeout kill, fallback kill, abort, exit during hand-off");
} finally {
  rmSync(temp, { recursive: true, force: true });
}
