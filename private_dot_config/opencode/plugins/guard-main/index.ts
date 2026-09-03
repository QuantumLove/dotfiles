import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Rule 1 for OpenCode: the primary worktree stays pristine.
 *
 * This is the adapter git-main-guard's header has claimed existed since before
 * it did. Git has no pre-edit hook, so the rule cannot be enforced the way rules
 * 2 and 3 are — it needs one adapter per agent surface, and each one delegates
 * to the same engine rather than reimplementing policy.
 *
 * Blocks writes to TRACKED files in the primary worktree. Untracked and
 * gitignored paths stay writable: scratch files never enter a commit, so
 * blocking them buys nothing and would make the guard something to work around.
 *
 * Exit codes from the engine: 0 allow, 2 block, 3 policy unreadable. A missing
 * policy means the guard is disarmed, which the assertion suite reports — the
 * plugin lets the operation through rather than blocking every write on a
 * config problem.
 */

const GUARD = join(homedir(), ".local", "bin", "git-main-guard");

// Tools whose arguments name a path the agent is about to write.
const WRITE_TOOLS = new Set(["write", "edit", "patch", "multiedit"]);

function pathFromArgs(args: Record<string, unknown>): string | undefined {
  for (const key of ["filePath", "path", "file"]) {
    const v = args?.[key];
    if (typeof v === "string" && v.length > 0) return v;
  }
  return undefined;
}

export const GuardMain = async ({ client }: { client?: any }) => {
  return {
    "tool.execute.before": async (
      input: { tool: string },
      output: { args: Record<string, unknown> },
    ) => {
      if (!WRITE_TOOLS.has(input.tool)) return;
      const target = pathFromArgs(output.args);
      if (!target) return;

      try {
        execFileSync(GUARD, ["edit", "--path", target], { stdio: "pipe" });
      } catch (err: any) {
        // 2 is a deliberate block; anything else (including a missing engine)
        // is not this plugin's business to turn into a refusal.
        if (err?.status !== 2) return;
        const reason = String(err?.stderr ?? "").trim() ||
          "blocked: the primary worktree must stay pristine";
        await client?.tui
          ?.showToast({ body: { title: "guard-main", message: reason, variant: "error" } })
          .catch(() => {});
        throw new Error(reason);
      }
    },
  };
};

export default { id: "guard-main", server: GuardMain };
