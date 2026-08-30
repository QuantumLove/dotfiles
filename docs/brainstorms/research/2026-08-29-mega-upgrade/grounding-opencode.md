# Grounding: oc/opencode sessions, cross-dir view, cd plugin

Investigated on the macOS host (`~/.local/share/chezmoi`), which does NOT have
`opencode`/`omp` installed — those only exist inside the mega-container. `oc`
wrapper behavior was reproduced by sourcing the real function; underlying
`opencode` binary calls could not run here (noted per item).

## Problem 1 — `oc sessions list` is broken

**Root cause: wrong subcommand, twice.**

- `oc` is a bash function, not a binary (`dot_bash_functions:14-53`). It
  special-cases only `ps` and `history` (`:15-17`); anything else — including
  `sessions` — falls through to `opencode --port 0 "$@"` (`:48-52`).
- Reproduced on host (`source dot_bash_functions; oc sessions list`):
  `oc:39: command not found: opencode` — no opencode binary here
  (container-only). The `trap...RETURN` warning above it is a sourcing
  artifact of this host, not a real `.bashrc` bug.
- Upstream opencode has no `sessions` command. Source
  (`gh api repos/sst/opencode/.../src/cli/cmd/session.ts`): the command is
  **`session`** (singular), subcommands `list` (`--max-count/-n`,
  `--format table|json`) and `delete`. Correct invocation:
  `opencode session list`. So `oc sessions list` fails two ways: (a) `oc`
  doesn't intercept `sessions`, passing it straight to `opencode`, and (b)
  `sessions` (plural) was never valid upstream either.
- `oc history` (`dot_bash_functions:94-129`) is the intended replacement —
  reads sqlite directly rather than shelling to `opencode session list`.
  Confirms the sqlite hint: commit `180bb49` (`fix(mega): add sqlite3 for oc
  history support`) adds `sqlite3` to the Dockerfile + entrypoint hard-fail,
  precisely because `_oc_sessions()` runs `sqlite3 -json "$db" "$query"`.
- **Fix**: teach `oc` to intercept `sessions`→`history`, or retrain to
  `oc history` / `opencode session list`.

## Problem 2 — no cross-directory session view

**Root cause: `session list` is hard-scoped to the current project; a global
list method exists in the service layer but nothing calls it.**

- Storage: one sqlite DB, not per-project files. `getDbPath()` (vendored
  `opencode-dir/lib.ts`) resolves `${XDG_DATA_HOME:-~/.local/share}/opencode/opencode.db`
  — same path used by `dot_bash_functions:104` and
  `private_dot_local/bin/executable_opencode-prune:9`. Directory doesn't
  exist on this host (opencode never run here); schema is fully visible via
  `opencode-prune`'s DELETEs: tables `session` (id, directory, title,
  time_created/updated ms, parent_id), `message`, `part`, `todo`,
  `session_share`, `session_message`, `session_input`,
  `session_context_epoch`.
- CLI source (`.../src/session/session.ts`) confirms the scoping:
  `list(input)` always calls `listByProject(db, { projectID: ctx.project.id,
  ...input })`, and `listByProject` puts `eq(SessionTable.project_id,
  input.projectID)` as its first, unconditional filter — no CLI flag
  overrides it.
- A **`listGlobal(input?: GlobalListInput)`** method exists in the same file
  (queries `session` with zero project filter — only optional `directory`,
  `roots`, `start`, `cursor`, `search`, `archived`) — exactly the needed
  query. It is **not wired to the CLI** (`session.ts` cmd only calls
  `svc.list`) nor the HTTP API (`server/routes/instance/httpapi/handlers/session.ts`
  only `.handle("list", list)`; `handlers/global.ts` is unrelated
  config/installation). Dead/unused capability today.
- What already does the right query: `_oc_sessions()`
  (`dot_bash_functions:94-129`) selects from `session` with **no** directory
  filter — already a full cross-project view, just unlabeled as such.
  `opencode-prune` does the same for pruning.
- **Fix path**: no upstream flag to reach for; keep reading `opencode.db`
  directly (as `oc history` already does) — add a `--by-dir` grouping or a
  longer default window. Fixing it upstream would mean wiring `listGlobal`
  into the CLI/API.

## Problem 3 — the cd plugin

**What it is:** `opencode-dir`, vendored at
`private_dot_config/opencode/plugins/opencode-dir/{index.ts,lib.ts}`, loaded
via `private_dot_config/opencode/opencode.json.tmpl:5`
(`file://{env:HOME}/.config/opencode/plugins/opencode-dir/index.ts`).
Upstream `github.com/adiled/opencode-dir` v1.0.10, pinned/stripped per
`.../opencode-dir/VENDORED.md`. Adds `/cd`, `/mv`, `/add-dir` TUI commands
plus a vendor-added agent-callable `cd` tool (`index.ts:88-113`) for
`/setup-work` parity with Claude Code's `EnterWorktree`.

**What it actually changes (agent-side only — `index.ts:231-273`):**
writes a `{sessionID:{oldDir,newDir}}` override to
`opencode-dir-overrides.json` + the session row in `opencode.db`; then
`tool.execute.before` injects `newDir` as default `workdir`/`path` for
`bash`/`glob`/`grep`; `shell.env` overrides `PWD` for spawned tool
processes; `experimental.chat.system.transform` rewrites the system
prompt's "Working directory:" line. **It never touches the real OS process
tree** — the tmux pane's actual login shell keeps its original cwd; only
opencode's tool-dispatch layer is redirected (`bash cd` inside a tool call
still doesn't persist across calls, per the tool's own description).

**omp extension system — confirmed viable host for an equivalent.** Docs:
`docs/extensions.md`, `docs/custom-tools.md`, `docs/hooks.md` (`gh api
repos/can1357/oh-my-pi/contents/docs/...`). Two integration points: a
**custom tool** (`CustomToolFactory`: `(pi) => ({name, parameters,
execute(toolCallId, params, onUpdate, ctx, signal)})`, `pi.cwd`/`pi.exec(cmd,
args,{cwd})`) — direct analog of opencode-dir's `tool:{cd}` block; and an
**extension** (`export default (pi: ExtensionAPI) => { pi.on(event,
handler); pi.registerTool/registerCommand }`) with `tool_call`/`tool_result`
interception and session lifecycle events (`session_start`,
`session_switch`, ...) — the same hook points opencode-dir uses. Concrete
example, `sjawhar/dotfiles:omp/extensions/session-env.ts` (fetched in full):
```ts
export default function (pi: ExtensionAPI) {
  const set = (_event, ctx) => {
    const id = ctx.sessionManager?.getSessionId?.()
    if (id) process.env.OMP_SESSION_ID = id
  }
  pi.on("session_start", set); pi.on("session_switch", set); pi.on("session_branch", set)
}
```
Right shape to port from: hook `session_start`/`session_switch`, keep a
per-session dir-override map (mirroring `dirOverrides`), register a `cd`
custom tool. No existing omp port of opencode-dir found — would be a
from-scratch build, same agent-side-only scope.

**tmux part — hard constraint:** a child process cannot chdir() its parent
shell; nothing a plugin does in-process retroactively moves the pane's login
shell. Mechanisms and trade-offs:

| Mechanism | Does | Trade-off |
|---|---|---|
| `tmux respawn-pane -k -c <dir>` | Kills pane's process, restarts shell in `<dir>` | Kills the very agent process you're redirecting (it *is* the foreground process). Only viable once the agent has exited. |
| `tmux send-keys "cd <dir>" Enter` | Injects keystrokes into the pane | Only reaches the shell if it's the foreground stdin reader. While the TUI owns the tty, keys go to the TUI, not the shell. Fine for syncing a *different*, shell-only pane. |
| `tmux set-option -p @custom_cwd <dir>` + shell precmd/`PROMPT_COMMAND` hook | Non-destructive pane-scoped var; shell hook `cd`s on read | Only fires once the shell regains control (after the agent exits) — same timing as exit-hooks below, but tmux-visible to other tooling (status line, split logic) meanwhile. |
| `tmux attach-session -c <dir>` / `switch-client -c <dir>` | Sets session default path for **future** windows/panes | Doesn't touch the existing pane; only affects `new-window`/`split-window` calls without their own `-c`. |

**Recommendation**: the only non-destructive path for the *current* pane is
deferred-until-exit — write the target dir to a file/tmux option (same
pattern as `OC_REGISTRY/$$.json` + `session-registry.ts`), then extend the
`oc()`/future `omp()` wrapper's existing `trap ... RETURN`
(`dot_bash_functions:35`) to `cd` when the agent exits — the "cd on quit"
pattern used by `broot`/`ranger`. Live mid-session pane-follow isn't
achievable without killing the pane or racing `send-keys` against the TUI.
