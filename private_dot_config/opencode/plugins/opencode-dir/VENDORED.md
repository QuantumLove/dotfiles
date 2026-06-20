# opencode-dir (vendored)

This is a **vendored, telemetry-stripped copy** of [`opencode-dir`](https://github.com/adiled/opencode-dir),
an opencode plugin that adds `/cd`, `/mv`, and `/add-dir` commands so a session can change its
working directory without losing context. We use it so `/setup-work` on opencode can move the
session into a worktree (the equivalent of Claude Code's `EnterWorktree` tool).

## Why vendored (don't just `"plugin": ["opencode-dir"]`)

- **Supply chain.** Upstream is a single-maintainer project (~17 stars at time of vendoring). A bare
  npm reference auto-fetches whatever the account publishes. Pinning a reviewed copy in our own repo
  removes that exposure. opencode plugins run in-process with full shell/file access, so the bar is high.
- **It phoned home.** Upstream sends caught errors to a hardcoded Sentry DSN and runs an npm
  self-update check. Both are removed here (see below).

## Pinned source

- Repo: https://github.com/adiled/opencode-dir (MIT)
- Version: **v1.0.10**
- Commit: `a42cfdd9d46b39db7d003677612705df4ba45627`
- Vendored: 2026-06-20

Only `index.ts` and `lib.ts` are vendored (the package's published `files`). The session-DB logic uses
`bun:sqlite` and reads/writes opencode's own session database; the `/cd` mechanism is pure opencode
hooks (`tool.execute.before`, `shell.env`, `experimental.chat.system.transform`) — no network.

## Local changes vs upstream

All changes are clearly commented in the source with "REMOVED in this vendored copy":

- **`lib.ts` — Sentry removed.** `SENTRY_DSN`, the envelope builder, the `fetch()` to
  `*.ingest.us.sentry.io`, and the version-reader it used are gone. `reportError()` is now a no-op
  (kept and still exported so the catch blocks compile; errors still surface as opencode toasts).
- **`lib.ts` — self-update removed.** `checkForUpdate()` and its `UpdateResult` type (which fetched
  `registry.npmjs.org` and deleted files in opencode's plugin cache) are gone.
- **`index.ts` — update-check call removed**, and `checkForUpdate` dropped from the imports.
- **`index.ts` — agent-callable `cd` tool ADDED (not upstream).** A `tool: { cd }` entry in the
  returned hooks lets the model change the session directory itself (Claude Code `EnterWorktree`
  parity for `/setup-work`) instead of only the human `/cd` command. It reuses the same
  `applyMove()`/override mechanism as the command. **Re-apply this when re-vendoring.**

Net result: **the plugin makes zero network calls.** Verify with:

```bash
grep -nE 'fetch\(|sentry|registry\.npmjs|\.ingest\.' index.ts lib.ts   # → only comments
```

## How to upgrade

Periodically (e.g. when touching opencode tooling) check whether upstream has something worth pulling:

1. Diff our pin against upstream `main`:
   `gh api repos/adiled/opencode-dir/commits/main --jq .sha` — compare to the commit above.
2. If you want the new version, re-vendor `index.ts` + `lib.ts`, then **re-apply the removals and the
   `cd` tool addition above** (search upstream for `SENTRY_DSN`, `checkForUpdate`, and `fetch(`; and
   re-add the `tool: { cd }` block + `applyMove` helper).
3. Re-run the verify grep, bump the version/commit/date in this file, `chezmoi apply`, and restart opencode.

Treat any upstream change that adds a network call or new broad permission as a reason to re-review
before adopting.
