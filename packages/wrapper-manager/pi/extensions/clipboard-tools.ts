import { copyToClipboard, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";

/**
 * Clipboard helpers that copy source text instead of the rendered screen.
 *
 * Fullscreen mouse selection copies rendered rows, so soft-wrapped paragraphs
 * arrive with hard newlines and indentation. These copy the message text the
 * transcript was rendered from:
 *
 * - Ctrl+X with text in the editor cuts it to the clipboard (and clears the
 *   editor), to set a half-written prompt aside. With an empty editor it copies
 *   the last assistant response, as Pi's built-in Ctrl+X does. The built-in
 *   `app.message.copy` moves to Ctrl+Shift+X (the wrapper's keybindings), where
 *   it still copies the selected message in /tree and sign-in URLs.
 * - /clip opens a picker of the last response, each of its code blocks, and
 *   recent messages, and copies the chosen one.
 */

const RECENT_MESSAGES = 20;
const PREVIEW_CHARS = 70;

type Role = "user" | "assistant";
interface Message {
	role: Role;
	text: string;
}

export default function clipboardTools(pi: ExtensionAPI) {
	pi.registerShortcut("ctrl+x", {
		description: "Cut the editor text to the clipboard; with an empty editor, copy the last response",
		handler: async (ctx) => {
			const draft = ctx.ui.getEditorText();
			if (draft.trim()) {
				if (await copy(ctx, draft, "Prompt cut to clipboard")) ctx.ui.setEditorText("");
				return;
			}
			const last = messages(ctx).findLast((message) => message.role === "assistant");
			if (!last) {
				ctx.ui.notify("No assistant response to copy", "warning");
				return;
			}
			await copy(ctx, last.text, "Copied last response");
		},
	});

	pi.registerCommand("clip", {
		description: "Copy the last response, one of its code blocks, or a recent message (source text, no wrapping)",
		handler: async (_args, ctx) => {
			const all = messages(ctx);
			const choices: Array<{ label: string; text: string }> = [];
			const last = all.findLast((message) => message.role === "assistant");
			if (last) {
				choices.push({ label: `Last response · ${preview(last.text)}`, text: last.text });
				codeBlocks(last.text).forEach((block, index) =>
					choices.push({
						label: `Code block ${index + 1}${block.language ? ` (${block.language})` : ""} · ${preview(block.code)}`,
						text: block.code,
					}),
				);
			}
			for (const message of all.slice(-RECENT_MESSAGES).reverse()) {
				if (message === last) continue;
				choices.push({ label: `${message.role === "user" ? "You" : "Pi"} · ${preview(message.text)}`, text: message.text });
			}
			if (!choices.length) {
				ctx.ui.notify("Nothing to copy yet", "warning");
				return;
			}
			// Labels can repeat; prefix an index so the selection maps back uniquely.
			const labels = choices.map((choice, index) => `${index + 1}. ${choice.label}`);
			const picked = await ctx.ui.select("Copy to clipboard", labels);
			if (picked === undefined) return;
			const choice = choices[labels.indexOf(picked)];
			if (choice) await copy(ctx, choice.text, "Copied");
		},
	});
}

async function copy(ctx: ExtensionContext, text: string, done: string): Promise<boolean> {
	try {
		await copyToClipboard(text);
		ctx.ui.notify(done, "info");
		return true;
	} catch (error) {
		ctx.ui.notify(`Copy failed: ${error instanceof Error ? error.message : String(error)}`, "error");
		return false;
	}
}

/** User and assistant messages on the active branch with their text content. */
function messages(ctx: ExtensionContext): Message[] {
	const result: Message[] = [];
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "message") continue;
		const { role, content } = entry.message as { role: string; content: unknown };
		if (role !== "user" && role !== "assistant") continue;
		const text = textOf(content).trim();
		if (text) result.push({ role, text });
	}
	return result;
}

function textOf(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.filter((part): part is { type: "text"; text: string } => part?.type === "text" && typeof part.text === "string")
		.map((part) => part.text)
		.join("\n\n");
}

/** Fenced code blocks (``` or ~~~, three or more), without the fences. */
export function codeBlocks(markdown: string): Array<{ language: string; code: string }> {
	const blocks: Array<{ language: string; code: string }> = [];
	const lines = markdown.split("\n");
	for (let index = 0; index < lines.length; index++) {
		const open = /^ {0,3}(`{3,}|~{3,})\s*([^\s`]*)/.exec(lines[index]!);
		if (!open) continue;
		const fence = open[1]!;
		const body: string[] = [];
		let end = index + 1;
		for (; end < lines.length; end++) {
			const line = lines[end]!;
			if (line.trimStart().startsWith(fence[0]!.repeat(fence.length)) && !line.trim().slice(fence.length).trim()) break;
			body.push(line);
		}
		blocks.push({ language: open[2] ?? "", code: body.join("\n") });
		index = end;
	}
	return blocks;
}

function preview(text: string): string {
	const flat = text.replace(/\s+/g, " ").trim();
	return flat.length > PREVIEW_CHARS ? `${flat.slice(0, PREVIEW_CHARS - 1)}…` : flat;
}
