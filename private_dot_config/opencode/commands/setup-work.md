---
description: Set up (or re-enter) an isolated worktree, cd into it, then STOP — or run through to a draft PR with --go. Never makes a duplicate worktree for a branch.
---

You are running `/setup-work` on opencode. Arguments: `$ARGUMENTS`

This is the opencode twin of the Claude Code `setup-work` skill. Same behavior; the only platform
difference is HOW you change directory:

- Claude Code uses the native `EnterWorktree` tool.
- **opencode: call the `cd` tool from the vendored `opencode-dir` plugin** with the absolute worktree
  path. It moves the session the same way `/cd` does (same session, no context loss), but you invoke
  it yourself — do that, don't ask the user. (The `/cd` slash command still exists for humans; only
  fall back to printing a `/cd <abs-path>` line if the `cd` tool isn't available.)

Current worktrees (for the reuse check below):
!`git worktree list --porcelain 2>/dev/null`

## Guarantees

- **Never two worktrees for one branch.** Use the `git worktree list --porcelain` output above; if the
  target branch already has a worktree, `/cd` into that one — do not create a duplicate.
- **PR review / existing branches never get a fresh branch.** Check that branch out; do not `-b` a new one.

## Steps

1. **Parse args + flags.** `--go` anywhere → autonomous mode (step 6); strip it first. Then classify
   the rest to get target **branch**, **base ref**, whether it's **existing** (PR/branch) or **new**,
   and an optional **Linear issue id**:
   - Linear ID (`PLT-456`, `SEC-89`) / URL → look it up (Linear MCP). New branch `ISSUE-ID/slug`, base `origin/main`.
   - GitHub PR URL / `PR 1234` / "review the X PR" → `gh pr view` for the head branch. Existing branch; base `origin/<pr-branch>`. Link any Linear ref in the PR.
   - Branch name (slug or contains `/`) → existing branch. Check Linear for a matching issue; link if found.
   - Free text → ask: create a Linear issue, or quick experiment (`quick/<slug>`)? Only create on confirmation. New branch.
   - Empty → ask what to work on.
2. **Refuse setup-on-main.** If asked to edit the main checkout directly, decline and set up a worktree instead.
3. **Reuse check.** `git fetch origin`. If the branch already has a worktree (from the list above),
   `/cd` into it and go to step 5.
4. **Create the worktree** at `.worktrees/<safe-name>` under the repo root (`<safe-name>` =
   branch with `/`→`-`). Ensure `.worktrees/` is gitignored (`git check-ignore`; add + commit if not).
   - New branch: `git worktree add .worktrees/<safe-name> -b <branch> origin/main`
   - Existing branch (PR/branch): fetch it, then `git worktree add .worktrees/<safe-name> <branch>` (no `-b`)
   Then `/cd <abs-path-of-worktree>` to move the session in.
5. **Default: report and STOP.** Print the worktree path, branch, and linked issue, confirm you've
   cd'd in (or print the `/cd` line for the user), and stop. The user continues from inside the worktree.
6. **`--go` only:** after the cd, do the work end-to-end (implement, verify, commit on the feature
   branch, push), then **open the PR by running the `/pr-create` command** — do not hand-roll
   `gh pr create`. `/pr-create` is the single source of truth and opens a **draft, self-assigned**
   PR by default (it runs `gh pr create … --assignee @me ${READY:---draft}`). Never merge. If you
   lack context or hit a real decision point, stop and ask.

## Hard rules

- Worktrees only — never branch/commit in the main checkout.
- Always do the reuse check before creating; one worktree per branch, ever.
- PR review / existing branch → check that branch out, never `-b` a new one.
- Never create a Linear issue without explicit confirmation.
- Default stops after the cd; only `--go` continues, and only as far as a draft, self-assigned PR.
