// Integration fixture: load explicitly with `pi --no-extensions -e <this file>`.
// Run /test-bash-timeout. It takes about 60 seconds and does not call a model.
import assert from "node:assert/strict";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import expandBashCommand from "../extensions/expand-bash-command.ts";

export default function testBashTimeout(pi: ExtensionAPI) {
	let bash: Parameters<ExtensionAPI["registerTool"]>[0];
	expandBashCommand({
		registerTool(definition) {
			bash = definition;
			pi.registerTool(definition);
		},
	} as ExtensionAPI);

	pi.registerCommand("test-bash-timeout", {
		description: "Test real Bash timeout termination (about 60 seconds)",
		handler: async (_args, ctx: ExtensionCommandContext) => {
			const quick = await bash.execute("quick", { command: "printf quick" }, undefined, undefined, ctx);
			assert.equal(quick.content[0].type, "text");
			assert.equal((quick.content[0] as { text: string }).text, "quick");

			const check = async (timeout: number | undefined, expected: number) => {
				const started = performance.now();
				let caught: Error | undefined;
				try {
					await bash.execute(
						"timeout-test",
						{ command: "printf 'shell=%s\\n' $$; sleep 70; printf UNEXPECTED_COMPLETION", ...(timeout === undefined ? {} : { timeout }) },
						undefined, undefined, ctx,
					);
				} catch (error) {
					caught = error as Error;
				}
				assert.ok(caught, "command must time out");
				assert.ok(caught.message.includes(`Command timed out after ${expected} seconds`), caught.message);
				assert.ok(caught.message.includes("partial changes"));
				assert.ok(!caught.message.includes("UNEXPECTED_COMPLETION"));
				const elapsed = (performance.now() - started) / 1000;
				assert.ok(elapsed >= expected - 0.1 && elapsed < expected + 5, `elapsed=${elapsed}`);
				const pid = Number(/shell=(\d+)/.exec(caught.message)?.[1]);
				assert.ok(pid > 0, "partial output retained");
				assert.throws(() => process.kill(pid, 0), { code: "ESRCH" }, "shell terminated");
			};
			// Run in parallel to test omitted, oversized and short timeouts in one minute.
			await Promise.all([check(undefined, 60), check(120, 60), check(0.2, 0.2)]);
			ctx.ui.notify("PASS: real Bash process termination at 60 seconds, short timeout and partial output", "info");
		},
	});
}
