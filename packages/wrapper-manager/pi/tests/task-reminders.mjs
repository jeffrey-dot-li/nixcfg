// Node 24: node tests/task-reminders.mjs [pi-background-task store path]
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const modulePath = process.argv[2] ? join(resolve(process.argv[2]), "dist/reminders.js") : join(root, "background-task/reminders.js");
const { TaskReminders, REMINDER_ENTRY, REMINDER_MESSAGE } = await import(pathToFileURL(modulePath));

function fixture() {
    let now = 1000000;
    let entries = [];
    let sessionId = "session-a";
    const timers = new Map();
    const messages = [];
    const tasks = new Map([["bg_a", { name: "Build", status: "running", owned: true, result: undefined }]]);
    const visible = new Set(["bg_a"]);
    const registry = new EventEmitter();
    registry.resolve = async (id) => {
        const task = tasks.get(id);
        if (!task) throw new Error("Task not found");
        return { meta: { name: task.name, status: task.status }, paths: { id }, owned: task.owned };
    };
    registry.isVisibleInCurrentBranch = id => visible.has(id);
    registry.store = { readResult: async paths => tasks.get(paths.id)?.result };
    for (const method of ["get", "start", "terminate", "send", "kill"]) {
        registry[method] = () => { throw new Error(`Reminder must not call ${method}`); };
    }
    const sessionManager = { getSessionId: () => sessionId, getBranch: () => entries };
    const pi = {
        appendEntry(type, data) { entries.push({ type: "custom", customType: type, data: structuredClone(data) }); },
        sendMessage(message, options) { messages.push({ message, options }); },
    };
    const clock = {
        now: () => now,
        setTimeout(callback, delay) { const timer = { unref() {} }; timers.set(timer, { callback, at: now + delay }); return timer; },
        clearTimeout(timer) { timers.delete(timer); },
    };
    let manager = new TaskReminders(pi, registry, sessionManager, clock);
    return {
        get manager() { return manager; }, registry, sessionManager, tasks, visible, messages, timers,
        get entries() { return entries; }, set entries(value) { entries = value; },
        set sessionId(value) { sessionId = value; },
        async refresh() { await manager.refresh(); },
        async schedule(extra = {}) { return manager.schedule({ taskId: "bg_a", afterSeconds: 300, message: "Check progress", ...extra }, { sessionManager }); },
        async tick(ms) {
            now += ms;
            for (let limit = 0; limit < 100; limit++) {
                const due = [...timers].find(([, timer]) => timer.at <= now);
                if (!due) break;
                timers.delete(due[0]); due[1].callback();
                await manager.queue; await Promise.resolve();
            }
            await manager.queue;
        },
        restart() { manager.dispose(); manager = new TaskReminders(pi, registry, sessionManager, clock); },
    };
}

// Scheduling returns immediately, makes no task mutations, and emits exactly one follow-up.
{
    const f = fixture(); await f.refresh();
    const taskBefore = structuredClone(f.tasks.get("bg_a"));
    const reminder = await f.schedule();
    assert.equal(reminder.state, "pending");
    assert.equal(reminder.dueAt, 1300000);
    assert.equal(reminder.cancelOnCompletion, true);
    assert.equal((await f.manager.list()).length, 1);
    assert.equal(f.messages.length, 0);
    await f.tick(299999); assert.equal(f.messages.length, 0);
    await f.tick(1); assert.equal(f.messages.length, 1);
    assert.equal(f.messages[0].message.customType, REMINDER_MESSAGE);
    assert.ok(f.messages[0].message.content.includes("Check progress"));
    assert.deepEqual(f.messages[0].options, { triggerTurn: true, deliverAs: "followUp" });
    assert.equal((await f.manager.list()).length, 0);
    await f.tick(1000000); assert.equal(f.messages.length, 1);
    assert.deepEqual(f.tasks.get("bg_a"), taskBefore);
    f.restart(); await f.refresh(); await f.tick(0);
    assert.equal(f.messages.length, 1, "notified marker prevents replay duplicates");
    f.manager.dispose();
}
// Completion cancels only the alarm, including if no completion event was observed.
for (const emit of [true, false]) {
    const f = fixture(); await f.refresh(); await f.schedule();
    f.tasks.get("bg_a").result = { status: "completed", exitCode: 0 };
    if (emit) { f.registry.emit("completion", { taskId: "bg_a", status: "completed" }); await f.manager.queue; }
    await f.tick(300000);
    assert.equal(f.messages.length, 0);
    assert.equal(f.timers.size, 0);
    assert.equal(f.entries.at(-1).data.state, "cancelled");
    assert.equal(f.tasks.get("bg_a").result.status, "completed");
    f.manager.dispose();
}
// Explicit cancel and opting out of cancellation.
{
    const f = fixture(); await f.refresh();
    const first = await f.schedule(); await f.manager.cancel(first.reminderId);
    await f.tick(300000); assert.equal(f.messages.length, 0);
    await assert.rejects(f.manager.cancel(first.reminderId), /not found/);
    f.tasks.get("bg_a").result = { status: "failed" };
    const finished = await f.schedule(); assert.equal(finished.state, "cancelled");
    await f.schedule({ cancelOnCompletion: false });
    f.registry.emit("completion", { taskId: "bg_a", status: "failed" });
    await f.tick(300000); assert.equal(f.messages.length, 1);
    assert.ok(f.messages[0].message.content.includes("failed"));
    f.manager.dispose();
}
// Reload/resume preserve absolute due times; overdue reminders fire once on return.
{
    const f = fixture(); await f.refresh(); await f.schedule();
    await f.tick(100000); f.restart(); await f.refresh();
    await f.tick(199999); assert.equal(f.messages.length, 0);
    await f.tick(1); assert.equal(f.messages.length, 1);
    f.manager.dispose();
}
{
    const f = fixture(); await f.refresh(); await f.schedule();
    const branch = structuredClone(f.entries);
    f.entries = []; await f.refresh(); await f.tick(400000);
    assert.equal(f.messages.length, 0, "no reminder on another branch");
    f.entries = branch; await f.refresh(); await f.tick(0);
    assert.equal(f.messages.length, 1, "overdue reminder on restored branch");
    f.manager.dispose();
}
// Forked/new sessions do not inherit alarms; the original session can resume them.
{
    const f = fixture(); await f.refresh(); await f.schedule();
    f.manager.dispose(); f.sessionId = "session-b"; f.restart(); await f.refresh(); await f.tick(400000);
    assert.equal(f.messages.length, 0);
    assert.equal((await f.manager.list()).length, 0);
    f.sessionId = "session-a"; f.restart(); await f.refresh(); await f.tick(0);
    assert.equal(f.messages.length, 1);
    f.manager.dispose();
}
// Missing task records prompt inspection, not mutation or silent loss.
{
    const f = fixture(); await f.refresh(); await f.schedule(); f.tasks.clear();
    await f.tick(300000);
    assert.equal(f.messages.length, 1);
    assert.ok(f.messages[0].message.content.includes("task record unavailable"));
    f.manager.dispose();
}
// Invalid schedules, foreign task/session ownership, and limits.
{
    const f = fixture(); await f.refresh();
    for (const afterSeconds of [0, -1, 1.5, NaN, 604801]) await assert.rejects(f.schedule({ afterSeconds }), /afterSeconds/);
    await assert.rejects(f.schedule({ message: "  " }), /message/);
    await assert.rejects(f.schedule({ message: "x".repeat(4001) }), /message/);
    await assert.rejects(f.schedule({ cancelOnCompletion: "yes" }), /boolean/);
    f.tasks.get("bg_a").owned = false; await assert.rejects(f.schedule(), /another Pi instance/);
    f.tasks.get("bg_a").owned = true;
    f.visible.clear(); await assert.rejects(f.schedule(), /not visible/); f.visible.add("bg_a");
    await assert.rejects(f.manager.schedule({ taskId: "bg_a", afterSeconds: 1, message: "check" }, { sessionManager: { getSessionId: () => "other" } }), /another session/);
    for (let i = 0; i < 100; i++) await f.schedule();
    await assert.rejects(f.schedule(), /At most 100/);
    f.manager.dispose(); assert.equal(f.timers.size, 0); assert.equal(f.registry.listenerCount("completion"), 0);
}
// Disposal while a file read is in flight must not notify or append stale entries.
{
    const f = fixture(); await f.refresh(); await f.schedule();
    let release;
    const inFlight = new Promise(resolve => { release = resolve; });
    f.registry.store.readResult = () => inFlight;
    const tick = f.tick(300000); await Promise.resolve(); await Promise.resolve();
    const count = f.entries.length; f.manager.dispose(); release(undefined); await tick;
    assert.equal(f.messages.length, 0); assert.equal(f.entries.length, count);
}
// Notification failure retries without marking the reminder as sent.
{
    const f = fixture(); await f.refresh(); await f.schedule();
    // Test append/delivery separation by changing the injected Pi instance.
    const send = f.manager.pi.sendMessage;
    f.manager.pi.sendMessage = () => { throw new Error("temporary notification error"); };
    f.manager.report = () => {};
    await f.tick(300000); await Promise.resolve();
    assert.equal(f.entries.at(-1).data.state, "pending");
    f.manager.pi.sendMessage = send;
    await f.tick(30000); assert.equal(f.messages.length, 1);
    f.manager.dispose();
}
assert.equal(REMINDER_ENTRY, "pi-background-task:reminder-state");
console.log("PASS: one-shot notifications, completion/manual cancellation, replay, branch/session isolation, limits, missing tasks, stale callbacks and retry; no task mutations");
