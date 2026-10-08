// Node 24: node tests/universal-agents.mjs [managed-resources store path]
import assert from "node:assert/strict";
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const source = process.argv[2]
  ? resolve(process.argv[2])
  : dirname(dirname(fileURLToPath(import.meta.url)));
const temp = mkdtempSync(join(tmpdir(), "pi-universal-agents-test-"));
const cwd = process.cwd();
try {
  const extensionDir = join(temp, "package", "extensions");
  mkdirSync(extensionDir, { recursive: true });
  const modulePath = join(extensionDir, "load-universal-agents.mts");
  copyFileSync(join(source, "extensions", "load-universal-agents.ts"), modulePath);
  const rulesPath = join(temp, "package", "AGENTS.md");
  // The built package must ship the actual rules alongside its extension.
  assert.ok(readFileSync(join(source, "AGENTS.md"), "utf8").includes("Universal Pi defaults"));
  writeFileSync(rulesPath, "# Universal defaults\nKeep answers concise.\n");
  const machinePath = join(temp, "AGENTS.md");
  writeFileSync(machinePath, "# Machine rules\nUse VM-specific settings.\n");
  const machineBefore = readFileSync(machinePath, "utf8");
  process.chdir(temp); // Unrelated cwd with its own AGENTS.md.

  const { default: register } = await import(pathToFileURL(modulePath).href);
  function instance() {
    const events = new Map();
    register({ on: (name, callback) => events.set(name, callback) });
    return events;
  }
  const events = instance();
  const existing = "Pi core prompt\nMachine rules\nProject rules\nOther extension instructions";
  await events.get("session_start")({ reason: "startup" });
  const result = await events.get("before_agent_start")({ systemPrompt: existing });
  assert.ok(result.systemPrompt.endsWith(existing), "preserve the entire existing prompt");
  assert.ok(result.systemPrompt.startsWith("Universal Pi defaults"));
  assert.ok(result.systemPrompt.includes("Keep answers concise."));
  assert.equal(readFileSync(machinePath, "utf8"), machineBefore, "machine-local file untouched");
  assert.deepEqual(await events.get("before_agent_start")({ systemPrompt: existing }), result, "no cumulative injection");

  writeFileSync(rulesPath, "# Updated defaults\nUse the new rules.\n");
  assert.deepEqual(await events.get("before_agent_start")({ systemPrompt: existing }), result, "cache rules until session startup/reload");
  await events.get("session_start")({ reason: "reload" });
  const refreshed = await events.get("before_agent_start")({ systemPrompt: existing });
  assert.ok(refreshed.systemPrompt.includes("Use the new rules."));
  assert.ok(!refreshed.systemPrompt.includes("Keep answers concise."));

  const fallback = await instance().get("before_agent_start")({ systemPrompt: existing });
  assert.deepEqual(fallback, refreshed, "fallback before startup");
  writeFileSync(rulesPath, " \n ");
  await events.get("session_start")({ reason: "resume" });
  assert.equal(await events.get("before_agent_start")({ systemPrompt: existing }), undefined, "empty rules are a no-op");
  console.log("PASS: package-relative rules, layering, cache/reload, empty file, and untouched machine rules");
} finally {
  process.chdir(cwd);
  rmSync(temp, { recursive: true, force: true });
}
