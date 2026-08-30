# Grounding: guardrails against commits/pushes to main

## Mechanical enforcement chain (Claude Code hooks + settings.json)

**Chezmoi source:** `/Users/rafael/.local/share/chezmoi/private_dot_claude/modify_settings.json`
**Applied:** `/Users/rafael/.claude/settings.json`

Global deny (settings.json, blocks unconditionally, no prompt):
- `modify_settings.json:139-142` / `settings.json:82-85`
  ```
  "Bash(git push origin main*)",
  "Bash(git push origin master*)",
  "Bash(git push --force*)",
  "Bash(git push -f *)",
  ```

Global ask (settings.json, prompts every time, model can request):
- `modify_settings.json:92-99` / `settings.json:107-114`
  ```
  "Bash(git commit *)",
  "Bash(git push *)",
  "Bash(git pull *)",
  "Bash(git merge *)",
  "Bash(git rebase *)",
  "Bash(git reset *)",
  "Bash(git checkout *)",
  "Bash(git switch *)",
  ```
  Note: `git commit` has **no branch check** — commit-on-main is only "ask", not "deny", at the settings.json layer.

Hook wiring (`modify_settings.json:164-191`, identical in applied `settings.json:151-178`):
```
"PreToolUse": [
  { "matcher": "Edit|Write|MultiEdit|NotebookEdit",
    "hooks": [{"command": "$HOME/.claude/hooks/guard-no-main-edits.sh"}] },
  { "matcher": "Bash",
    "hooks": [
      {"command": "$HOME/.claude/hooks/guard-no-main-checkout.sh"},
      {"command": "$HOME/.claude/hooks/allow-chezmoi-push.sh", "if": "Bash(git push*)"}
    ]}
]
```

### `guard-no-main-edits.sh` / `guard-no-main-checkout.sh`
`/Users/rafael/.claude/hooks/guard-no-main-edits.sh:1-9`, `guard-no-main-checkout.sh:1-9` — thin adapters calling shared core:
> "Blocks Edit/Write/MultiEdit/NotebookEdit when the target file is a tracked file in the PRIMARY (main) checkout... Allowlisted repos (main edits expected): chezmoi dotfiles, QuantumLove/glove80."
These guard **editing/checkout in the primary worktree**, not commit/push directly.

### `/Users/rafael/.local/bin/git-main-guard` (shared core, `private_dot_local/bin/executable_git-main-guard`)
- Lines 33-36 — allowlist:
  ```
  ALLOW_REMOTES=(
      "QuantumLove/dotfiles"
      "QuantumLove/glove80"
  )
  ```
- Line 20: bypass via `export ALLOW_MAIN_EDITS=1` (or `CLAUDE_ALLOW_MAIN_EDITS=1`)
- Lines 22-26: scope disclaimer — "file protection covers the Edit/Write tools, not arbitrary shell writes... not a security boundary."
- This binary does **not** intercept `git commit`/`git push` at all — only `edit` and `checkout` modes (lines 168, 209).

### `allow-chezmoi-push.sh` — the actual push-to-main override
`/Users/rafael/.claude/hooks/allow-chezmoi-push.sh:1-9,31-37`:
> "re-allows `git push` in the chezmoi dotfiles repo, overriding the global deny... Force-pushes are never re-allowed."
```
case "$repo_root" in
    "$HOME/.local/share/chezmoi"|"$HOME/.local/share/chezmoi"/*)
        printf '...permissionDecision":"allow"...chezmoi dotfiles repo: pushes to main are expected per CLAUDE.md"}}'
```
**Hardcoded to the chezmoi path only** — does not check remote slug, does not cover glove80.

## Prose-only enforcement (CLAUDE.md)

`/Users/rafael/.local/share/chezmoi/private_dot_claude/CLAUDE.md.tmpl:101-123` (applied verbatim at `/Users/rafael/.claude/CLAUDE.md`):
```
### Never commit or push to main/master
- NEVER run `git commit` while on the `main` or `master` branch
- NEVER run `git push` to `main` or `master` (directly or implicitly)
- NEVER run `git push --force` or `git push -f` on any branch
...
### Exceptions
- Chezmoi/dotfiles repo (`~/.local/share/chezmoi`): Direct commits to main are OK — this is a personal dotfiles repo
- If the user explicitly says "commit to main"... you may proceed — but confirm first
```
This is the **only** place the "never commit on main" rule (as opposed to push) is stated — no hook checks current branch before `git commit`.

## Gap found: glove80 exception is inconsistent across layers
- Mentioned in `guard-no-main-edits.sh.tmpl:8`, `guard-no-main-checkout.sh.tmpl:6`, and `git-main-guard:35` (ALLOW_REMOTES).
- **Absent** from CLAUDE.md.tmpl's prose Exceptions section (only chezmoi is listed there, line 122).
- **Absent** from `allow-chezmoi-push.sh`, which only re-allows push for the literal chezmoi path — so even if glove80 were checked out, `git push origin main` there would still hit the global deny (`settings.json:82-85`) since nothing re-allows it.

## Findings (1-4)

1. **Mechanical vs. prose:** Both exist, but they cover different actions. Push-to-main is mechanically enforced (deny rule + one repo-scoped allow hook). Commit-on-main is prose-only in CLAUDE.md — no hook inspects branch before `git commit`. `git-main-guard` mechanically blocks *edits* and *checkout* in the primary worktree of any repo (not just main-push), independent of the CLAUDE.md prose.

2. **Where the dotfiles exception lives:** Stated in prose at `CLAUDE.md.tmpl:122`. Mechanically encoded in two places: `git-main-guard` ALLOW_REMOTES (`QuantumLove/dotfiles`, matched by origin remote slug) and `allow-chezmoi-push.sh` (matched by hardcoded path `~/.local/share/chezmoi`, not remote slug). The push-allow hook is a mechanical guard that *can* and *does* read a version of this exception — but only for chezmoi, and by path not slug, so it wouldn't survive a reclone to a different path.

3. **glove80 repo:** Not present locally. No `~/code/glove80` directory (referenced only in `docs/plans/2026-06-21-*.md` and `docs/manual-setup.md:35-37` as a future/external checkout). Confirmed on GitHub as `QuantumLove/glove80` (repo exists, `gh api` returned a 404 "Branch not protected" rather than repo-not-found).

4. **Branch protection:** Checked both identifiable remotes via `gh api repos/:owner/:repo/branches/main/protection`:
   - `QuantumLove/dotfiles`: `{"message":"Branch not protected", "status":"404"}`
   - `QuantumLove/glove80`: `{"message":"Branch not protected", "status":"404"}`
   Neither repo has GitHub-side branch protection on `main`. No `core.hooksPath` set globally or in chezmoi repo; chezmoi's `.git/hooks/` contains only default `.sample` files (no active pre-commit/pre-push hook).
