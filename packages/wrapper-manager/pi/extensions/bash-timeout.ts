/** Enforced in the Bash executor, not merely suggested to the model. */
export const MAX_BASH_TIMEOUT_SECONDS = 60;

export function effectiveBashTimeout(requested: unknown): number {
	return typeof requested === "number" && Number.isFinite(requested) && requested > 0
		? Math.min(requested, MAX_BASH_TIMEOUT_SECONDS)
		: MAX_BASH_TIMEOUT_SECONDS;
}
