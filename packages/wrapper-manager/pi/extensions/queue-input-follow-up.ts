import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Keep interactive slash commands responsive while Pi is busy, but route
 * model-bound input to the follow-up queue so it does not interrupt the active
 * task. Built-in and extension commands are dispatched before the input event;
 * everything reaching this handler is a prompt, skill, or prompt template.
 */
export default function queueInputAsFollowUp(pi: ExtensionAPI) {
	pi.on("input", async (event) => {
		if (event.source !== "interactive" || event.streamingBehavior !== "steer") {
			return { action: "continue" };
		}

		pi.sendUserMessage([{ type: "text", text: event.text }, ...(event.images ?? [])], {
			deliverAs: "followUp",
			expandPromptTemplates: true,
		});
		return { action: "handled" };
	});
}
