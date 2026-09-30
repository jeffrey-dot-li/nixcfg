import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

/**
 * Footer status for model generation throughput, to make provider throttling
 * visible at a glance.
 *
 *   ⚡ 48 tok/s · avg 52 · ttft 1.3s
 *
 * - While streaming, the first number is a live estimate for the current
 *   response. After the response ends, it is the measured rate for that
 *   response: provider-reported output tokens divided by the time from the
 *   first streamed content delta to the end of the message.
 * - `avg` is a token-weighted rolling average over recent responses (short
 *   responses excluded because their rates are dominated by jitter).
 * - `ttft` is the time from sending the request to the first content delta.
 *   Throttling can show up either as a slow token rate or as a long wait
 *   before the first token. Hidden reasoning (no deltas streamed while the
 *   model thinks) also counts toward ttft rather than the token rate.
 *
 * While waiting for the first token, the status shows ⏳. There is no timer:
 * like static-working-indicator.ts, this avoids idle repaints (which make
 * Cursor's terminal links flicker). Live updates piggyback on stream deltas,
 * which already repaint, and are throttled.
 */

const STATUS_KEY = "token-rate";
const WINDOW = 10; // responses kept in the rolling average
const MIN_TOKENS = 20; // shorter responses are not averaged
const RENDER_THROTTLE_MS = 1000;
const CHARS_PER_TOKEN = 4; // live estimate only, used before usage is final

type Sample = { tokens: number; seconds: number };

export default function tokenRateStatus(pi: ExtensionAPI) {
	let samples: Sample[] = [];
	let requestAt: number | undefined;
	let firstDeltaAt: number | undefined;
	let streamedChars = 0;
	let lastRate: number | undefined;
	let lastTtft: number | undefined;
	let lastRenderAt = 0;
	let uiCtx: ExtensionContext | undefined;

	const average = () => {
		const tokens = samples.reduce((sum, s) => sum + s.tokens, 0);
		const seconds = samples.reduce((sum, s) => sum + s.seconds, 0);
		return seconds > 0 ? tokens / seconds : undefined;
	};

	const render = () => {
		const ctx = uiCtx;
		if (!ctx?.hasUI) return;
		const { theme } = ctx.ui;
		const now = Date.now();
		lastRenderAt = now;
		const parts: string[] = [];

		if (requestAt !== undefined && firstDeltaAt === undefined) {
			parts.push(theme.fg("warning", "⏳ tok/s"));
		} else if (firstDeltaAt !== undefined) {
			const seconds = (now - firstDeltaAt) / 1000;
			const live = seconds > 0.25 ? streamedChars / CHARS_PER_TOKEN / seconds : undefined;
			parts.push(theme.fg("accent", `⚡ ${live === undefined ? "…" : `~${Math.round(live)}`} tok/s`));
		} else if (lastRate !== undefined) {
			parts.push(theme.fg("accent", `⚡ ${Math.round(lastRate)} tok/s`));
		}

		const avg = average();
		if (avg !== undefined) parts.push(theme.fg("dim", `avg ${Math.round(avg)}`));
		const ttft = firstDeltaAt !== undefined && requestAt !== undefined ? (firstDeltaAt - requestAt) / 1000 : lastTtft;
		if (ttft !== undefined) parts.push(theme.fg("dim", `ttft ${ttft.toFixed(1)}s`));

		ctx.ui.setStatus(STATUS_KEY, parts.length ? parts.join(theme.fg("dim", " · ")) : undefined);
	};

	const resetCurrent = () => {
		requestAt = undefined;
		firstDeltaAt = undefined;
		streamedChars = 0;
	};

	pi.on("session_start", async (_event, ctx) => {
		uiCtx = ctx;
		samples = [];
		lastRate = undefined;
		lastTtft = undefined;
		resetCurrent();
		render();
	});

	pi.on("model_select", async (_event, ctx) => {
		// Rates are provider/model specific; do not mix them.
		uiCtx = ctx;
		samples = [];
		lastRate = undefined;
		lastTtft = undefined;
		render();
	});

	pi.on("before_provider_request", (_event, ctx) => {
		uiCtx = ctx;
		resetCurrent();
		requestAt = Date.now();
		render();
	});

	pi.on("message_update", async (event, ctx) => {
		const update = event.assistantMessageEvent as { type: string; delta?: string };
		if (update.type !== "text_delta" && update.type !== "thinking_delta" && update.type !== "toolcall_delta") return;
		uiCtx = ctx;
		if (firstDeltaAt === undefined) {
			firstDeltaAt = Date.now();
			requestAt ??= firstDeltaAt;
		}
		streamedChars += update.delta?.length ?? 0;
		if (Date.now() - lastRenderAt >= RENDER_THROTTLE_MS) render();
	});

	pi.on("message_end", async (event, ctx) => {
		const message = event.message as {
			role: string;
			stopReason?: string;
			usage?: { output?: number };
		};
		if (message.role !== "assistant") return;
		uiCtx = ctx;

		const end = Date.now();
		const tokens = message.usage?.output ?? 0;
		const ok = message.stopReason !== "error" && message.stopReason !== "aborted";

		if (firstDeltaAt !== undefined) {
			lastTtft = requestAt !== undefined ? (firstDeltaAt - requestAt) / 1000 : undefined;
			const seconds = (end - firstDeltaAt) / 1000;
			if (ok && tokens > 0 && seconds > 0) {
				lastRate = tokens / seconds;
				if (tokens >= MIN_TOKENS) {
					samples.push({ tokens, seconds });
					if (samples.length > WINDOW) samples.shift();
				}
			}
		}

		resetCurrent();
		render();
	});

	pi.on("agent_end", async (_event, ctx) => {
		uiCtx = ctx;
		resetCurrent();
		render();
	});
}
