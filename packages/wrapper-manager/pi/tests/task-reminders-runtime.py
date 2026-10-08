"""Run: python3 tests/task-reminders-runtime.py <patched-bg-package> <pi-binary>
Uses isolated config/state and real tmux tasks. Notifications are captured
instead of triggering a model request; no credentials or model calls needed.
"""
import json
import uuid
from datetime import datetime, timezone
import os
from pathlib import Path
import queue
import subprocess
import sys
import tempfile
import threading
import time

package = Path(sys.argv[1]).resolve()
binary = Path(sys.argv[2]).resolve()
fixture_source = '''
import assert from "node:assert/strict";
import backgroundTasks from PACKAGE_IMPORT;

export default function(pi) {
    const tools = new Map();
    const notifications = [];
    let ui;
    const wrapped = new Proxy(pi, {
        get(target, key) {
            if (key === "registerTool") return (definition) => {
                tools.set(definition.name, definition);
                target.registerTool(definition);
            };
            if (key === "sendMessage") return (message, options) => {
                notifications.push({ message, options });
                ui?.notify(`CAPTURE ${message.customType}: ${JSON.stringify(message.details)}`, "info");
            };
            return Reflect.get(target, key);
        },
    });
    backgroundTasks(wrapped);
    pi.on("session_start", async (_event, ctx) => { ui = ctx.ui; });
    pi.registerCommand("test-reminder-start", {
        description: "Start isolated reminder smoke test",
        handler: async (_args, ctx) => {
            const call = (name, args) => tools.get(name).execute("test", args, undefined, undefined, ctx);
            const slow = (await call("task_start", { command: "sleep 8", name: "Slow reminder test", timeoutSeconds: 20 })).details;
            const quick = (await call("task_start", { command: "sleep 0.3", name: "Quick cancellation test", timeoutSeconds: 20 })).details;
            const first = await call("task_reminder", { taskId: slow.taskId, afterSeconds: 2, message: "Inspect slow task" });
            const second = await call("task_reminder", { taskId: quick.taskId, afterSeconds: 3, message: "Should cancel" });
            const third = await call("task_reminder", { taskId: quick.taskId, afterSeconds: 3, message: "Inspect even after completion", cancelOnCompletion: false });
            assert.equal(first.details.state, "pending");
            assert.ok(["pending", "cancelled"].includes(second.details.state));
            assert.equal(third.details.state, "pending");
            const cancelled = await call("task_reminder", { taskId: slow.taskId, afterSeconds: 5, message: "Manual cancellation" });
            await call("task_reminder", { action: "cancel", reminderId: cancelled.details.reminderId });
            assert.ok((await call("task_reminder", { action: "list" })).details.reminders.length >= 2);
            ui.notify("SCHEDULED", "info");
        },
    });
    pi.registerCommand("test-reminder-cleanup", {
        description: "Stop an isolated fixture task before removing temporary state",
        handler: async (args, ctx) => {
            await tools.get("task_kill").execute("cleanup", { taskId: args.trim() }, undefined, undefined, ctx);
        },
    });
    pi.registerCommand("test-reminder-reload", {
        description: "Reload the fixture and restore pending reminder timers",
        handler: async (_args, ctx) => { await ctx.reload(); },
    });
    pi.registerCommand("test-reminder-validate", {
        description: "Validate one-shot notifications",
        handler: async (_args, ctx) => {
            const reminders = notifications.filter(n => n.message.customType === "pi-background-task:reminder");
            assert.equal(reminders.length, 2);
            assert.ok(reminders.some(n => n.message.content.includes("Inspect slow task")));
            assert.ok(reminders.some(n => n.message.content.includes("Inspect even after completion")));
            assert.ok(!reminders.some(n => n.message.content.includes("Should cancel")));
            for (const n of reminders) assert.deepEqual(n.options, { triggerTurn: true, deliverAs: "followUp" });
            const pending = await tools.get("task_reminder").execute("list", { action: "list" }, undefined, undefined, ctx);
            assert.equal(pending.details.reminders.length, 0);
            ui.notify("PASS: native reminder tools, real tasks, completion/manual cancellation and one-shot follow-up delivery", "info");
        },
    });
}
'''

with tempfile.TemporaryDirectory(prefix="pi-reminder-runtime-") as temp:
    temp = Path(temp)
    config, cwd, state = [temp / name for name in ("config", "cwd", "state")]
    for path in (config, cwd, state):
        path.mkdir()
    session_file = temp / "session.jsonl"
    timestamp = datetime.now(timezone.utc).isoformat()
    # Seed an assistant entry so Pi flushes subsequent custom entries to disk,
    # without making a model call just to create a persisted session.
    seed = [
        {"type": "session", "version": 3, "id": str(uuid.uuid4()), "timestamp": timestamp, "cwd": str(cwd)},
        {"type": "message", "id": "seed0001", "parentId": None, "timestamp": timestamp, "message": {
            "role": "assistant", "content": [{"type": "text", "text": "Fixture seed"}],
            "api": "openai-responses", "provider": "openai", "model": "fixture",
            "usage": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0, "totalTokens": 0,
                      "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0, "total": 0}},
            "stopReason": "stop", "timestamp": int(time.time() * 1000),
        }},
    ]
    session_file.write_text("".join(json.dumps(entry) + "\n" for entry in seed))
    fixture = temp / "fixture.ts"
    fixture.write_text(fixture_source.replace("PACKAGE_IMPORT", json.dumps(str(package / "dist/index.js"))))
    env = {**os.environ, "PI_CODING_AGENT_DIR": str(config), "PI_BACKGROUND_TASK_STATE_DIR": str(state)}
    proc = subprocess.Popen([str(binary), "--mode", "rpc", "--session", str(session_file), "--no-extensions", "--no-skills", "--no-context-files", "-e", str(fixture)], cwd=cwd, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    events = queue.Queue()
    observed = []

    def read_events():
        for line in proc.stdout:
            try:
                events.put(json.loads(line))
            except ValueError:
                events.put({"invalid": line})
        events.put({"eof": True})

    threading.Thread(target=read_events, daemon=True).start()

    def send(payload):
        proc.stdin.write(json.dumps(payload) + "\n")
        proc.stdin.flush()

    def until(predicate, seconds=15):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            event = events.get(timeout=max(0.01, deadline - time.monotonic()))
            observed.append(event)
            if event.get("eof") or event.get("type") == "extension_error":
                raise AssertionError(event)
            if event.get("method") == "notify":
                print(event["message"], flush=True)
            if predicate(event):
                return event
        raise TimeoutError("Pi did not respond")

    try:
        send({"type": "get_commands", "id": "commands"})
        commands = until(lambda e: e.get("id") == "commands")
        assert any(c["name"] == "bg-reminders" for c in commands["data"]["commands"])
        send({"type": "prompt", "message": "/test-reminder-start", "id": "start"})
        assert until(lambda e: e.get("id") == "start")["success"]
        # A normal request can be answered while timers are pending; no wait tool.
        started = time.monotonic()
        send({"type": "get_state", "id": "responsive"})
        assert until(lambda e: e.get("id") == "responsive")["success"]
        assert time.monotonic() - started < 1
        send({"type": "prompt", "message": "/test-reminder-reload", "id": "reload"})
        assert until(lambda e: e.get("id") == "reload")["success"]
        count = lambda: sum(e.get("method") == "notify" and e.get("message", "").startswith("CAPTURE pi-background-task:reminder:") for e in observed)
        until(lambda _: count() >= 2)
        send({"type": "prompt", "message": "/test-reminder-validate", "id": "validate"})
        assert until(lambda e: e.get("id") == "validate")["success"]
        assert any(e.get("message", "").startswith("PASS:") for e in observed)
        captured = next(e["message"] for e in observed if e.get("message", "").startswith("CAPTURE pi-background-task:reminder:"))
        task_id = json.loads(captured.split(": ", 1)[1])["taskId"]
        send({"type": "prompt", "message": "/test-reminder-cleanup " + task_id, "id": "cleanup"})
        assert until(lambda e: e.get("id") == "cleanup")["success"]
        records = {}
        for line in session_file.read_text().splitlines():
            entry = json.loads(line)
            if entry.get("customType") == "pi-background-task:reminder-state":
                records[entry["data"]["reminderId"]] = entry["data"]
        assert sum(r["state"] == "notified" for r in records.values()) == 2
        assert sum(r["state"] == "cancelled" for r in records.values()) == 2
        print("PASS: Pi stays responsive; reload restores deadlines; reminder states persist to disk", flush=True)
    finally:
        proc.terminate()
        proc.wait(timeout=10)
        stderr = proc.stderr.read()
        if stderr:
            print("STDERR:", stderr, flush=True)
            raise AssertionError("Unexpected Pi stderr during runtime test")
