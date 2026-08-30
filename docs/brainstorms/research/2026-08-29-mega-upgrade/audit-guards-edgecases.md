# Adversarial edge-case audit: don't-touch-main guardrails

Builds on `grounding-guards.md`. Findings ranked by severity. V=verified by direct
test (crafted hook payload / scratch repo in `/tmp`, read-only), R=reasoned from
code inspection only.

## HIGH severity

### 1. [FN, V] allow-chezmoi-push.sh trusts stale session cwd, not the command's real target
Trigger: session/tool cwd is inside chezmoi, but the Bash command itself `cd`s
elsewhere before pushing, e.g. `cd ~/code/other-repo && git push origin main`.
Verified: crafted a PreToolUse payload with `cwd=$HOME/.local/share/chezmoi` and
`tool_input.command="cd /tmp/guard-test/repo && git push origin main"` (a
non-chezmoi repo) — the hook emitted `permissionDecision:"allow"` anyway.
Why: `allow-chezmoi-push.sh` computes `repo_root` from `.cwd` only —
`cwd="$(jq -r '.cwd // ""' ...)"` then `git -C "$cwd" rev-parse --show-toplevel`
— it never parses the command string for an embedded `cd`. Any compound command
run while the ambient cwd happens to be chezmoi gets the chezmoi override
applied to whatever repo the command actually touches, overriding the global
push-to-main deny for an unrelated repo.

### 2. [FN, R] Literal-string deny patterns miss every implicit push-to-main form
Trigger: `git push` (branch already tracks `origin/main`), `git push origin
HEAD`, `git push --all`, `git -C <path> push origin main`, a shell alias, or a
wrapper script that pushes.
Why: the global deny is `"Bash(git push origin main*)"` /
`"Bash(git push origin master*)"` — prefix/glob matching on the literal command
text. None of the forms above start with that literal string, so they don't
hit the deny. `git -C ...` and aliases don't even start with `git push`, so
they also miss the generic `"Bash(git push *)"` ask bucket — they fall through
to whatever the harness's default Bash permission is, with no branch-aware
signal at all. `git push`/`git push origin HEAD` do hit the generic ask bucket,
but that's an approvable prompt, not a hard block, for a command that is
functionally identical to the denied one.

### 3. [FN, V] opencode/omo agents in the mega-container have zero wiring to any guard
Trigger: any bash command run by an opencode/omo agent (sisyphus, oracle, etc.)
inside the mega-container — Rafael's own documented daily workflow.
Verified: `private_dot_config/opencode/opencode.json.tmpl` and
`dot_omo/omo.jsonc` contain no `permission`/deny/ask keys at all, and no
reference to `git-main-guard` or any hook script; `private_dot_config/opencode/AGENTS.md`
(opencode's CLAUDE.md equivalent) has zero mentions of main/push/commit safety —
`grep -n -i "main\|push\|commit"` returned nothing. The comment in
`git-main-guard` claiming it's "shared... with the opencode claude-code-hooks
bridge" describes a bridge that does not exist anywhere in the chezmoi source.
Every protection in the grounding doc (settings.json deny, both PreToolUse
hooks, git-main-guard) is Claude-Code-specific. Running the identical task
through opencode/omo against the identical repos is a complete, sanctioned,
frequently-used bypass of the entire guard system — not an obscure edge case.

### 4. [FN, R] Detached HEAD permanently disarms the checkout guard
Trigger: primary worktree's HEAD becomes detached (verified reachable state:
`git checkout --detach main` from main is itself correctly blocked, but the
worktree can still end up detached via a bypass, a raw git command outside the
harness, or any other agent per #3). Once detached, `git checkout -b
<anything>` is unconditionally allowed.
Why: `current_branch()` returns "" on detached HEAD, and the checkout mode's
guard is `case "$br" in main|master) ;; *) exit 0 ;; esac` — empty string hits
the wildcard and the function returns before ever calling
`command_moves_head`. There is no re-arm path other than manually getting back
onto a branch literally named `main`/`master`.

## MEDIUM severity

### 5. [FN, R] Guard only recognizes branches literally named "main" or "master"
Trigger: a repo whose default branch is `trunk`, `develop`, or anything else,
checked out in the primary worktree.
Verified: created a scratch repo, renamed default branch to `trunk`, set a
non-allowlisted remote, ran `git-main-guard checkout` with a HEAD-moving
command — exit 0 (allowed) unconditionally, because
`case "$br" in main|master) ;; *) exit 0 ;; esac` treats any non-`main`/`master`
branch as "already off main, allow recovery," never asking whether that branch
*is* the repo's real default.

### 6. [FP, R] allow-chezmoi-push.sh matches by hardcoded path, not remote slug
Trigger: pushing chezmoi's main from any clone at a path other than the exact
literal `$HOME/.local/share/chezmoi` — a fresh reclone, a renamed directory, or
a copy made from inside the mega-container workspace (`~/code/...`).
Why: `case "$repo_root" in "$HOME/.local/share/chezmoi"|"$HOME/.local/share/chezmoi"/*)`
is a pure path match. `git-main-guard`'s edit/checkout protections use
`repo_is_allowlisted()`, which matches by *origin remote slug* and would still
recognize the relocated clone — but the push-allow hook has no such fallback,
so the global push-to-main deny fires with no override, forcing Rafael to push
by hand even though CLAUDE.md says chezmoi pushes to main are fine. (Confirms
and generalizes the grounding doc's glove80 gap: the path-vs-slug mismatch
isn't glove80-specific, it also breaks for chezmoi itself under relocation.)

### 7. [FN, R] No branch check on non-git write paths (GitHub API / MCP)
Trigger: `mcp__github__push_files`, `mcp__github__create_or_update_file`, or
`gh api repos/:owner/:repo/contents/...` targeting `branch: "main"` — none of
these invoke a local `git push`, so no hook or deny pattern ever sees them.
Why: every mechanical control here is a Bash-command-string or local-git
check. settings.json only gates `mcp__github__create_*` behind "ask" (generic,
not branch-aware); `push_files` isn't even in that list. A model that decides
to write straight to `main` via the API sidesteps deny rules, both PreToolUse
hooks, and git-main-guard simultaneously, with no branch-name gate anywhere in
the chain.

## LOW severity

### 8. [FN, known/restated] Commit-on-main has no mechanical check anywhere
`git commit` on `main` in any non-chezmoi repo is gated only by the generic
`"Bash(git commit *)"` ask entry — approvable, not branch-aware. CLAUDE.md
prose is the only thing naming this rule; no hook inspects current branch
before a commit. Low severity only because it requires the agent (or Rafael)
to affirmatively approve the "ask" prompt with a bad commit in flight.

### 9. Non-findings worth recording (guard is more robust than expected here)
- Symlinked access to chezmoi (`ln -s ~/.local/share/chezmoi /tmp/link`) still
  resolves correctly — `git rev-parse --show-toplevel` canonicalizes the path
  before either hook compares it, so no bypass. Verified.
- Different `$HOME` (mega-container's `/home/rafaelcarvalho` vs host's
  `/Users/rafael`): all guard scripts reference `$HOME` dynamically, no
  hardcoded `/Users/rafael/...` found in any hook, `git-main-guard`, or
  `modify_settings.json`. Should work identically in-container. Verified via
  `grep -rn "/Users/rafael"` — no matches in the guard sources.
- No-remote-at-all and case-differing/`.git`-suffixed/HTTPS-vs-SSH remote URLs
  all normalize correctly in `git-main-guard` (verified) and fail closed (not
  allowlisted) rather than open.
- A linked worktree with `main` checked out is correctly excluded from
  "primary worktree" (verified via `git-common-dir` comparison) — by design,
  not a gap, since the actual push-to-main deny is worktree-agnostic.

## Priority read
#1 and #3 are the most actionable: #1 is a live logic bug in a hook that
actively *grants* permission (not just fails to deny), and #3 means the whole
system is opt-in per-tool rather than per-repo — anyone (including future
Rafael in a hurry inside the container) reaching for opencode instead of
Claude Code gets no safety net at all.
