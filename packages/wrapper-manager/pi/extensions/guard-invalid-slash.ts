import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function slashCommandName(text: string): string | undefined {
	if (!text.startsWith("/")) return undefined;
	return text.slice(1).match(/^[^\s]*/)?.[0];
}

export default function guardInvalidSlashCommands(pi: ExtensionAPI) {
	pi.on("input", async (event, ctx) => {
		// This is an interactive editor affordance. RPC, print, JSON, and
		// extension-injected messages retain Pi's normal input semantics.
		if (event.source !== "interactive") return { action: "continue" };

		const commandName = slashCommandName(event.text);
		if (commandName === undefined) return { action: "continue" };

		// Extension commands are normally dispatched before this event. Skills
		// and prompt templates reach this event and are included by getCommands().
		// Builtin TUI commands are handled by Pi's interactive command dispatcher.
		const isKnownCommand = pi.getCommands().some((command) => command.name === commandName);
		if (isKnownCommand) return { action: "continue" };

		// Input handlers run after submission, so restore the text to make Enter
		// behave as a no-op. Do not notify or add anything to the conversation.
		ctx.ui.setEditorText(event.text);
		return { action: "handled" };
	});
}
