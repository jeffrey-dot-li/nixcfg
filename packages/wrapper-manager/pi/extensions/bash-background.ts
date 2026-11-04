import { spawn } from "node:child_process";
import { createWriteStream, mkdtempSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { constants as fsConstants } from "node:fs";
import { access } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { getShellConfig, getShellEnv } from "@earendil-works/pi-coding-agent";

/**
 * Bash execution that moves long-running calls to the background instead of
 * killing them.
 *
 * The command runs exactly like Pi's local Bash backend (same shell, detached
 * process group, piped stdout/stderr, no terminal). Its output is also appended
 * to a private file. If it is still running after `afterSeconds`, the process
 * is handed to pi-background-task (`adopt`): the tool call returns the output
 * so far, the process keeps running as Pi's child, and the task tracks it,
 * notifying on completion. No reparenting is needed because the background
 * task only follows the file and the exit status written here.
 *
 * An explicit `timeout` keeps Pi's kill-at-timeout semantics.
 */

export const DEFAULT_BACKGROUND_AFTER_SECONDS = 60;

export interface AdoptInput {
	pid: number;
	command: string;
	name: string;
	cwd: string;
	output: string;
	exit: string;
	startedAt: string;
	notifyOnCompletion: boolean;
}

export interface Promotion {
	taskId: string;
	name: string;
	afterSeconds: number;
}

export interface BackgroundingOptions {
	/** Seconds before an uncapped call moves to the background. */
	afterSeconds: number;
	/** Hand-off to pi-background-task; undefined when it is unavailable (then the call is killed). */
	adopt?: (input: AdoptInput) => Promise<{ taskId: string; name: string }>;
	onPromoted: (promotion: Promotion) => void;
	name: (command: string) => string;
}

interface ExecOptions {
	onData: (data: Buffer) => void;
	signal?: AbortSignal;
	timeout?: number;
	env?: NodeJS.ProcessEnv;
}

/** The `background after` threshold; PI_BASH_BACKGROUND_AFTER_SECONDS overrides it (tests). */
export function backgroundAfterSeconds(env: NodeJS.ProcessEnv = process.env): number {
	const configured = Number(env.PI_BASH_BACKGROUND_AFTER_SECONDS);
	return Number.isFinite(configured) && configured > 0 ? configured : DEFAULT_BACKGROUND_AFTER_SECONDS;
}

export function createBackgroundingOperations(options: BackgroundingOptions) {
	return {
		async exec(command: string, cwd: string, { onData, signal, timeout, env }: ExecOptions): Promise<{ exitCode: number | null }> {
			if (signal?.aborted) throw new Error("aborted");
			try {
				await access(cwd, fsConstants.F_OK);
			} catch {
				throw new Error(`Working directory does not exist: ${cwd}\nCannot execute bash commands.`);
			}
			const shell = getShellConfig() as { shell: string; args: string[]; commandTransport?: string };
			const fromStdin = shell.commandTransport === "stdin";
			const dir = mkdtempSync(join(tmpdir(), "pi-bash-"));
			const outputPath = join(dir, "output");
			const exitPath = join(dir, "exit.json");
			const sink = createWriteStream(outputPath, { flags: "a", mode: 0o600 });
			const startedAt = new Date().toISOString();
			const child = spawn(shell.shell, fromStdin ? shell.args : [...shell.args, command], {
				cwd,
				detached: true,
				env: env ?? getShellEnv(),
				stdio: [fromStdin ? "pipe" : "ignore", "pipe", "pipe"],
				windowsHide: true,
			});
			if (fromStdin) {
				child.stdin?.on("error", () => {});
				child.stdin?.end(command);
			}

			let promoted = false;
			// A hand-off in flight: if the command exits meanwhile, the task still
			// receives its exit status (and simply completes right away).
			let adopting = false;
			let closedExitCode: number | undefined;
			let settled = false;
			let timer: NodeJS.Timeout | undefined;
			const killGroup = () => {
				if (!child.pid) return;
				try {
					process.kill(-child.pid, "SIGKILL");
				} catch {
					try {
						child.kill("SIGKILL");
					} catch {
						// Already gone.
					}
				}
			};

			return await new Promise((resolve, reject) => {
				const settle = (action: () => void) => {
					if (settled) return;
					settled = true;
					if (timer) clearTimeout(timer);
					signal?.removeEventListener("abort", onAbort);
					action();
				};
				const fail = (message: string) => {
					killGroup();
					settle(() => reject(new Error(message)));
				};
				const onAbort = () => fail("aborted");
				const onChunk = (chunk: Buffer) => {
					sink.write(chunk);
					if (!promoted) onData(chunk);
				};
				child.stdout?.on("data", onChunk);
				child.stderr?.on("data", onChunk);
				signal?.addEventListener("abort", onAbort, { once: true });

				const promote = async () => {
					const pid = child.pid;
					if (!options.adopt || !pid || settled) {
						fail(`timeout:${options.afterSeconds}`);
						return;
					}
					adopting = true;
					try {
						const task = await options.adopt({
							pid,
							command,
							name: options.name(command),
							cwd,
							output: outputPath,
							exit: exitPath,
							startedAt,
							notifyOnCompletion: true,
						});
						if (settled) return; // Aborted during the hand-off.
						promoted = true;
						options.onPromoted({ taskId: task.taskId, name: task.name, afterSeconds: options.afterSeconds });
						settle(() => resolve({ exitCode: 0 }));
					} catch {
						adopting = false;
						if (closedExitCode !== undefined) {
							rmSync(dir, { recursive: true, force: true });
							settle(() => resolve({ exitCode: closedExitCode! }));
						} else {
							fail(`timeout:${options.afterSeconds}`);
						}
					}
				};
				if (timeout !== undefined) {
					timer = setTimeout(() => fail(`timeout:${timeout}`), timeout * 1000);
				} else {
					timer = setTimeout(() => void promote(), options.afterSeconds * 1000);
				}

				child.once("error", (error) => {
					sink.end();
					settle(() => reject(error));
				});
				child.once("close", (code, signalName) => {
					// The follower drains the output file before reading the exit status,
					// so flush the file first, then publish the status atomically.
					sink.end(() => {
						const exitCode = code ?? (signalName ? null : 1);
						closedExitCode = code ?? (signalName ? 128 : 1);
						if (promoted || adopting) {
							const temp = `${exitPath}.tmp`;
							writeFileSync(temp, JSON.stringify({ exitCode, signal: signalName ?? null }), { mode: 0o600 });
							renameSync(temp, exitPath);
						} else {
							rmSync(dir, { recursive: true, force: true });
						}
						if (!adopting || promoted) settle(() => resolve({ exitCode: closedExitCode! }));
					});
				});
			});
		},
	};
}
