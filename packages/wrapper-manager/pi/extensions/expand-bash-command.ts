import { createBashTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	type Component,
	truncateToWidth,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";

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
 * override retains the built-in tool implementation and result renderer, but
 * renders the complete command (including newlines) while the row is expanded.
 */
export default function expandBashCommand(pi: ExtensionAPI) {
	const bash = createBashTool(process.cwd());

	pi.registerTool({
		...bash,
		renderCall(args, theme, context) {
			const command = typeof args?.command === "string" ? args.command : "(invalid command)";
			const timeout =
				typeof args?.timeout === "number" ? theme.fg("muted", ` (timeout ${args.timeout}s)`) : "";
			const displayedCommand = context.expanded ? command : previewCommand(command);
			const component =
				(context.lastComponent as ResponsiveText | undefined) ?? new ResponsiveText();

			component.setText(theme.fg("toolTitle", theme.bold(`$ ${displayedCommand}`)) + timeout);
			return component;
		},
	});
}
