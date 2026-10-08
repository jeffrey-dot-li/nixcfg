// Node 24: node tests/bash-timeout.mjs [managed-resources store path]
import assert from "node:assert/strict";
import { copyFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.argv[2] ? resolve(process.argv[2]) : dirname(dirname(fileURLToPath(import.meta.url)));
const temp = mkdtempSync(join(tmpdir(), "pi-bash-timeout-test-"));
try {
  copyFileSync(join(root, "extensions/bash-timeout.ts"), join(temp, "bash-timeout.ts"));
  // Mock only SDK/TUI dependencies; exercise the unchanged registration,
  // executor wrapper and renderer against a recording native-tool stand-in.
  writeFileSync(join(temp, "sdk.mjs"), `
    export const calls = [];
    export let failure;
    export function fail(error) { failure = error; }
    export function createBashTool() {
      return {
        name: 'bash', description: 'Native Bash', promptGuidelines: ['Original guidance'],
        async execute(...args) { calls.push(args); if (failure) throw failure; return {content: [], details: {native: true}}; }
      };
    }
    export const truncateToWidth = text => text;
    export const wrapTextWithAnsi = text => [text];
  `);
  let source = readFileSync(join(root, "extensions/expand-bash-command.ts"), "utf8");
  source = source.replace('"@earendil-works/pi-coding-agent"', '"./sdk.mjs"')
    .replace('"@earendil-works/pi-tui"', '"./sdk.mjs"');
  writeFileSync(join(temp, "extension.mts"), source);
  const { default: register } = await import(pathToFileURL(join(temp, "extension.mts")).href);
  const { calls, fail } = await import(pathToFileURL(join(temp, "sdk.mjs")).href);
  let tool;
  register({ registerTool: definition => { tool = definition; } });
  const signal = new AbortController().signal;
  const update = () => {};
  const ctx = { cwd: "/some/session" };
  for (const [requested, expected] of [[undefined, 60], [120, 60], [60, 60], [10, 10], [0.1, 0.1], [0, 60], [-1, 60], [NaN, 60], [Infinity, 60]]) {
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
    const rendered = tool.renderCall(params, { fg: (_, text) => text, bold: text => text }, { expanded: true });
    assert.ok(rendered.render(200)[0].includes(`timeout ${expected}s`));
  }
  assert.ok(tool.promptGuidelines.includes("Original guidance"));
  assert.ok(tool.description.includes("task_start"));
  fail(new Error("partial output\nCommand timed out after 60 seconds"));
  await assert.rejects(tool.execute("id", { command: "sleep 90" }), /partial output.*\n.*interrupted.*partial changes/s);
  const abort = new Error("Command aborted");
  fail(abort);
  await assert.rejects(tool.execute("id", { command: "echo ok" }), error => error === abort);
  const nonzero = new Error("Command exited with code 1");
  fail(nonzero);
  await assert.rejects(tool.execute("id", { command: "false" }), error => error === nonzero);
  console.log("PASS: timeout clamping/defaults, native delegation, renderer, timeout guidance, abort and exit errors");
} finally {
  rmSync(temp, { recursive: true, force: true });
}
