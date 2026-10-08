import { randomUUID } from "node:crypto";

export const REMINDER_ENTRY = "pi-background-task:reminder-state";
export const REMINDER_MESSAGE = "pi-background-task:reminder";
const FINISHED = new Set(["completed", "failed", "cancelled", "timed_out", "interrupted"]);
const MAX_PENDING = 100;

/**
 * One-shot task reminders, persisted as branch-local Pi entries. Only timer
 * bookkeeping and reminder messages change; task state/commands are untouched.
 */
export class TaskReminders {
    pending = new Map();
    timers = new Map();
    queue = Promise.resolve();
    disposed = false;
    generation = 0;

    constructor(pi, registry, sessionManager, clock = {}) {
        this.pi = pi;
        this.registry = registry;
        this.sessionManager = sessionManager;
        this.sessionId = sessionManager.getSessionId();
        this.now = clock.now ?? Date.now;
        this.setTimer = clock.setTimeout ?? setTimeout;
        this.clearTimer = clock.clearTimeout ?? clearTimeout;
        this.onCompletion = (task) => {
            if (!FINISHED.has(task.status)) return;
            void this.enqueue(async () => {
                for (const reminder of [...this.pending.values()]) {
                    if (reminder.taskId === task.taskId && reminder.cancelOnCompletion && this.isVisible(reminder)) {
                        this.finish(reminder, "cancelled", "task finished");
                    }
                }
            }).catch((error) => this.report(error));
        };
        registry.on("completion", this.onCompletion);
    }

    enqueue(work) {
        const result = this.queue.then(() => {
            if (this.disposed) throw new Error("Background task reminder runtime is no longer active");
            return work();
        });
        this.queue = result.catch(() => undefined);
        return result;
    }

    assertCurrent(generation) {
        if (this.disposed || generation !== this.generation) {
            throw new Error("Background task reminder context changed");
        }
    }

    // Last state entry wins. Forked/new sessions don't inherit another
    // session's alarms; returning to an earlier tree branch restores its state.
    branchState() {
        const records = new Map();
        for (const entry of this.sessionManager.getBranch()) {
            if (entry.type !== "custom" || entry.customType !== REMINDER_ENTRY) continue;
            const data = entry.data;
            if (!data || data.version !== 1 || data.sessionId !== this.sessionId ||
                typeof data.reminderId !== "string" || typeof data.taskId !== "string" ||
                typeof data.message !== "string" || !Number.isFinite(data.dueAt) ||
                typeof data.cancelOnCompletion !== "boolean") continue;
            records.set(data.reminderId, data);
        }
        return records;
    }

    isVisible(reminder) {
        return this.branchState().get(reminder.reminderId)?.state === "pending";
    }

    async taskSnapshot(taskId) {
        // Do not call registry.get(): it can write an interrupted task result.
        // Reminders inspect existing files only, without changing task state.
        const { meta, paths, owned } = await this.registry.resolve(taskId);
        const result = await this.registry.store.readResult(paths);
        return { taskId, name: meta.name, status: result?.status ?? (owned ? meta.status : "unknown"), owned };
    }

    save(reminder) {
        this.pi.appendEntry(REMINDER_ENTRY, reminder);
    }

    finish(reminder, state, reason) {
        this.assertCurrent(this.generation);
        const record = { ...reminder, state, updatedAt: this.now(), ...(reason ? { reason } : {}) };
        this.save(record);
        this.pending.delete(reminder.reminderId);
        const timer = this.timers.get(reminder.reminderId);
        if (timer !== undefined) this.clearTimer(timer);
        this.timers.delete(reminder.reminderId);
        return record;
    }

    arm(reminder, delay = Math.max(0, reminder.dueAt - this.now())) {
        const old = this.timers.get(reminder.reminderId);
        if (old !== undefined) this.clearTimer(old);
        const generation = this.generation;
        const timer = this.setTimer(() => {
            this.timers.delete(reminder.reminderId);
            void this.enqueue(() => this.fire(reminder.reminderId, generation)).catch((error) => {
                this.report(error);
                // A transient notification failure shouldn't silently lose the alarm.
                if (!this.disposed && generation === this.generation && this.pending.has(reminder.reminderId)) {
                    this.arm(reminder, 30_000);
                }
            });
        }, delay);
        timer.unref?.();
        this.timers.set(reminder.reminderId, timer);
    }

    refresh() {
        // Invalidate in-flight callbacks immediately, even before queued replay.
        const generation = ++this.generation;
        for (const timer of this.timers.values()) this.clearTimer(timer);
        this.timers.clear();
        return this.enqueue(async () => {
            this.assertCurrent(generation);
            this.pending.clear();
            for (const record of this.branchState().values()) {
                if (record.state === "pending") this.pending.set(record.reminderId, record);
            }
            for (const reminder of [...this.pending.values()]) {
                let task;
                try { task = await this.taskSnapshot(reminder.taskId); }
                catch { task = undefined; }
                this.assertCurrent(generation);
                if (task && reminder.cancelOnCompletion && FINISHED.has(task.status)) {
                    this.finish(reminder, "cancelled", "task finished");
                } else {
                    this.arm(reminder);
                }
            }
        });
    }

    schedule(params, ctx) {
        return this.enqueue(async () => {
            const generation = this.generation;
            if (ctx.sessionManager.getSessionId() !== this.sessionId) throw new Error("Reminder belongs to another session");
            if (!Number.isInteger(params.afterSeconds) || params.afterSeconds < 1 || params.afterSeconds > 604800) {
                throw new Error("afterSeconds must be an integer between 1 and 604800");
            }
            if (typeof params.message !== "string" || !params.message.trim() || params.message.length > 4000) {
                throw new Error("message must contain 1–4000 characters");
            }
            if (params.cancelOnCompletion !== undefined && typeof params.cancelOnCompletion !== "boolean") {
                throw new Error("cancelOnCompletion must be a boolean");
            }
            if (this.pending.size >= MAX_PENDING) throw new Error(`At most ${MAX_PENDING} reminders may be pending`);
            if (!this.registry.isVisibleInCurrentBranch(params.taskId)) throw new Error("Task is not visible on the current branch");
            const task = await this.taskSnapshot(params.taskId);
            this.assertCurrent(generation);
            if (!task.owned) throw new Error("Cannot schedule reminders for a task owned by another Pi instance");
            const now = this.now();
            const reminder = {
                version: 1, reminderId: `rem_${randomUUID()}`, sessionId: this.sessionId,
                taskId: task.taskId, message: params.message.trim(), createdAt: now,
                dueAt: now + params.afterSeconds * 1000,
                cancelOnCompletion: params.cancelOnCompletion ?? true, state: "pending",
            };
            if (reminder.cancelOnCompletion && FINISHED.has(task.status)) {
                return this.finish(reminder, "cancelled", "task already finished");
            }
            this.save(reminder);
            this.pending.set(reminder.reminderId, reminder);
            this.arm(reminder);
            return reminder;
        });
    }

    list() {
        return this.enqueue(() => [...this.pending.values()].filter((r) => this.isVisible(r)).sort((a, b) => a.dueAt - b.dueAt));
    }

    cancel(reminderId) {
        return this.enqueue(() => {
            const reminder = this.pending.get(reminderId);
            if (!reminder || !this.isVisible(reminder)) throw new Error(`Pending reminder not found: ${reminderId}`);
            return this.finish(reminder, "cancelled", "cancelled by request");
        });
    }

    async fire(reminderId, generation) {
        this.assertCurrent(generation);
        const reminder = this.pending.get(reminderId);
        if (!reminder || !this.isVisible(reminder)) return;
        let task;
        try { task = await this.taskSnapshot(reminder.taskId); }
        catch { task = { taskId: reminder.taskId, name: "task record unavailable", status: "unknown" }; }
        this.assertCurrent(generation);
        if (!this.isVisible(reminder)) return;
        if (reminder.cancelOnCompletion && FINISHED.has(task.status)) {
            this.finish(reminder, "cancelled", "task finished");
            return;
        }
        this.pi.sendMessage({
            customType: REMINDER_MESSAGE,
            content: `Background task reminder:\n- ${task.taskId} (${task.name}): ${task.status}\nReminder: ${reminder.message}\nInspect task_status and relevant task_logs, then decide what to do. This reminder has not modified the task.`,
            display: true,
            details: { reminderId, taskId: reminder.taskId, dueAt: reminder.dueAt },
        }, { triggerTurn: true, deliverAs: "followUp" });
        this.finish(reminder, "notified");
    }

    report(error) {
        if (!this.disposed && error?.message !== "Background task reminder context changed") {
            console.error(`[pi-background-task] reminder: ${error instanceof Error ? error.message : String(error)}`);
        }
    }

    dispose() {
        this.disposed = true;
        ++this.generation;
        for (const timer of this.timers.values()) this.clearTimer(timer);
        this.timers.clear();
        this.pending.clear();
        this.registry.off("completion", this.onCompletion);
    }
}
