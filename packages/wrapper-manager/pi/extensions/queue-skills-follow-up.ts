import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function commandName(text: string): string | undefined {
	return text.match(/^\/([^\s]+)/)?.[1];
}

/**
 * Keep interactive slash commands responsive while Pi is busy, but route skill
 * invocations to the follow-up queue so they run after the current agent task.
 */
export default function queueSkillsAsFollowUps(pi: ExtensionAPI) {
	pi.on("input", async (event) => {
		if (event.source !== "interactive" || event.streamingBehavior !== "steer") {
			return { action: "continue" };
		}

		const name = commandName(event.text);
		if (!name || !pi.getCommands().some((command) => command.name === name && command.source === "skill")) {
			return { action: "continue" };
		}

		pi.sendUserMessage([{ type: "text", text: event.text }, ...(event.images ?? [])], {
			deliverAs: "followUp",
			expandPromptTemplates: true,
		});
		return { action: "handled" };
	});
}
