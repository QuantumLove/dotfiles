---
title: "feat: Warp -CC tmux durability + reattach resilience"
status: superseded
superseded_by: docs/plans/2026-06-20-002-feat-warp-extension-tmux-remote-dev-plan.md
date: 2026-06-20
type: feat
depth: standard
---

> **⚠️ SUPERSEDED (2026-06-20).** Investigation established that the `-CC` wrapper this plan hardens is deprecated/frozen and the durability stack is broken in deeper ways than `-CC`. Replaced by `docs/plans/2026-06-20-002-feat-warp-extension-tmux-remote-dev-plan.md` (Warp SSH extension + plain tmux). Kept for history.

# feat: Warp -CC tmux durability + reattach resilience

## Summary

Warp's SSH integration wraps every mega-container session in a dedicated tmux server (`tmux -Lwarp -CC`, control mode). That gives native Warp blocks but silently breaks the durability features the dotfiles assume: tmux-continuum's auto-save never fires under control mode, the one backup cron is gone, and every persistence tool points at the *default* tmux socket while the real work lives on the `warp` socket. On top of that, dead control-mode clients reparent to PID 1 and pile up, so a long disconnect leaves Warp unable to cleanly reattach and the user's work stranded in an invisible numbered session.

This plan keeps Warp `-CC` (explicit user preference) and makes the `warp` socket durable: external resurrect auto-save on a reliable cron, pane-content capture for scrollback, an orphan/ghost-client reaper, and a recovery helper to re-enter stranded sessions. The Warp reattach bootstrap itself is Warp-internal and out of our control; the strategy is to make state fully durable and recovery one command, not to reverse-engineer Warp's reconnect.

> **⚠️ Decision required (surfaced by post-plan review + upstream research):** The `-CC` SSH tmux wrapper this plan hardens is **deprecated and frozen** per Warp's own docs ("will eventually be removed. Use the SSH extension instead"), and the reported sprawl symptom is **unfixable on it** (Warp runs `tmux -CC` with no `-A` and no session-name knob). The maintained "Warp future" path is the **SSH extension — which is already enabled** in `settings.toml`. This reopens the keep-`-CC` decision: harden a path with a removal clock (Plan A, below), or pivot to the extension + your own plain `tmux new-session -A -s main` (Plan B in *Alternatives Considered*), which is simpler, fixes the sprawl, and is the direction Warp is actually investing in. The rest of this document is written for Plan A; if you choose B it collapses to ~2 units.

---

## Problem Frame

**Observed by the user:** starting tmux inside a warpified SSH session warns about nesting; the session is somehow already inside tmux; after a long laptop-closed period, Warp shows "a long command" trying to resume that doesn't work, and work appears lost.

**Root causes (confirmed live on `raf-dev`):**

1. **Warp runs tmux for you.** `dot_warp/settings.toml.tmpl` sets `[warpify.ssh] use_ssh_tmux_wrapper = true`. Warp launches `tmux -Lwarp -CC` — a *separate* tmux server (socket `warp`) in *control mode* — so each tmux pane renders as a native Warp block. The user never started tmux; Warp did. Running `tmux` then nests (and targets the default socket).

2. **Auto-save is dead.** Latest resurrect save on the box is 11 days old while warp sessions are current. tmux-continuum triggers auto-save off the **status-line redraw**, which control mode (`-CC`) never performs. Structural incompatibility, not a config typo.

3. **The backup cron vanished.** `crontab -l` is empty; the custom `tmux-snapshot` cron (installed by `run_once_after_setup-snapshot-cron.sh`) did not survive a container rebuild. Snapshots in the dir are from April.

4. **Everything targets the wrong socket.** continuum/resurrect (via `dot_tmux.conf`) and `tmux-snapshot`/`tmux-restore` all default to the **default** socket. The user's interactive work is on the **`warp`** socket. Even if they ran, they'd save `tst`/`tst2`, not real work.

5. **Orphaned control-mode clients accumulate.** Live `ps` showed a `tmux -Lwarp -CC` process with **PPID 1**, 20 h old, not even a registered client — a zombie from an unclean disconnect. Transport is **Tailscale SSH** (`tailscaled be-child ssh`), so OpenSSH keepalive/reaping never applies. Sessions stay `attached=1` held by ghost clients, blocking clean reattach; Warp then spawns a fresh numbered session, stranding prior work.

---

## Requirements

- **R1** — tmux state on the `warp` socket auto-saves on a schedule that does not depend on the status line (continuum's broken trigger).
- **R2** — The auto-save cron is installed reliably on every container start and survives rebuilds.
- **R3** — Pane scrollback ("logs") is captured in saves and comes back on restore.
- **R4** — On `warp`-server start (e.g., after container restart), the latest save auto-restores.
- **R5** — Orphaned control-mode processes (PPID 1) and stale ghost clients are reaped so reconnect is clean and sessions don't sprawl.
- **R6** — A one-command recovery path exists to list and re-enter stranded `warp` sessions from any plain SSH shell.
- **R7** — No regression to the default-socket workflow or the existing OpenCode snapshot system; changes are scoped to the `warp` socket and additive.

---

## Key Technical Decisions

- **KTD1 — Keep Warp `-CC`; replace continuum's trigger, not the engine.** User wants native Warp blocks. tmux-resurrect (the save/restore engine) works fine when invoked directly; only continuum's *auto-save trigger* is dead under `-CC`. So we drive `resurrect/scripts/save.sh` from an external timer against `-L warp`, and keep `@continuum-restore on` (its restore hook fires on server start, which control mode does perform). **Gated by U0:** this rests on `-CC` behaviors we have not fully proven (continuum's save *not* firing, restore *firing* on server start, `run-shell` save working). U0 verifies all three before U1/U2/U5 are built. If continuum's restore hook proves `-CC`-incompatible, the fallback is an explicit `restore.sh` call from `entrypoint.sh` on warp-server start — symmetric with the external save timer (we should not asymmetrically trust restore while distrusting save under the same control mode).

- **KTD2 — Cron lives in `entrypoint.sh`, not a `run_once` script.** The `run_once` snapshot cron silently vanished across a rebuild (empty crontab confirmed). The entrypoint already starts `cron` (step 10b) and runs every boot, so installing the crontab there (idempotently) guarantees presence after every rebuild. Retire `run_once_after_setup-snapshot-cron.sh`.

- **KTD3 — Reaper kills only provably-dead clients.** Predicate: `tmux -Lwarp -CC` processes whose **PPID == 1** (reparented to init = no live connection) **AND** whose process age exceeds a floor (default 5 min). The age floor guards a **reconnect-reparent race**: during a Tailscale-SSH reconnect a control-mode client the user is actively reattaching to can be momentarily reparented to init before the new transport attaches; without the floor, a `*/10` reaper could fire inside that window and kill a live session. Age is a *guard*, never the sole signal — PPID==1 remains required (we never kill by age or activity alone). The predicate is a pure function tested against synthetic `ps` input (the reaper never runs live during tests), and a `--dry-run` flag lists targets without killing.

- **KTD4 — Dedicated, per-server resurrect dir for the warp workflow.** Set `@resurrect-dir` to a stable warp-scoped path so a default-socket continuum save can't clobber the warp save (resurrect uses one `last` pointer per dir). **Restore-side caveat:** because both servers source the same `dot_tmux.conf`, a *global* `@resurrect-dir` would also point the **default** server's `@continuum-restore` at the warp dir — so a plain `tmux` start could restore warp sessions into the default server (an R7 regression). Therefore scope the option to the warp server only — set `@resurrect-dir` via an `if-shell` keyed on `#{socket_path}` (or a warp-only sourced fragment), not globally. U0 confirms the socket-path test behaves under `-CC`.

- **KTD5 — Recovery uses plain-mode attach.** `warp-sessions` lists `tmux -L warp` sessions and attaches in *normal* mode (`tmux -L warp attach -t <name>`) from a plain SSH shell. This sidesteps Warp's control-mode reattach entirely — the guaranteed escape hatch when Warp's bootstrap flakes. Work is recovered, not lost.

- **KTD6 — Reattach bootstrap is explicitly out of scope to fix.** Warp's reconnect command is internal to the Warp client/SSH extension; no persisted bootstrap script exists on the remote to patch (confirmed: `~/.warp` holds only empty `launch_configurations`). We make state durable and recovery trivial instead. Documented as a known limitation.

---

## High-Level Technical Design

Two tmux servers coexist on the container; this plan hardens the `warp` one.

```mermaid
flowchart TB
    subgraph laptop["Laptop — Warp.app"]
        W[Warp client<br/>control-mode renderer]
    end
    subgraph net["Tailscale SSH"]
        T[tailscaled be-child ssh]
    end
    subgraph container["mega-container"]
        subgraph warpsrv["tmux server: socket 'warp' (-CC)"]
            S1[session 'webapp']
            S2[session '23' ...]
        end
        subgraph defsrv["tmux server: default socket"]
            D1[pulumi-preview, tst...]
        end
        CRON[cron]
        SAVE[tmux-warp-save<br/>resurrect save.sh on -L warp]
        REAP[tmux-warp-reaper<br/>kill PPID-1 -CC zombies]
        RDIR[(resurrect-warp dir<br/>+ pane contents)]
    end

    W -->|warpify SSH wrapper| T --> warpsrv
    CRON -->|every 5 min| SAVE --> RDIR
    CRON -->|every 10 min| REAP -.->|reaps| warpsrv
    warpsrv -->|@continuum-restore on server start| RDIR
    plain[Plain SSH + warp-sessions] -->|normal-mode attach, recovery| warpsrv
```

Save path: cron → `tmux-warp-save` → `tmux -L warp run-shell save.sh` → resurrect dir (with pane contents).
Restore path: warp server starts → continuum restore hook → reads resurrect dir.
Recovery path: Warp reattach flakes → user runs `warp-sessions` over plain SSH → normal-mode attach to the stranded session.

---

## Implementation Units

### U0. Verify `-CC` control-mode behavior (spike — gates U1/U2/U5)

**Goal:** Empirically confirm the control-mode assumptions the whole build rests on, *before* writing build units. De-risks A2 (continuum-save diagnosis), A3 (restore-on-start), and A6 (`run-shell` save).
**Requirements:** gating investigation for R1, R3, R4 (no new requirement).
**Dependencies:** none. **Blocks:** U1, U2, U5.
**Files:** none (investigation; record results inline here + `~/.local/state/tmux-warp/spike-notes.md` on the box).
**Approach:** On `raf-dev`, against a throwaway `tmux -L spike -CC` server (plus read-only checks on the live `warp` socket): (a) determine *why* continuum auto-save isn't firing — is the status line redrawing under `-CC`, is `@continuum-save-interval` unset (default), and which socket/dir the stale 11-day file actually belongs to; (b) confirm `tmux -L spike run-shell save.sh` produces a valid resurrect file *including* `pane_contents`; (c) `kill-server` then restart the `-CC` server and confirm `@continuum-restore on` restores on start.
**Decision gates:**
- (a) shows the cause is NOT the status-line mechanism (wrong dir / status disabled) → reconsider whether the external timer (U2) is the right fix or a config correction suffices.
- (b) fails → promote the A6 transient-plain-client fallback to a designed approach in U2 with its own tests.
- (c) fails → add an explicit `entrypoint.sh` `restore.sh`-on-start fallback (KTD1) instead of relying on continuum restore.
**Test scenarios:** Test expectation: none — investigation spike; output is recorded pass/fail findings that gate later units, not shippable code.
**Verification:** all three behaviors have a recorded pass/fail, and every failing gate has a chosen fallback, before U1/U2 begin.

### U1. Enable pane-content capture and a dedicated resurrect dir

**Goal:** Make saves include scrollback (R3) and isolate the warp save dir (KTD4).
**Requirements:** R3, R4.
**Dependencies:** U0.
**Files:** `dot_tmux.conf`.
**Approach:** Add `@resurrect-capture-pane-contents 'on'` and `@resurrect-pane-contents-area 'visible'` (bounds capture size). Set `@resurrect-dir` to a warp-scoped path under `~/.local/share/tmux/` — **scoped to the warp server only** via `if-shell` on `#{socket_path}` (or a warp-only sourced fragment) so the default server's restore isn't redirected (see KTD4). Confirm `@continuum-restore 'on'` stays. Leave continuum loaded — its restore-on-start hook is still wanted; only its save trigger is superseded by U2.
**Patterns to follow:** existing `@continuum-*` / `@resurrect-*` block in `dot_tmux.conf`.
**Test scenarios:**
- Config parse: `tmux -L test source-file` of a rendered config exits 0 with the new options set (`show-options -g` includes `@resurrect-capture-pane-contents on` and the dir).
- Covers R3: after a manual `save.sh` on a throwaway server with the config, the produced resurrect file directory contains a `pane_contents` archive.
**Verification:** rendered config loads cleanly; options visible via `show-options -g`.

### U2. `tmux-warp-save` — external resurrect save for the warp socket

**Goal:** Auto-save the `warp` server independent of the status line (R1).
**Requirements:** R1, R7.
**Dependencies:** U0, U1.
**Files:** `private_dot_local/bin/executable_tmux-warp-save`, `tests/bin/test_tmux-warp-save.sh`.
**Approach:** Bash script that (a) exports an explicit `PATH` (`$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/bin:/bin:$PATH`) up top, matching the repo's `fill-toggl-cron.sh` cron convention rather than relying on cron's minimal PATH; (b) checks a `warp` server exists (`tmux -L warp has-session`/`list-sessions`), exiting 0 quietly if not (cron-safe); (c) runs `tmux -L warp run-shell "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"`; (d) logs a line to `~/.local/state/tmux-warp/save.log`. Socket name overridable via arg/env for testability. No-op when no server — never errors under cron. (If U0 gate (b) failed, this unit instead drives the designed transient-plain-client fallback.)
**Patterns to follow:** existing `private_dot_local/bin/executable_tmux-snapshot` (exec-bit naming, log dir conventions); hook-style logging from `private_dot_claude/hooks/executable_hook-lib.sh.tmpl` (source; applied as `~/.claude/hooks/hook-lib.sh` — it's a chezmoi template, account for rendering if reusing).
**Test scenarios:**
- Happy path: start a throwaway `tmux -L <testsock>` server with one session + TPM resurrect available; run the script with that socket; assert exit 0 and a fresh resurrect save file appears in the configured dir.
- Edge — no server: run against a socket with no server; assert exit 0 and a "no warp server" log line, no error.
- Edge — server with zero sessions: assert graceful no-op.
**Verification:** invoking the script against a live warp socket produces a new timestamped resurrect file; cron invocation leaves a log line.

### U3. `tmux-warp-reaper` — kill orphaned control-mode clients

**Goal:** Reap PPID-1 `-CC` zombies and stale ghost clients (R5).
**Requirements:** R5.
**Dependencies:** none.
**Files:** `private_dot_local/bin/executable_tmux-warp-reaper`, `tests/bin/test_tmux-warp-reaper.sh`.
**Approach:** Factor the selection into a pure function `orphan_pids(ps_output, age_floor)` that, given `ps -eo pid,ppid,etimes,args` text, returns PIDs where `args` matches `tmux -Lwarp -CC` (or `-L warp -CC`) **and** `ppid == 1` **and** `etimes > age_floor` (default 300 s — beyond any reconnect-reparent window, see KTD3). The main path exports cron `PATH` (as U2), collects those PIDs, `kill`s them, logs each, and supports `--dry-run`. Conservative by construction: live clients have a live parent, and the age floor excludes mid-reconnect transients. Optionally also `detach-client` for clients whose tty no longer exists, but only if cheaply detectable; otherwise defer. Socket pattern + age floor overridable for tests.
**Patterns to follow:** pure-function-plus-thin-IO split used in `tests/hooks/test_no-diff-narration-comments.sh`'s tested logic.
**Test scenarios:**
- Happy path: synthetic `ps` with one PPID-1 `-CC` line aged above the floor and one PPID-1234 `-CC` line; assert `orphan_pids` returns only the aged PPID-1 PID.
- Age floor (reconnect-race guard): a PPID-1 `-CC` line aged *below* the floor is NOT selected; the same line aged *above* the floor IS selected.
- Edge — none orphaned: all `-CC` lines have live parents; assert empty result, no kills.
- Edge — unrelated tmux: `tmux -Lwarp` without `-CC`, and default-socket tmux; assert never selected.
- Safety: `orphan_pids` on empty input returns empty; main path performs zero kills when selection is empty (assert no `kill` invoked via a stubbed `kill`).
**Execution note:** test-first — the kill predicate is safety-critical; write `orphan_pids` tests before the script does any killing.
**Verification:** unit tests pass; a dry-run (`--dry-run` flag) on the live box lists exactly the known 20 h orphan and no live clients.

### U4. `warp-sessions` — recovery helper

**Goal:** One command to see and re-enter stranded warp sessions (R6).
**Requirements:** R6.
**Dependencies:** none.
**Files:** `private_dot_local/bin/executable_warp-sessions`, `tests/bin/test_warp-sessions.sh`.
**Approach:** `warp-sessions` with no args lists `tmux -L warp list-sessions` annotated with attached/created; `warp-sessions <name>` does `tmux -L warp attach -t <name>` in normal mode (works from any plain SSH). Friendly message when no warp server. Consider a `bashrc` alias for discoverability. **Nesting guard:** if the recovery shell is itself inside a tmux session (`$TMUX` set — possible since the default-socket server also exists on the box), a bare `attach` trips tmux's nesting refusal; detect `$TMUX` and either prepend `TMUX= ` or pass `-d`/`switch-client` so recovery never hits the very nesting error the plan cites as a root cause.
**Patterns to follow:** alias style in `dot_bashrc.tmpl` (`tm`); script conventions in `private_dot_local/bin/`.
**Test scenarios:**
- List: against a throwaway socket with 2 sessions, assert both names appear with attached state.
- Attach arg construction: assert the script invokes `tmux -L warp attach -t <name>` (verify via a stubbed `tmux` capturing argv).
- Edge — no server: assert a clear "no warp sessions" message, exit 0.
**Verification:** on the live box, `warp-sessions` lists `webapp`/`23`/`25`; attaching to one shows the stranded work in a normal tmux view.

### U5. Install save + reaper cron from `entrypoint.sh`

**Goal:** Reliable, rebuild-surviving cron (R2).
**Requirements:** R2.
**Dependencies:** U2, U3.
**Files:** `mega-container/entrypoint.sh`, `private_dot_local/bin/executable_tmux-warp-install-cron`, `tests/bin/test_tmux-warp-install-cron.sh`.
**Approach:** Extract the crontab-install logic into a dedicated, **testable** script `tmux-warp-install-cron` (marker-guarded: filter prior managed lines, then re-add — idempotent, and edits propagate). `entrypoint.sh` simply calls it after `cron` starts (step 10b), non-fatal (warn, don't `exit 1` — durability tooling must never block boot). This is deliberate: the exact failure mode that started this (a cron silently vanishing across rebuild) had no automated guard; moving the logic into a tested script gives it one. Managed entries: `*/5 * * * * $HOME/.local/bin/tmux-warp-save` and `2-59/10 * * * * $HOME/.local/bin/tmux-warp-reaper` — the reaper is **offset off the 5-min save tick** so save and reaper never coincide (addresses the cron-interleave risk).
**Patterns to follow:** marker-guard pattern in `run_once_after_setup-snapshot-cron.sh`; non-fatal warning style used by the `mega-doctor` call at end of `entrypoint.sh`.
**Test scenarios:** (logic now lives in `tmux-warp-install-cron`, so it's unit-testable against a stubbed `crontab`)
- Idempotency: run the installer twice; assert exactly the two managed entries after the second run (no duplicates).
- Preserve unrelated entries: seed an unrelated crontab line; run installer; assert it survives and only managed lines are rewritten.
- Edit propagation: change a managed entry's schedule, re-run; assert the new schedule replaces the old managed line.
- Marker scoping: assert the filter matches only managed lines (an unrelated comment containing `tmux-warp` is not stripped).
- Entrypoint wiring itself remains integration-verified.
**Verification:** after a rebuild, `crontab -l` shows exactly the two managed entries (no duplicates after multiple boots).

### U6. Retire the stale snapshot `run_once` and document

**Goal:** Remove the dead cron installer and record the new model (R7, durability docs).
**Requirements:** R7.
**Dependencies:** U5 (file committed; live validation not required to unblock U6 — the deletion is safe once U5's crontab entries are in the repo).
**Files:** delete `run_once_after_setup-snapshot-cron.sh`; update `mega-container/README.md` (or `TROUBLESHOOTING.md`) with a short "tmux durability under Warp -CC" section covering the two servers, the recovery command, and the bypass/limitations.
**Approach:** Since cron now lives in `entrypoint.sh` (U5), the `run_once` is redundant and was already non-functional. Removing it avoids two systems fighting over the crontab. Document the OpenCode snapshot system as a separate, still-default-socket concern deferred to follow-up.
**Patterns to follow:** existing doc tone in `mega-container/README.md`.
**Test scenarios:** Test expectation: none — deletion + docs.
**Verification:** repo has no `run_once_*snapshot*`; README documents `warp-sessions` and the durability model.

---

## Assumptions

- **A1** — Warp's wrapper invokes `tmux -Lwarp -CC` and reuses one `warp` socket per container (confirmed via live `ps` and `~/.tmux/sockets/tmux-501/warp`). If a future Warp version changes the socket name or flags, U2–U4's socket constant needs updating (single point of change).
- **A2** — The `-Lwarp` server sources `~/.tmux.conf` like any tmux server, so TPM/resurrect plugins and `@resurrect-*` options apply there (confirmed: `show-options -g` on the warp socket shows `@continuum-restore on` and resurrect script paths).
- **A3** — `@continuum-restore on` actually restores on a fresh `tmux -Lwarp -CC` server start. *Unproven — gated by U0.* The option is set and continuum's restore hook is server-start-based (not status-line-based), but this is the same class of "what does `-CC` trigger" claim as the save diagnosis; we must not asymmetrically trust restore while distrusting save. U0 verifies it before U1/U2 build; failure adds the entrypoint `restore.sh`-on-start fallback (KTD1).
- **A4** — PPID == 1 is a reliable "dead control-mode client" signal on this container's init (the container runs without a full init that re-parents differently). Confirmed by the observed 20 h PPID-1 orphan. If the container later runs under an init that reaps zombies, the reaper simply finds fewer targets (still safe).
- **A5** — cron runs in the container (confirmed: `entrypoint.sh` starts `cron`; `cron` daemon present). Cron's minimal env is sufficient because the scripts use absolute `$HOME` paths and call tmux by absolute plugin path.
- **A6** — resurrect's `save.sh`/`restore.sh` work when invoked via `run-shell` on a `-CC` server (control mode doesn't block `run-shell`). *Unproven — gated by U0.* If `run-shell` misbehaves under `-CC`, the transient-plain-client fallback is promoted from a one-line risk note to a designed approach with its own tests (rather than shipping an undesigned fallback as the real implementation).
- **A7** — Pane-content capture size is acceptable on the persistent volume; bounded via `@resurrect-pane-contents-area visible` if it grows too large.

---

## Test Strategy

**Layer 1 — Hermetic unit tests (laptop, no container).** For U2/U3/U4, mirror the existing `tests/hooks/` approach: temp `$HOME`, throwaway tmux servers on a test socket, stubbed `tmux`/`kill`/`ps` where behavior must be asserted without side effects. The reaper's `orphan_pids` is pure and fully table-tested against synthetic `ps` input — it never kills during tests. Runner returns non-zero on any failure. Place under `tests/bin/` (already `.chezmoiignore`d).

**Layer 2 — Rendered-config check.** Render `dot_tmux.conf` (via `chezmoi execute-template` or direct, since it has no template directives) and load it on a test socket to confirm the new `@resurrect-*` options parse and are set.

**Layer 3 — Live integration on `raf-dev` (read-mostly, then controlled).**
1. Apply changes (hot-patch chezmoi + copy scripts), confirm `crontab -l` shows the two managed entries with no duplicates after a second boot/apply.
2. Run `tmux-warp-save` manually against the real `warp` socket; confirm a fresh resurrect file with pane contents.
3. Run `tmux-warp-reaper --dry-run`; confirm it selects exactly the known PPID-1 orphan and zero live clients; then run for real and confirm the orphan is gone and live sessions untouched.
4. `warp-sessions` lists `webapp`/`23`/`25`; attach to a numbered session over plain SSH and confirm stranded work is visible.

**Layer 4 — Restore acceptance (the real goal).**
- Controlled: kill the `warp` server (`tmux -L warp kill-server`) after a save, reconnect via Warp, confirm `@continuum-restore` brings sessions/panes/scrollback back.
- Real-world: close the laptop overnight, reconnect next day; confirm either Warp reattaches or `warp-sessions` recovers the session with no lost work.

**Regression guard:** confirm the default-socket sessions (`pulumi-preview`, `tst`) and the OpenCode snapshot files are untouched (R7).

---

## Alternatives Considered

**A — This plan: keep `-CC`, add durability + recovery machinery.** Preserves native Warp blocks. Cost: a cron, several new scripts, and a safety-critical reaper that exist *specifically* to work around control-mode limitations — a standing maintenance surface whose worst failure (reaper killing live work) is this plan's highest risk.

**B — Switch to Warp's SSH extension + run your own plain-mode tmux.** Set `use_ssh_tmux_wrapper = false` (the extension, `ssh_extension_install_mode = "always_install"`, is *already enabled*), and run `tmux new-session -A -s main` yourself via `~/.ssh/config` `RemoteCommand` or a remote shell alias. Eliminates root cause #2 (status line renders → continuum auto-save works natively), #4 (one server), #5 (no `-CC` orphans), AND the numbered-session sprawl (idempotent `-A -s main` reattach). Deletes U2, U3, U5, and the reaper entirely. Cost: tmux panes are drawn by tmux, not as native Warp blocks inside the session.

**The decision is now reopened by the upstream findings.** When `-CC` was chosen, we didn't know the wrapper is **deprecated and frozen** — and that native Warp blocks for tmux panes exist *only* on that frozen path. So "Warp is the future for me" actually points at **B**: the SSH extension is Warp's recommended, maintained direction; the `-CC` wrapper is the past Warp is removing. Plan A hardens a path with a removal clock on it, and still can't fix the reported sprawl symptom (no `-A`, no knob). This is a user decision — see the Summary callout.

### Upstream findings (Warp issue tracker)

Research confirms this is a known, structural problem — and that the wrapper we're hardening is **officially deprecated**.

- **The wrapper is deprecated and frozen.** Warp's own docs ([ssh-legacy](https://docs.warp.dev/terminal/warpify/ssh-legacy)) state the tmux-based Warpification "is deprecated, will not receive new features, updates, or fixes, and will eventually be removed. Use the SSH extension instead." The replacement — `ssh_extension_install_mode` — installs a remote binary instead of wrapping in `tmux -CC`, sidestepping the entire `-CC` lifecycle. **Your `settings.toml` already has `ssh_extension_install_mode = "always_install"` set alongside `use_ssh_tmux_wrapper = true`.**
- **Numbered-session sprawl — root cause confirmed.** Warp's wrapper runs `tmux -CC` **without `-A` and without a pinned session name**. iTerm2 (the reference `-CC` implementation) uses `tmux -CC new-session -A -s main` — attach-or-create against a fixed name, so reconnect is idempotent. Warp omits both, so every reconnect spawns a fresh numbered session ([discussion #501](https://github.com/warpdotdev/Warp/discussions/501), [iTerm2 docs](https://iterm2.com/documentation-tmux-integration.html)).
- **No knob to pin the session name.** The legacy wrapper is a single on/off toggle — no `tmux_session_name`, no `-A` option. So the sprawl / "work appears lost" symptom **cannot be fixed via Warp settings on this path**. This kills the deferred auto-attach item *as long as the wrapper is in use*.
- **Reconnect failure is filed.** [#3230](https://github.com/warpdotdev/Warp/issues/3230) (open): after an SSH disconnect the tab gets stuck and only a new tab recovers — matches "the long command that doesn't resume." The "SSH Warpify Timeout" cluster ([#6080](https://github.com/warpdotdev/Warp/issues/6080) et al.) shows the bootstrap runs `check_tmux && command $TMUX -CC && exit` — a control-mode handshake failure emits `%exit` and kills the session.
- **Ghost clients after network drop** are a known tmux control-mode lifecycle issue (iTerm2 community: [thread](https://groups.google.com/g/iterm2-discuss/c/pQhjsdIh4zQ)); mitigation there is `ServerAliveInterval` keepalive + force-detach before reattach.
- **continuum under `-CC`** ([tmux-continuum #40](https://github.com/tmux-plugins/tmux-continuum/issues/40)): the status-right-driven auto-save is suspected-but-not-confirmed broken under control mode — vindicating U0's "verify, don't assume" gate.
- **Community escape hatch:** disable `use_ssh_tmux_wrapper`, run your own `tmux new-session -A -s main` (via `~/.ssh/config` `RemoteCommand` or remote shell). Stable reattach, working continuum, no ghost clients — at the cost of per-pane Warp blocks inside tmux.

**Implication for this plan:** the `-CC` path we're hardening is the deprecated one, and the headline symptom (numbered-session sprawl on reconnect) is unfixable on it by design. Native Warp blocks for tmux panes — the whole reason to keep `-CC` — exist *only* on this frozen wrapper. This materially changes the keep-`-CC`-vs-extension decision; see the callout in the Summary and Open Questions.

---

## Post-Implementation Experience & Known Limitations

Honest accounting of what this plan does and does **not** fix for the *reported* symptom ("after a long disconnect, work appears lost"):

- **Fixed:** if the `warp` tmux server dies (container restart, crash), state auto-restores (R4) with scrollback (R3); and stranded work is always recoverable in one command (`warp-sessions`, R6). No more silent loss.
- **NOT auto-fixed:** in the common lived case the server is *alive* and your sessions still exist — Warp spawns a *new numbered session* on reconnect instead of reattaching, so prior work looks lost until you run `warp-sessions`. The durability machinery doesn't change that; it makes recovery instant and lossless, not automatic.
- **The actual fix** for the reported symptom is pinning Warp to reattach one stable session (killing the numbered-session sprawl at root). Whether that's possible hinges on a Warp-side knob — under investigation (see Upstream findings). **If a knob exists, promote it from deferred into this plan**; if not, `warp-sessions` is the supported recovery path, and this limitation is stated deliberately rather than hidden.

---

## Scope Boundaries

**In scope:** durability + recovery for the `warp` socket — pane capture, external auto-save cron, orphan reaper, recovery helper, reliable cron install, doc.

### Deferred to Follow-Up Work
- **Fix the OpenCode `tmux-snapshot`/`tmux-restore` system** to target the `warp` socket (currently default-socket, cron gone). Separate, richer feature (resumes OpenCode sessions by ID); not what the user asked for here.
- **Auto-attach Warp to a single stable named session** (reduce numeric-session sprawl) — depends on whether Warp exposes a session-name knob; needs Warp-side investigation.
- **Faster dead-connection reaping at the transport layer** (Tailscale SSH keepalive tuning) — would reduce orphan creation rather than clean up after it.

### Out of scope (cannot fix from our side)
- **Warp's reattach bootstrap** ("the long command that doesn't resume") — internal to the Warp client/SSH extension; no remote script to patch (KTD6). Mitigated by durable state + `warp-sessions`.

---

## Risks & Dependencies

- **Risk — reaper kills a live client.** Mitigation: **PPID-1 AND age>5min** predicate (the age floor guards the reconnect-reparent race) + `--dry-run` + unit tests + `kill` stub tests. Highest-severity item; treated test-first (U3 execution note).
- **Risk — save/reaper crons interleave.** Mitigation: reaper offset (`2-59/10`) off the save tick so they never coincide (U5); even if they did, the reaper only targets PPID-1 processes and never the save's transient client.
- **Risk — whole restore path rests on unproven `-CC` behavior (A3/A6).** Mitigation: U0 gates the build on empirical verification; each failing gate has a defined fallback. If U0 invalidates the core premise (A2), the plan reduces to a config correction rather than the full machinery.
- **Risk — `run-shell` save misbehaves under `-CC`.** Mitigation: A6 fallback (transient plain-mode client to run save). Confirm in Layer 3.
- **Risk — resurrect dir clobbering between servers.** Mitigation: dedicated `@resurrect-dir` (KTD4); only warp auto-saves.
- **Risk — cron env too minimal.** Mitigation: absolute paths everywhere; log to a file for diagnosis.
- **Dependency:** TPM plugins installed on the container (confirmed present). Container must be running to integration-test.

---

## Sources & Research

- Live container probes on `raf-dev` (2026-06-20): process tree showing `tmux -Lwarp -CC` (incl. PPID-1 orphan), `tmux -L warp list-sessions/list-clients`, empty `crontab -l`, stale resurrect/snapshot files, `@continuum-restore on` on the warp socket, TPM plugins present.
- `dot_warp/settings.toml.tmpl` — `[warpify.ssh] use_ssh_tmux_wrapper = true`.
- `dot_tmux.conf` — continuum/resurrect config, `update-environment`.
- `mega-container/entrypoint.sh` — cron start (10b), boot sequence.
- `run_once_after_setup-snapshot-cron.sh`, `private_dot_local/bin/executable_tmux-snapshot|tmux-restore` — existing (broken) snapshot system.
- tmux-continuum behavior: auto-save is driven by the status-line interval (incompatible with `-CC` control mode, which doesn't redraw the status line).
