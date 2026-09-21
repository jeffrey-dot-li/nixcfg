import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Keep interactive slash commands responsive while Pi is busy. Ordinary Enter
 * submissions are routed to the follow-up queue so they do not interrupt the
 * active task, while the explicit Option+Enter action is inverted to provide a
 * reachable steering path. Built-in and extension commands are dispatched
 * before the input event; everything reaching this handler is model-bound.
 */
export default function routeBusyInput(pi: ExtensionAPI) {
	pi.on("input", async (event) => {
		if (event.source !== "interactive") return { action: "continue" };

		const deliverAs =
			event.streamingBehavior === "steer"
				? "followUp"
				: event.streamingBehavior === "followUp"
					? "steer"
					: undefined;
		if (!deliverAs) return { action: "continue" };

		pi.sendUserMessage([{ type: "text", text: event.text }, ...(event.images ?? [])], {
			deliverAs,
			expandPromptTemplates: true,
		});
		return { action: "handled" };
	});
}
