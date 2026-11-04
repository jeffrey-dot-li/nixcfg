import { createBashTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	type Component,
	truncateToWidth,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";

import {
	backgroundAfterSeconds,
	createBackgroundingOperations,
	type AdoptInput,
	type Promotion,
} from "./bash-background.ts";
import { effectiveBashTimeout, MAX_BASH_TIMEOUT_SECONDS } from "./bash-timeout.ts";

/** pi-background-task's cross-extension API (its adopt patch), when that package is loaded. */
interface BackgroundTaskApi {
	adopt(piSessionId: string, input: AdoptInput): Promise<{ taskId: string; name: string }>;
}
const BACKGROUND_TASK_API = Symbol.for("pi-background-task.api");
function backgroundTaskApi(): BackgroundTaskApi | undefined {
	return (globalThis as Record<symbol, BackgroundTaskApi | undefined>)[BACKGROUND_TASK_API];
}

function explicitTimeout(requested: unknown): boolean {
	return typeof requested === "number" && Number.isFinite(requested) && requested > 0;
}

function promotionNote(promotion: Promotion): string {
	return `[Still running after ${promotion.afterSeconds}s: moved to background task ${promotion.taskId} (${promotion.name}). It keeps running; you will be notified when it finishes. Use task_logs for its output (the full stream, including the part above), task_status, or task_kill to stop it. Do not rerun it.]`;
}

const PREVIEW_LENGTH = 160;

class ResponsiveText implements Component {
	private content = "";
	private cachedWidth: number | undefined;
	private cachedLines: string[] | undefined;

	setText(content: string): void {
		if (this.content === content) return;
		this.content = content;
		this.invalidate();
	}

	render(width: number): string[] {
		const safeWidth = Math.max(1, width);
		if (this.cachedLines && this.cachedWidth === safeWidth) return this.cachedLines;

		this.cachedWidth = safeWidth;
		this.cachedLines = wrapTextWithAnsi(this.content, safeWidth).map((line) =>
			truncateToWidth(line, safeWidth, ""),
		);
		return this.cachedLines;
	}

	invalidate(): void {
		this.cachedWidth = undefined;
		this.cachedLines = undefined;
	}
}

function previewCommand(command: string): string {
	const oneLine = command.replace(/\s+/g, " ").trim();
	return oneLine.length > PREVIEW_LENGTH ? `${oneLine.slice(0, PREVIEW_LENGTH - 1)}…` : oneLine;
}

/**
 * Make Ctrl+O expand the bash tool call as well as its output.
 *
 * The built-in bash renderer respects the expanded state only for output. This
 * override retains the built-in shell backend and result renderer, but
 * renders the complete command (including newlines) while the row is expanded.
 * It also caps foreground Bash at 60 seconds: an explicit timeout kills at that
 * time, and a call without one moves to a background task (bash-background.ts).
 */
export default function expandBashCommand(pi: ExtensionAPI) {
	const bash = createBashTool(process.cwd());

	pi.registerTool({
		...bash,
		description: `${bash.description} Without a timeout, a command still running after ${MAX_BASH_TIMEOUT_SECONDS} seconds moves to a background task (the call returns its output so far and a task ID; you are notified on completion). An explicit timeout (capped at ${MAX_BASH_TIMEOUT_SECONDS}s) kills the command instead. Prefer task_start for work known to be long-running.`,
		promptGuidelines: [
			...(bash.promptGuidelines ?? []),
			"Bash commands without a timeout that run longer than 60 seconds move to a background task automatically: the call returns the output so far plus a task ID, the command keeps running, and a completion notification follows. Do not rerun it; use task_logs/task_status/task_kill on that ID. An explicit timeout (at most 60 seconds) kills the command at that time instead, possibly leaving partial effects; inspect before retrying and do not automatically rerun side-effecting commands. Prefer task_start for work known to be long-running (builds, test suites, servers).",
			"Never launch background or detached processes through Bash: no trailing &, nohup, disown, setsid, ad-hoc tmux/screen sessions, or daemon/detach flags. Start dev servers, port-forwards, tunnels and watchers with task_start, running the actual service in the foreground inside that task. Track its task ID and stop it with task_kill when no longer needed.",
			"Tool calls in the same message run concurrently with no ordering guarantee. A bash call alongside write/edit may run before the file exists or changes. Run bash that depends on a write/edit in a later message, after that result returns.",
			"For background tasks, keep notifyOnCompletion enabled and do not immediately call task_wait or poll. Do independent work, or finish the turn and resume on the completion notification. Only use blocking waits when the user explicitly requests them.",
		],
		async execute(id, params, signal, onUpdate, ctx) {
			const timeout = effectiveBashTimeout(params.timeout);
			const capped = explicitTimeout(params.timeout);
			const api = backgroundTaskApi();
			const sessionId = ctx?.sessionManager?.getSessionId?.();
			let promotion: Promotion | undefined;
			const operations = createBackgroundingOperations({
				afterSeconds: Math.min(backgroundAfterSeconds(), MAX_BASH_TIMEOUT_SECONDS),
				adopt: api && sessionId ? (input) => api.adopt(sessionId, input) : undefined,
				onPromoted: (value) => {
					promotion = value;
				},
				name: previewCommand,
			});
			const runner = createBashTool(ctx?.cwd || process.cwd(), { operations });
			try {
				// Without an explicit timeout the backend promotes instead of killing.
				const result = await runner.execute(id, { ...params, timeout: capped ? timeout : undefined }, signal, onUpdate, ctx);
				if (!promotion) return result;
				const note = promotionNote(promotion);
				const text = result.content?.find((part: { type: string }) => part.type === "text") as { text: string } | undefined;
				if (text) text.text = text.text && text.text !== "(no output)" ? `${text.text}\n\n${note}` : note;
				else result.content = [...(result.content ?? []), { type: "text", text: note }];
				result.details = { ...(result.details ?? {}), backgroundTaskId: promotion.taskId };
				if (result.structuredContent) {
					result.structuredContent = {
						...result.structuredContent,
						output: `${result.structuredContent.output ?? ""}\n\n${note}`,
						exit_code: -1,
					};
				}
				return result;
			} catch (error) {
				if (error instanceof Error && /Command timed out after [0-9.]+ seconds/.test(error.message)) {
					throw new Error(`${error.message}\nThe command was interrupted and may have left partial changes. Inspect before retrying. Use task_start for long-running work; this command was not restarted automatically.`);
				}
				throw error;
			}
		},
		renderCall(args, theme, context) {
			const command = typeof args?.command === "string" ? args.command : "(invalid command)";
			const timeout = theme.fg(
				"muted",
				explicitTimeout(args?.timeout)
					? ` (timeout ${effectiveBashTimeout(args?.timeout)}s)`
					: ` (background after ${MAX_BASH_TIMEOUT_SECONDS}s)`,
			);
			const displayedCommand = context.expanded ? command : previewCommand(command);
			const component =
				(context.lastComponent as ResponsiveText | undefined) ?? new ResponsiveText();

			component.setText(theme.fg("toolTitle", theme.bold(`$ ${displayedCommand}`)) + timeout);
			return component;
		},
	});
}
