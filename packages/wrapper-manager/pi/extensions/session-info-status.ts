import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

/**
 * Footer status showing the session's display name (set with /name) and the
 * number of conversation messages on the active branch, e.g.
 *
 *   refactor auth · 14 msgs
 *
 * Messages are user prompts plus assistant responses; tool results are not
 * counted. Unnamed sessions show only the count.
 */
const STATUS_KEY = "session-info";

export default function sessionInfoStatus(pi: ExtensionAPI) {
	const countMessages = (ctx: ExtensionContext) =>
		ctx.sessionManager
			.getBranch()
			.filter((entry) => entry.type === "message" && (entry.message.role === "user" || entry.message.role === "assistant"))
			.length;

	const render = (ctx: ExtensionContext, name = pi.getSessionName()) => {
		if (!ctx.hasUI) return;
		const { theme } = ctx.ui;
		const count = countMessages(ctx);
		const parts: string[] = [];
		if (name) parts.push(theme.fg("accent", name));
		parts.push(theme.fg("dim", `${count} ${count === 1 ? "msg" : "msgs"}`));
		ctx.ui.setStatus(STATUS_KEY, parts.join(theme.fg("dim", " · ")));
	};

	pi.on("session_start", async (_event, ctx) => render(ctx));
	pi.on("session_info_changed", async (event, ctx) => render(ctx, event.name));
	pi.on("session_tree", async (_event, ctx) => render(ctx));
	pi.on("session_compact", async (_event, ctx) => render(ctx));
	pi.on("message_end", async (event, ctx) => {
		const role = event.message.role;
		if (role === "user" || role === "assistant") render(ctx);
	});
	pi.on("agent_end", async (_event, ctx) => render(ctx));
}
