import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

/**
 * Publish the agent's working directory to a pane-scoped tmux option.
 *
 * A child process cannot change its parent shell's directory, so tmux's
 * pane_current_path goes stale the moment an agent moves — and the path-copy
 * binding then reports where the shell was, not where the work is. Rather than
 * fighting that, the agent publishes where it actually is and the binding
 * prefers it, falling back to pane_current_path when nothing is set.
 *
 * Harness-agnostic on purpose: every agent that can run a shell command can do
 * this, so no per-tool plugin API is load-bearing.
 */

const PANE = process.env.TMUX_PANE;
const OPTION = "@agent_cwd";

export default function (pi: ExtensionAPI) {
	if (!PANE) return; // not inside tmux; nothing to publish to

	let last = "";

	const publish = async (dir: string | undefined) => {
		if (!dir || dir === last) return;
		last = dir;
		try {
			await pi.exec("tmux", ["set-option", "-p", "-t", PANE, OPTION, dir]);
		} catch {
			// tmux server gone, or the pane closed. Not worth failing a session over.
		}
	};

	const clear = async () => {
		try {
			await pi.exec("tmux", ["set-option", "-p", "-t", PANE, "-u", OPTION]);
		} catch {}
	};

	// Subagents share the parent process and their lifecycle events fire
	// process-wide, so without this guard a subagent's start would overwrite the
	// pane with a directory the user never navigated to.
	const isTopLevel = (ctx: any): boolean => {
		const file = ctx?.sessionManager?.getSessionFile?.();
		if (!file) return false;
		return /\d{4}-\d{2}-\d{2}T[\d-]+Z_[0-9a-f-]{36}\.jsonl$/.test(String(file));
	};

	const onSession = async (_event: unknown, ctx: any) => {
		if (!isTopLevel(ctx)) return;
		await publish(ctx?.cwd);
	};

	// The triad that covers every way a session's directory can change.
	pi.on("session_start", onSession);
	pi.on("session_switch", onSession);
	pi.on("session_branch", onSession);

	// /move relocates the process without emitting a cwd event — there is no
	// such event in the API — so the current directory is re-read each turn.
	pi.on("turn_start", async (_event: unknown, ctx: any) => {
		if (!isTopLevel(ctx)) return;
		await publish(ctx?.cwd);
	});

	pi.on("session_shutdown", clear);
}
