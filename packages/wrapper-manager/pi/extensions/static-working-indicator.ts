import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Cursor invalidates integrated-terminal link decorations whenever Pi's
 * animated working indicator redraws. A single static frame preserves a clear
 * busy signal without continuously rewriting terminal cells under the mouse.
 */
export default function staticWorkingIndicator(pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		ctx.ui.setWorkingIndicator({
			frames: [ctx.ui.theme.fg("accent", "●")],
		});
	});
}
