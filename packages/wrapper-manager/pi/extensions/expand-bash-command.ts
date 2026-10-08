import { createBashTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	type Component,
	truncateToWidth,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";

import { effectiveBashTimeout, MAX_BASH_TIMEOUT_SECONDS } from "./bash-timeout.ts";

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
 * It also enforces a maximum 60-second timeout on every Bash tool execution.
 */
export default function expandBashCommand(pi: ExtensionAPI) {
	const bash = createBashTool(process.cwd());

	pi.registerTool({
		...bash,
		description: `${bash.description} Foreground execution is limited to ${MAX_BASH_TIMEOUT_SECONDS} seconds, including when timeout is omitted. Larger timeouts are clamped. Use task_start for commands that might take longer.`,
		promptGuidelines: [
			...(bash.promptGuidelines ?? []),
			"Bash commands have an enforced 60-second timeout. Use task_start for work that might exceed one minute, then inspect its exit status and logs. A timeout interrupts the command and may leave partial effects; inspect before retrying. Do not automatically rerun side-effecting commands.",
			"For background tasks, keep notifyOnCompletion enabled and do not immediately call task_wait or poll. Do independent work, or finish the turn and resume on the completion notification. Only use blocking waits when the user explicitly requests them.",
		],
		async execute(id, params, signal, onUpdate, ctx) {
			const timeout = effectiveBashTimeout(params.timeout);
			try {
				return await bash.execute(id, { ...params, timeout }, signal, onUpdate, ctx);
			} catch (error) {
				if (error instanceof Error && error.message.includes(`Command timed out after ${timeout} seconds`)) {
					throw new Error(`${error.message}\nThe command was interrupted and may have left partial changes. Inspect before retrying. Use task_start for long-running work; this command was not restarted automatically.`);
				}
				throw error;
			}
		},
		renderCall(args, theme, context) {
			const command = typeof args?.command === "string" ? args.command : "(invalid command)";
			const timeout = theme.fg("muted", ` (timeout ${effectiveBashTimeout(args?.timeout)}s)`);
			const displayedCommand = context.expanded ? command : previewCommand(command);
			const component =
				(context.lastComponent as ResponsiveText | undefined) ?? new ResponsiveText();

			component.setText(theme.fg("toolTitle", theme.bold(`$ ${displayedCommand}`)) + timeout);
			return component;
		},
	});
}
