import { access, readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const LOCAL_AGENT_FILES = ["agents.local.md", "AGENTS.local.md"] as const;

async function repositoryRoot(cwd: string): Promise<string | undefined> {
	let directory = resolve(cwd);

	while (true) {
		try {
			await access(join(directory, ".git"));
			return directory;
		} catch {
			const parent = dirname(directory);
			if (parent === directory) return undefined;
			directory = parent;
		}
	}
}

async function readLocalInstructions(root: string): Promise<string[]> {
	const instructions: string[] = [];

	for (const filename of LOCAL_AGENT_FILES) {
		const path = join(root, filename);
		try {
			const content = (await readFile(path, "utf8")).trim();
			if (content) instructions.push(`Instructions from ${path}:\n\n${content}`);
		} catch (error) {
			if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
		}
	}

	return instructions;
}

/** Load private, globally ignored instructions from the current Git root. */
export default function loadLocalAgents(pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event, ctx) => {
		const root = await repositoryRoot(ctx.cwd);
		if (!root) return;

		const instructions = await readLocalInstructions(root);
		if (instructions.length === 0) return;

		return {
			systemPrompt: `${event.systemPrompt}\n\n${instructions.join("\n\n")}`,
		};
	});
}
