import { existsSync, unlinkSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * /undo: rewind the conversation by one user message, like choosing the most
 * recent message in /fork, but without leaving the original conversation
 * behind.
 *
 * Pi's fork machinery does the rewind: it writes a new session file holding
 * the active branch up to (but excluding) the last user message and restores
 * that message's text into the editor. /undo then deletes the old session
 * file, so the session list keeps only one conversation. Deleting the old
 * file also removes any other /tree branches stored in it.
 */
export default function undoLastMessage(pi: ExtensionAPI) {
	pi.registerCommand("undo", {
		description: "Rewind the last user message (restores it to the editor) and discard the old session",
		handler: async (_args, ctx) => {
			const branch = ctx.sessionManager.getBranch();
			const lastUser = [...branch]
				.reverse()
				.find((entry) => entry.type === "message" && entry.message.role === "user");
			if (!lastUser) {
				ctx.ui.notify("Nothing to undo", "warning");
				return;
			}

			// Capture plain data only; the old session context is stale after fork.
			const oldSessionFile = ctx.sessionManager.getSessionFile();

			// Pi writes the session file only after the first assistant response.
			// Forking an unsaved session past its first message throws, and a fork
			// error from a command is fatal in the TUI, so do not attempt it.
			if (
				ctx.sessionManager.isPersisted() &&
				lastUser.parentId &&
				(!oldSessionFile || !existsSync(oldSessionFile))
			) {
				ctx.ui.notify("Nothing saved to undo yet; wait for an assistant response", "warning");
				return;
			}
			let newSessionFile: string | undefined;

			// The fork tears down the current runtime, which aborts any active run.
			const result = await ctx.fork(lastUser.id, {
				withSession: async (newCtx) => {
					newSessionFile = newCtx.sessionManager.getSessionFile();
				},
			});
			if (result.cancelled) return;

			// Ephemeral (--no-session) sessions fork in place; there is no file to remove.
			if (oldSessionFile && oldSessionFile !== newSessionFile && existsSync(oldSessionFile)) {
				try {
					unlinkSync(oldSessionFile);
				} catch (error) {
					const message = error instanceof Error ? error.message : String(error);
					console.error(`/undo: failed to delete ${oldSessionFile}: ${message}`);
				}
			}
		},
	});
}
