import { readFile } from "node:fs/promises";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Load Nix-managed defaults without replacing Pi's machine-local AGENTS.md.
 * Resolve relative to this extension so the installed store package works from
 * any cwd, including VMs and sessions using a different PI_CODING_AGENT_DIR.
 */
/**
 * Background subagent runners (PI_SUBAGENT_CHILD=1) load these defaults too, but
 * their Bash is uncapped and they have no background-task tools (see
 * expand-bash-command.ts), so the shell and background-task rules are scoped.
 */
const SUBAGENT_NOTE = `## Running as a subagent

You are running as a subagent. Here the Bash 60-second limit and the background-task rules above do not apply: Bash has no time limit and background-task tools are not available. Run long commands (builds, test suites) in the foreground with bash and wait for them; pass a timeout only to bound a command that could hang. Still never launch background or detached processes through Bash.`;

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
				...(process.env.PI_SUBAGENT_CHILD === "1" ? [SUBAGENT_NOTE] : []),
				event.systemPrompt,
			].join("\n\n"),
		};
	});
}
