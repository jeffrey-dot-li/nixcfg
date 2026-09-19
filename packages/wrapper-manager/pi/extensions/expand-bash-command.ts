import { createBashTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

const PREVIEW_LENGTH = 160;

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
			const text = (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);

			text.setText(theme.fg("toolTitle", theme.bold(`$ ${displayedCommand}`)) + timeout);
			return text;
		},
	});
}
