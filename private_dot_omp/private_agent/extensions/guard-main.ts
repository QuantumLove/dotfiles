import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { isAbsolute, join, resolve } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

/**
 * Rule 1 for omp: the primary worktree stays pristine.
 *
 * Third of three adapters. Git has no pre-edit hook, so rules 2 and 3 can be
 * enforced once for everyone in a git hook while rule 1 needs one adapter per
 * agent surface. All three shell out to the same engine rather than
 * reimplementing policy — the point of the exercise is one definition, not
 * three that agree today.
 *
 * Blocks writes to TRACKED files in the primary worktree. Untracked and
 * gitignored paths stay writable; scratch files never enter a commit, so
 * blocking them buys nothing and makes the guard something to route around.
 *
 * Engine exit codes: 0 allow, 2 block, 3 policy unreadable. A missing policy
 * means the guard is disarmed, which the assertion suite reports — this lets
 * the write through rather than blocking everything on a config problem.
 */

const GUARD = join(homedir(), ".local", "bin", "git-main-guard");

// omp's two file mutators do not agree on a shape. `write` takes {path, content};
// `edit` takes one DSL string whose per-file blocks open with a [path#HASH]
// header, the path relative to the session cwd. Reading only a `path` key sees
// the first and is blind to the second, which is the whole edit surface.
const EDIT_HEADER = /^\[([^\]\n#]+)#[0-9A-Za-z]+\]$/gm;

function targetPaths(toolName: string, input: Record<string, unknown> | undefined): string[] {
	if (toolName === "write") {
		const v = input?.path;
		return typeof v === "string" && v ? [v] : [];
	}
	if (toolName === "edit") {
		const dsl = input?.input;
		if (typeof dsl !== "string") return [];
		// One edit call can carry blocks for several files; any one of them
		// landing in the primary checkout is enough to refuse the call.
		return [...dsl.matchAll(EDIT_HEADER)].map((m) => m[1]);
	}
	return [];
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event: any, ctx: any) => {
		const targets = targetPaths(event.toolName, event.input);
		if (targets.length === 0) return;

		const base = typeof ctx?.cwd === "string" && ctx.cwd ? ctx.cwd : process.cwd();

		for (const target of targets) {
			const abs = isAbsolute(target) ? target : resolve(base, target);
			try {
				execFileSync(GUARD, ["edit", "--path", abs], { stdio: "pipe" });
			} catch (err: any) {
				// Only 2 is a verdict. A missing engine or an unreadable policy is
				// not this extension's call to turn into a refusal.
				if (err?.status !== 2) continue;
				const reason =
					String(err?.stderr ?? "").trim() ||
					"blocked: the primary worktree must stay pristine — use a worktree";
				return { block: true, reason };
			}
		}
	});
}
