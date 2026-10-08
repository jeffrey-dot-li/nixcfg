import { readFile } from "node:fs/promises";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Load Nix-managed defaults without replacing Pi's machine-local AGENTS.md.
 * Resolve relative to this extension so the installed store package works from
 * any cwd, including VMs and sessions using a different PI_CODING_AGENT_DIR.
 */
export default function loadUniversalAgents(pi: ExtensionAPI) {
	const instructionsFile = new URL("../AGENTS.md", import.meta.url);
	let instructions: string | undefined;

	pi.on("session_start", async () => {
		instructions = (await readFile(instructionsFile, "utf8")).trim();
	});

	pi.on("before_agent_start", async (event) => {
		// Also support loading this extension before any session_start event.
		instructions ??= (await readFile(instructionsFile, "utf8")).trim();
		if (!instructions) return;

		return {
			systemPrompt: [
				"Universal Pi defaults (Nix-managed). Machine-local and project instructions below may specialize or override these defaults:",
				instructions,
				event.systemPrompt,
			].join("\n\n"),
		};
	});
}
