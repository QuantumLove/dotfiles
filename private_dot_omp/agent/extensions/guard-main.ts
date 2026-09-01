import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
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
const WRITE_TOOLS = new Set(["write", "edit", "multiedit", "apply_patch", "patch"]);

function targetPath(input: Record<string, unknown> | undefined): string | undefined {
	for (const key of ["path", "filePath", "file"]) {
		const v = input?.[key];
		if (typeof v === "string" && v.length > 0) return v;
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event: any) => {
		if (!WRITE_TOOLS.has(event.toolName)) return;
		const target = targetPath(event.input);
		if (!target) return;

		try {
			execFileSync(GUARD, ["edit", "--path", target], { stdio: "pipe" });
		} catch (err: any) {
			// Only 2 is a verdict. A missing engine or an unreadable policy is
			// not this extension's call to turn into a refusal.
			if (err?.status !== 2) return;
			const reason =
				String(err?.stderr ?? "").trim() ||
				"blocked: the primary worktree must stay pristine — use a worktree";
			return { block: true, reason };
		}
	});
}
