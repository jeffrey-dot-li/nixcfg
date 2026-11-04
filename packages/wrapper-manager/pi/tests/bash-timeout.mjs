// Node 24: node tests/bash-timeout.mjs [managed-resources store path]
import assert from "node:assert/strict";
import { copyFileSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.argv[2] ? resolve(process.argv[2]) : dirname(dirname(fileURLToPath(import.meta.url)));
const temp = mkdtempSync(join(tmpdir(), "pi-bash-timeout-test-"));
try {
  copyFileSync(join(root, "extensions/bash-timeout.ts"), join(temp, "bash-timeout.ts"));
  writeFileSync(join(temp, "bash-background.ts"), readFileSync(join(root, "extensions/bash-background.ts"), "utf8")
    .replace('"@earendil-works/pi-coding-agent"', '"./sdk.mjs"'));
  // Mock only SDK/TUI dependencies; exercise the unchanged registration,
  // executor wrapper and renderer against a recording native-tool stand-in.
  writeFileSync(join(temp, "sdk.mjs"), `
    export const calls = [];
    export const created = [];
    export let failure;
    export let realExec = false;
    export function fail(error) { failure = error; }
    export function useRealExec(value) { realExec = value; }
    export function createBashTool(cwd, options) {
      created.push({ cwd, options });
      return {
        name: 'bash', description: 'Native Bash', promptGuidelines: ['Original guidance'],
        async execute(...args) {
          calls.push(args);
          if (failure) throw failure;
          if (realExec) {
            // Drive the wrapper's real backend, as Pi's shell tool would.
            const [, params] = args;
            let text = '';
            let exitCode;
            try {
              ({ exitCode } = await options.operations.exec(params.command, cwd, { onData: (chunk) => { text += chunk; }, timeout: params.timeout }));
            } catch (error) {
              // Mirror Pi's shell tool: timeout:<s> becomes its timeout message.
              if (error.message.startsWith('timeout:')) throw new Error(text + 'Command timed out after ' + error.message.split(':')[1] + ' seconds');
              throw error;
            }
            return {content: [{type: 'text', text: text.trim() || '(no output)'}], details: {native: true}, structuredContent: {output: text, exit_code: exitCode}};
          }
          return {content: [], details: {native: true}};
        }
      };
    }
    export const getShellConfig = () => ({ shell: '/bin/bash', args: ['-c'] });
    export const getShellEnv = () => process.env;
    export const truncateToWidth = text => text;
    export const wrapTextWithAnsi = text => [text];
  `);
  let source = readFileSync(join(root, "extensions/expand-bash-command.ts"), "utf8");
  source = source.replace('"@earendil-works/pi-coding-agent"', '"./sdk.mjs"')
    .replace('"@earendil-works/pi-tui"', '"./sdk.mjs"');
  writeFileSync(join(temp, "extension.mts"), source);
  const { default: register } = await import(pathToFileURL(join(temp, "extension.mts")).href);
  const { calls, created, fail, useRealExec } = await import(pathToFileURL(join(temp, "sdk.mjs")).href);
  let tool;
  register({ registerTool: definition => { tool = definition; } });
  const signal = new AbortController().signal;
  const update = () => {};
  const ctx = { cwd: "/some/session", sessionManager: { getSessionId: () => "session-1" } };
  // Explicit timeouts are clamped and passed on (kill semantics); omitted or
  // invalid ones pass undefined, so the backend moves the call to the background.
  for (const [requested, expected] of [[undefined, undefined], [120, 60], [60, 60], [10, 10], [0.1, 0.1], [0, undefined], [-1, undefined], [NaN, undefined], [Infinity, undefined]]) {
    const params = { command: "echo ok", ...(requested === undefined ? {} : { timeout: requested }) };
    const before = { ...params };
    const result = await tool.execute("id", params, signal, update, ctx);
    assert.equal(result.details.native, true);
    const call = calls.at(-1);
    assert.equal(call[1].timeout, expected);
    assert.equal(call[1].command, params.command);
    assert.equal(call[2], signal);
    assert.equal(call[3], update);
    assert.equal(call[4], ctx);
    assert.deepEqual(params, before, "do not mutate recorded input");
    assert.equal(created.at(-1).cwd, "/some/session", "runs in the session cwd");
    assert.equal(typeof created.at(-1).options.operations.exec, "function", "uses the backgrounding backend");
    const rendered = tool.renderCall(params, { fg: (_, text) => text, bold: text => text }, { expanded: true });
    assert.ok(rendered.render(200)[0].includes(expected === undefined ? "background after 60s" : `timeout ${expected}s`));
  }
  assert.ok(tool.promptGuidelines.includes("Original guidance"));
  assert.ok(tool.description.includes("task_start"));
  assert.ok(tool.description.includes("background task"));
  fail(new Error("partial output\nCommand timed out after 60 seconds"));
  await assert.rejects(tool.execute("id", { command: "sleep 90" }), /partial output.*\n.*interrupted.*partial changes/s);
  const abort = new Error("Command aborted");
  fail(abort);
  await assert.rejects(tool.execute("id", { command: "echo ok" }), error => error === abort);
  const nonzero = new Error("Command exited with code 1");
  fail(nonzero);
  await assert.rejects(tool.execute("id", { command: "false" }), error => error === nonzero);
  fail(undefined);

  // A real call without a timeout outlives a short threshold and is handed to
  // the (stand-in) background-task API; the result says so and records the ID.
  useRealExec(true);
  process.env.PI_BASH_BACKGROUND_AFTER_SECONDS = "0.3";
  const adopted = [];
  globalThis[Symbol.for("pi-background-task.api")] = {
    async adopt(sessionId, input) { adopted.push({ sessionId, input }); return { taskId: "bg_promoted", name: input.name }; },
  };
  const realCtx = { ...ctx, cwd: temp };
  const promoted = await tool.execute("id", { command: "echo before; sleep 1; echo after" }, signal, update, realCtx);
  assert.equal(adopted.length, 1);
  assert.equal(adopted[0].sessionId, "session-1");
  assert.equal(adopted[0].input.cwd, temp);
  assert.match(promoted.content[0].text, /^before\n\n\[Still running after 0.3s: moved to background task bg_promoted/);
  assert.match(promoted.content[0].text, /Do not rerun it/);
  assert.equal(promoted.details.backgroundTaskId, "bg_promoted");
  assert.equal(promoted.structuredContent.exit_code, -1);
  // Let the command finish and remove its hand-off files (normally the task runner does).
  const { exit, output } = adopted[0].input;
  for (let i = 0; i < 100 && !existsSync(exit); i++) await new Promise((done) => setTimeout(done, 30));
  assert.equal(JSON.parse(readFileSync(exit, "utf8")).exitCode, 0);
  rmSync(dirname(output), { recursive: true, force: true });

  // Without the API the same call is killed at the threshold, as before.
  delete globalThis[Symbol.for("pi-background-task.api")];
  await assert.rejects(
    tool.execute("id", { command: "sleep 5" }, signal, update, realCtx),
    /Command timed out after 0.3 seconds.*interrupted.*partial changes/s,
  );
  // An explicit timeout kills even with the API present.
  globalThis[Symbol.for("pi-background-task.api")] = { async adopt() { throw new Error("must not adopt"); } };
  await assert.rejects(
    tool.execute("id", { command: "sleep 5", timeout: 0.2 }, signal, update, realCtx),
    /Command timed out after 0.2 seconds/,
  );
  delete process.env.PI_BASH_BACKGROUND_AFTER_SECONDS;
  console.log("PASS: timeout clamping/defaults, native delegation, renderer, guidance, abort and exit errors, hand-off to background, fallback and explicit-timeout kill");
} finally {
  rmSync(temp, { recursive: true, force: true });
}
