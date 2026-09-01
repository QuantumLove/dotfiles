import { isAbsolute, resolve } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

/**
 * An agent-callable `cd` for omp, matching what opencode-dir provides.
 *
 * omp already ships `/move`, which is strictly better for the human case: it
 * relocates the process and re-scopes settings, skills and commands. But there
 * is no extension API to invoke it — ExtensionCommandContext has no move and
 * sessionManager is read-only — so an agent cannot use it, and /setup-work needs
 * an agent-callable equivalent.
 *
 * So this redirects tool arguments instead, the same way opencode-dir does:
 * bash takes an explicit `cwd`, glob and grep take `path`. The session's real
 * cwd is untouched; only what the tools operate on moves.
 *
 * The override is per-session and in-memory. omp re-execs itself for subagents,
 * so persisting it would leak a directory across unrelated work.
 */

const overrides = new Map<string, string>();

function sessionKey(ctx: any): string {
	return String(ctx?.sessionId ?? ctx?.sessionID ?? "default");
}

export default function (pi: ExtensionAPI) {
	const z = pi.zod;

	pi.registerTool({
		name: "cd",
		label: "Change working directory",
		description:
			"Change the directory this session's tools operate in. Affects bash, " +
			"glob, grep, read and write. Use an absolute path.",
		parameters: z.object({ path: z.string().describe("absolute path") }),
		async execute(_id: string, params: { path: string }, _signal: unknown, _onUpdate: unknown, ctx: any) {
			overrides.set(sessionKey(ctx), params.path);
			return { content: [{ type: "text", text: `Tools now operate in ${params.path}` }] };
		},
	});

	pi.on("tool_call", async (event: any, ctx: any) => {
		const dir = overrides.get(sessionKey(ctx));
		if (!dir) return;

		const input = { ...(event.input ?? {}) };
		switch (event.toolName) {
			case "bash":
				// Only when absent. omp's bash tool already extracts a leading
				// `cd <path> &&` into cwd, and overwriting an explicit value
				// would fight that rather than complement it.
				if (input.cwd == null) input.cwd = dir;
				else return;
				break;
			case "glob":
			case "grep":
				// These take a directory to search under.
				if (input.path == null) input.path = dir;
				else return;
				break;
			case "read":
			case "write":
				// These take a path TO a file, so an absent value is not the
				// signal — a relative one is. omp resolves it against the
				// session cwd, which this tool deliberately does not move, so
				// without rebasing here a relative read misses the file the
				// agent just changed directory to reach.
				if (typeof input.path === "string" && input.path && !isAbsolute(input.path)) {
					input.path = resolve(dir, input.path);
				} else return;
				break;
			default:
				return;
		}
		return { input };
	});
}
