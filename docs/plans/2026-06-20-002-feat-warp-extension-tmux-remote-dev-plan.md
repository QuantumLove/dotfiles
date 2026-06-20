---
title: "feat: Warp SSH extension + plain-tmux remote dev (durability, history, notifications)"
status: completed
date: 2026-06-20
type: feat
depth: deep
origin: docs/brainstorms/2026-06-20-warp-extension-tmux-remote-dev-requirements.md
deepened: 2026-06-20
---

# feat: Warp SSH extension + plain-tmux remote dev (durability, history, notifications)

## Summary

Retire Warp's deprecated `-CC` tmux wrapper and rebuild the mega-container remote-dev workflow on the **Warp SSH extension + plain tmux**. The current durability stack is empirically broken (continuum auto-save self-disables under multiple tmux servers; `restore.sh` crashes; cron silently vanishes on rebuild), so this plan **fixes the engine, drives saves from supercronic (flock-serialized), and proves the whole loop with a verification harness built first**. It adds painless session helpers, makes tmux scrollback + opencode history readable/restorable, and routes agent notifications through a terminal-bell side-channel (ntfy deferred to the roadmap). See origin: `docs/brainstorms/2026-06-20-warp-extension-tmux-remote-dev-requirements.md`.

---

## Problem Frame

Remote dev runs on the mega-container over Warp + Tailscale SSH, currently on the deprecated `-CC` wrapper (`use_ssh_tmux_wrapper = true`). Investigation (this session) established: the wrapper is frozen and spawns numbered sessions on every reconnect; continuum auto-save never wires up because `continuum.tmux` self-disables when more than one tmux server runs (always true here) **and** its status-line trigger only fires while a client is attached; `restore.sh` crashes the server even in isolation; the container's cron is unreliable (chezmoi `run_onchange` doesn't re-fire on rebuild + ephemeral spool); and Warp's native agent notifications don't survive tmux+SSH. The save *engine* (`save.sh`) works. The goal is a maintained setup where durability/history/notifications work and are verified, not assumed.

---

## Requirements (origin trace)

- **R1** — Warp SSH extension; retire `-CC` wrapper. **Conditional:** "retire `-CC`" is delivered unconditionally; "extension engages" is contingent on A-DEP1 (may resolve to documented non-delivery over Tailscale SSH). → U2
- **R2** — Plain tmux is the persistence layer. → U2, U3
- **R3** — Painless session create/attach helpers, nesting-safe. → U3
- **R4** — Durable saves via supercronic (flock-serialized), not continuum auto-save. → U5
- **R5** — Fix resurrect restore (currently crashes); restore window/pane layout + contents. → U4
- **R6** — Keep the opencode-aware custom snapshot/restore. → U6
- **R7** — Readable/restorable tmux scrollback + opencode history; address `opencode.db` bloat. → U4 (pane capture), U6
- **R8** — Agent notifications via bell side-channel. → U7
- **R9** — Container-native scheduling (supercronic); incidental fill-toggl cron repair. → U5, U8
- **R10** — Verification harness implementing AE1–AE8, built first as the gate. → U1
- **R11** — Durability artifacts survive rebuilds (persistent volume + reliable reinstall). → U4, U5

---

## Key Technical Decisions

- **KTD1 — Extension over `-CC`** (origin KD1/KD4). Flip `use_ssh_tmux_wrapper = false`; keep `ssh_extension_install_mode = "always_install"`. The wrapper is deprecated; the extension is UX-only (no persistence) so tmux owns durability. **Two-host apply:** `dot_warp/settings.toml.tmpl` only renders on macOS, so the cutover applies on the *laptop* (then restart Warp); raf-dev is only the observation point.
- **KTD2 — Drive saves from supercronic alone, flock-serialized** (origin KD2; revised post-review). continuum auto-save self-disables (`continuum.tmux main()` wires the hook only `if ! another_tmux_server_running`) **and** its status-right mechanism fires only while a client is attached — useless for the detached/rebuild case that matters. So no status-right hook: run resurrect's working `save.sh` from **supercronic** on a cadence, wrapped in **`flock`** on a shared lockfile so it never races a manual save or an overlapping run. (continuum's multi-server guard existed precisely to prevent that concurrent-writer corruption of the single resurrect dir; a single named socket does **not** prevent it — `flock` does.)
- **KTD3 — Fix restore by updating the TPM plugins; treat the path as unproven until verified.** resurrect (`cff343c`, 2023) and continuum (`0698e8f`, 2024) are stale against tmux 3.3a and `restore.sh` crashes. `run_onchange_install-tpm.sh.tmpl` only *installs* missing plugins, never updates — so extend it to update-on-change (or pin to known-good tags). **The restore path is unproven until OQ1 is resolved in U4.** If the plugin update doesn't turn AE5 green, the fallback (`tmux-restore`, U6) must be extended to reproduce window/pane **layout + contents**, not just opencode session IDs, before R5 is considered met.
- **KTD4 — supercronic as the scheduler, launched supervised with restart** (origin KD3). Not systemd (replaces tini, heavy), not crontab-spool (ephemeral). supercronic reads a chezmoi-managed crontab file and runs as a long-lived foreground process started from `entrypoint.sh`. Because **tini reaps but does not restart** children, wrap the launch in a small restart loop so a supercronic crash doesn't silently stop all saves.
- **KTD5 — Single named socket `work`, injected via env var** (origin OQ3). All interactive work lives on `tmux -L work`. The socket name comes from a `WARP_TMUX_SOCKET` env var (default `work`) read by the helpers, the save wrapper, supercronic, and `tmux-snapshot`/`tmux-restore`, so every consumer targets the same server. This keeps the save/restore target unambiguous; it does **not** prevent concurrent writes (KTD2/flock does).
- **KTD6 — Bell side-channel for notifications** (origin KD5). Claude Code + opencode notification hooks emit a **plain terminal bell** (`\a`); `monitor-bell on` + `bell-action any` surface it to Warp. A bare BEL traverses tmux natively — **no DCS-wrapping** (that's for OSC sequences like 777 and would break the monitor-bell path). ntfy phone-push is deferred to `TODO.md`.
- **KTD7 — Harness first, as the gate** (origin KD6/R10). U1 ships before the fixes and defines "done" for U4–U7. To avoid confirmation-shaped tests, AE5's pass criterion is a **pre-recorded known-good session graph**, not "whatever `restore.sh` emits."

---

## High-Level Technical Design

Two layers, cleanly separated: the **Warp SSH extension** provides UX (blocks, completions, file tree) and owns nothing persistent; **plain tmux on the single named `work` socket** is the persistence layer. Saves are driven by supercronic (flock-serialized); restore + history read from a persistent-volume resurrect dir.

```mermaid
flowchart TB
    subgraph laptop["Laptop / phone — Warp"]
        WC[Warp client + SSH extension UX]
    end
    subgraph net["Tailscale SSH"]
        T[tailscaled ssh]
    end
    subgraph container["mega-container (tini PID 1)"]
        subgraph srv["tmux server — socket 'work'"]
            S1[session: a]
            S2[session: b ...]
        end
        SUPER[supercronic (supervised, restart-looped)]
        SAVEW[tmux-save: flock + save.sh]
        SNAP[tmux-snapshot — opencode IDs]
        RDIR[(resurrect dir + pane contents\npersistent volume)]
        OCDB[(opencode.db / storage)]
        BELL[agent notify hooks → plain BEL]
    end

    WC --> T --> srv
    SUPER -->|periodic, flock-serialized| SAVEW --> RDIR
    SUPER -->|periodic| SNAP --> RDIR
    srv -->|@continuum-restore on start| RDIR
    SNAP -.->|opencode session IDs| OCDB
    BELL -->|BEL through tmux, monitor-bell| WC
```

Save: supercronic runs `tmux-save` (flock + `save.sh`) on a cadence — the single writer of record, covering attached and detached. Restore: on server start (`@continuum-restore on`) or manual → `restore.sh` (fixed) + custom `tmux-restore` for opencode sessions. History: tmux scrollback (captured by resurrect) + opencode history (`opencode.db`).

---

## Implementation Units

### U1. Verification harness (the spine)

**Goal:** A runnable test + guided-manual checklist implementing AE1–AE8; built first, used to verify U4–U7.
**Requirements:** R10.
**Dependencies:** none.
**Files:** `tests/integration/test_tmux_durability.sh`, `tests/integration/MANUAL-CHECKLIST.md`.
**Approach:** The harness is a **source-tree runner** (it lives under `tests/`, which is `.chezmoiignore`d and therefore intentionally NOT deployed to the container). It runs from the laptop and **SSHes into raf-dev** to drive the on-box parts on a throwaway named socket (the same pattern used during investigation). It: creates N sessions, runs a couple of opencode commands, runs `tmux-snapshot`, asserts snapshot artifacts (windows/panes + opencode session IDs), asserts history readable (scrollback present; opencode history queryable), captures a **pre-recorded known-good session graph**, kills the server, runs restore, and asserts the restored graph matches the pre-recorded one (not "whatever restore emits"). Non-automatable parts (real disconnect/reconnect; agent bell reaching Warp) go in the guided checklist. The script is the gate: it fails against today's broken stack — that's expected and is how we measure U4–U7.
**Patterns to follow:** the SSH-driven verification scripts used in this session's investigation; hermetic-harness style in `tests/hooks/test_no-diff-narration-comments.sh`.
**Test scenarios:**
- Covers AE1: helper creates 2–3 sessions on the throwaway socket; each is listed and attachable.
- Covers AE2/AE3: opencode commands run; `tmux-snapshot` output contains expected windows/panes + opencode session IDs.
- Covers AE4: scrollback shows prior output; opencode history shows the commands.
- Covers AE5: pre-record session graph → kill server → restore → restored graph matches the pre-recorded one (layout + panes + opencode sessions + pane-contents).
- Covers AE8: after a simulated re-apply/rebuild, supercronic is running and the crontab present (checked over SSH).
- Self-check: runs end-to-end on a throwaway socket without touching the real `work` socket; cleans up.
**Verification:** harness runs green end-to-end once U2–U7 land; today it runs and reports the known failures.

### U2. Cut over to the Warp SSH extension; retire `-CC`

**Goal:** Use the extension; stop spawning the deprecated `-CC` wrapper. Resolve A-DEP1 (does the extension engage over Tailscale SSH?) early — it gates whether R1's affirmative half is achievable.
**Requirements:** R1, R2.
**Dependencies:** none.
**Files:** `dot_warp/settings.toml.tmpl`.
**Approach:** Set `use_ssh_tmux_wrapper = false` (keep `ssh_extension_install_mode = "always_install"`). **Two-host:** this file renders only on macOS, so apply on the laptop and restart Warp; raf-dev is the observation point. Then verify whether the extension's `remote-server` installs/engages over Tailscale SSH (currently absent — likely a transport bypass). If it does not engage, record the finding + fallback (Warp blocks apply only to the interactive shell; tmux still provides everything else) — this does not block the rest of the plan since durability is tmux-owned.
**Patterns to follow:** existing `[warpify.ssh]` block in `dot_warp/settings.toml.tmpl`.
**Test scenarios:**
- Covers AE7 (partial): after apply + reconnect, no new `tmux -Lwarp -CC` process is spawned.
- A-DEP1: `~/.warp*/remote-server` exists after a Warp SSH connect, OR the Tailscale-SSH-bypass finding + fallback is documented.
**Verification:** new Warp SSH sessions are warpified without `-CC`; A-DEP1 resolved (engages, or documented non-delivery).

### U3. Painless session helpers

**Goal:** Short, nesting-safe commands to create a new session and to list/attach existing ones, on the `work` socket (KTD5).
**Requirements:** R2, R3.
**Dependencies:** none.
**Files:** `dot_sh_functions.tmpl`, `tests/bin/test_session_helpers.sh`.
**Approach:** Add a short session-helper family that reads `WARP_TMUX_SOCKET` (default `work`) and always passes `-L "$WARP_TMUX_SOCKET"`: create-or-attach by name (`new-session -A -s <name>`), a no-arg lister/picker, attach-by-name. Nesting guard: if `$TMUX` is set, use `switch-client`/`TMUX=` so it works from inside another session. Keep names short (the verbosity complaint is the point). Mirror the `tm` alias intent in `dot_bashrc.tmpl`.
**Patterns to follow:** `tm` alias + shell-function conventions in `dot_sh_functions.tmpl` / `dot_bashrc.tmpl`.
**Test scenarios:**
- Happy: create a named session → exists on the `work` socket; attach an existing one.
- Idempotent: create-or-attach twice with the same name → one session, second call attaches (`-A` semantics).
- Covers AE7: detach, then re-invoke the attach helper → reattaches the SAME session, no new numbered session created (no sprawl).
- List/pick: lister shows all sessions on the socket with attached state.
- Nesting guard: invoked with `$TMUX` set → uses switch/`TMUX=` instead of erroring on nested attach.
- Edge: no server yet → create path works from cold.
**Verification:** harness AE1 + AE7 (reconnect, no sprawl) pass using these helpers.

### U4. Repair the durability engine (restore + pane capture + persistent dir)

**Goal:** Make `restore.sh` reliable (layout + pane contents); put the resurrect dir on a persistent volume.
**Requirements:** R5, R7, R11.
**Dependencies:** U1 (harness verifies the fix).
**Files:** `.chezmoiscripts/run_onchange_install-tpm.sh.tmpl`, `dot_tmux.conf`, `mega-container/docker-compose.yml`.
**Approach:** Extend the TPM script to **update** plugins (not just install missing) — `update_plugins all` or pin resurrect/continuum to known-good tags — to fix the restore crash against tmux 3.3a (KTD3). In `dot_tmux.conf`: `@resurrect-capture-pane-contents 'on'`, `@resurrect-pane-contents-area 'visible'`, and `@resurrect-dir` on a persistent-volume path. Add a Docker volume mount for that dir in `docker-compose.yml` (mirroring `opencode-snapshots`). Confirm the exact restore-crash cause during implementation (OQ1).
**Execution note:** gate on the harness restore scenario (AE5) going red→green. **Decision gate:** if the plugin update does NOT turn AE5 green, scope a layout+pane-content restorer (extending `tmux-restore`, U6) before declaring R5 met — opencode-session resume alone is not sufficient.
**Patterns to follow:** existing `@resurrect-*`/`@continuum-*` block in `dot_tmux.conf`; the `opencode-snapshots` volume in `mega-container/docker-compose.yml`.
**Test scenarios:**
- Covers AE5: save then kill-server then restore → restored session graph matches the pre-recorded one without the server exiting.
- Pane contents: restored panes show prior scrollback (capture-pane-contents on).
- Persistence: resurrect dir survives a container rebuild (volume-backed).
- Regression: restore no longer emits "server exited unexpectedly".
**Verification:** harness AE5 green; `restore.sh` exits 0 and repopulates layout + panes.

### U5. supercronic save scheduler (flock-serialized)

**Goal:** Saves happen reliably from a single supervised scheduler, serialized so they never corrupt the resurrect dir.
**Requirements:** R4, R9, R11.
**Dependencies:** U4 for the full save+restore cycle; **the save-only path (file produced) is verifiable independently** (the save engine already works).
**Files:** `mega-container/Dockerfile` (install supercronic), `mega-container/entrypoint.sh` (launch supercronic supervised + restart loop), `private_dot_config/supercronic/crontab` (new), `private_dot_local/bin/executable_tmux-save` (new — flock wrapper), `tests/bin/test_tmux_save.sh`.
**Approach:** `tmux-save` wraps `save.sh` in `flock` on a shared lockfile (`~/.local/state/tmux-warp/save.lock`), targets `-L "$WARP_TMUX_SOCKET"`, exports the cron-safe PATH (mirroring `fill-toggl-cron.sh`), and no-ops cleanly if the server is absent. Install supercronic in the image; launch it from `entrypoint.sh` as a supervised long-running process wrapped in a restart loop (tini reaps but doesn't restart), reading `private_dot_config/supercronic/crontab`, which runs `tmux-save` (and `tmux-snapshot`) on a cadence that bounds worst-case loss for a detached session. The same `flock` makes a manual save and a scheduled save mutually exclusive. **No status-right hook** (dropped post-review: only fires while attached, adds concurrent-writer risk for marginal freshness).
**Patterns to follow:** cron-PATH convention in `private_dot_local/bin/executable_fill-toggl-cron.sh`; supervised background-launch style for long-lived services in `entrypoint.sh` (opencode web, tailscaled).
**Test scenarios:**
- Save path: `tmux-save` against a test socket with sessions → produces a resurrect file; exits 0.
- flock serialization: two overlapping `tmux-save` invocations → the `last` resurrect file is well-formed (not truncated/interleaved); only one runs at a time.
- No-op: `tmux-save` with no server → exits 0, logs, no error.
- Backstop wiring: supercronic crontab entry runs `tmux-save`; a save file appears on cadence (Covers AE8).
- Rebuild: supercronic running + crontab present after a container restart; restart loop respawns it if killed.
**Verification:** harness AE8 green; saves appear from supercronic and survive a rebuild; concurrent saves don't corrupt the dir.

### U6. opencode-aware snapshot/restore on the `work` socket + history readability

**Goal:** The custom snapshot/restore captures and resumes opencode sessions on the `work` socket; tmux + opencode history are readable.
**Requirements:** R6, R7.
**Dependencies:** U3 (socket convention), U4 (restore engine).
**Files:** `private_dot_local/bin/executable_tmux-snapshot`, `private_dot_local/bin/executable_tmux-restore`, `tests/bin/test_tmux_snapshot_restore.sh`.
**Approach:** Thread `-L "$WARP_TMUX_SOCKET"` through every `tmux` call in both scripts (they currently shell out to bare `tmux`). Confirm opencode session-ID capture via the `oc` registry still works and that restore resumes `opencode -s <id>`. If U4's decision gate fires (plugin update doesn't fix `restore.sh`), this is where the layout+pane-content restorer is added. For history readability: ensure tmux scrollback is captured (U4) and opencode history is queryable; note the ~1.8 GB `opencode.db` as a readability/perf risk (deep pruning deferred — origin Deferred).
**Patterns to follow:** existing `oc`-registry logic in `private_dot_local/bin/executable_tmux-snapshot` / `executable_tmux-restore`.
**Test scenarios:**
- Covers AE3: snapshot on the `work` socket captures windows/panes + opencode session IDs.
- Covers AE2/AE4: opencode session resumes via restore; opencode history shows the issued commands.
- Edge: snapshot with no opencode sessions → still captures layout, no error.
- Edge: restore into a fresh server recreates windows/panes + sends resume commands.
**Verification:** harness AE2–AE4 green.

### U7. Agent notifications via terminal-bell side-channel

**Goal:** Claude Code + opencode "done" / "needs permission" reach the user through tmux+SSH via a bell.
**Requirements:** R8.
**Dependencies:** none.
**Files:** `private_dot_claude/hooks/` (extend existing `notify-*.sh.tmpl`), `private_dot_claude/settings.json.tmpl` (already `preferredNotifChannel: terminal_bell`), `dot_tmux.conf` (`monitor-bell` / `bell-action`), opencode notification config under `private_dot_config/opencode/`, `tests/bin/test_notify_bell.sh`.
**Approach:** Notify hooks emit a **plain** terminal bell (`printf '\a'`) — no DCS-wrapping (a bare BEL traverses tmux natively; DCS-passthrough is for OSC sequences and would break the monitor-bell path). Set `set -g monitor-bell on` and change `bell-action` from `current` to `any` so a bell in any window surfaces. Wire opencode's notification path to the same bell.
**Patterns to follow:** existing `private_dot_claude/hooks/notify*.sh.tmpl` + `hook-lib.sh.tmpl`; bell/monitor settings in `dot_tmux.conf`.
**Test scenarios:**
- Covers AE6 (automated part): a simulated agent "done"/"needs permission" hook emits a plain `\a`; with `monitor-bell on`, tmux flags activity.
- opencode path: opencode notification triggers the same bell.
- (Guided-manual) AE6: the bell actually reaches Warp through tmux+SSH.
**Verification:** harness AE6 automated portion green (hook emits plain BEL, tmux flags bell); guided-manual confirms it reaches Warp.

### U8. Scheduling consolidation, cleanup & docs

**Goal:** Incidental fill-toggl repair onto supercronic, remove dead cron machinery, fix the healthcheck, document the new model, retire the superseded plan.
**Requirements:** R9 (incidental).
**Dependencies:** U5 (supercronic exists).
**Files:** `.chezmoiscripts/run_onchange_install-fill-toggl-cron.sh.tmpl` (remove), `run_once_after_setup-snapshot-cron.sh` (delete — dead), `private_dot_config/supercronic/crontab` (add fill-toggl entry), `mega-container/docker-compose.yml` (healthcheck), `mega-container/README.md` (docs), `docs/plans/2026-06-20-001-feat-warp-tmux-resilience-plan.md` (mark superseded — done).
**Approach:** Scope to **incidental** repair only (per origin Deferred): add fill-toggl's existing schedule to the supercronic crontab so it doesn't break when classic cron goes away, and delete the dead `run_once` snapshot installer + the stale fill-toggl crontab installer. **Update the compose healthcheck** (`pgrep -x cron` → check supercronic, or drop it) so removing classic cron doesn't mark the container unhealthy. Document the new durability model + helpers in the README. Deeper fill-toggl rework stays deferred.
**Patterns to follow:** existing `private_dot_local/bin/executable_fill-toggl-cron.sh`; doc tone in `mega-container/README.md`; healthcheck block in `mega-container/docker-compose.yml`.
**Test scenarios:** Test expectation: none — migration/cleanup/docs; covered indirectly by U5's rebuild test (supercronic crontab present, healthcheck green) and the harness.
**Verification:** supercronic runs both durability saves and fill-toggl; no `run_once`/crontab-installer cron remains; healthcheck passes; README reflects reality.

---

## Acceptance Examples (origin → units)

AE1→U3, AE2–AE4→U6, AE5→U4, AE6→U7, AE7→U2+U3, AE8→U5. U1 is the coordinating harness that automates AE1–AE5 and AE8 on a throwaway socket; AE6 (bell reaching Warp) and AE7 (real disconnect/reconnect) need live steps and are covered by their units + U1's guided-manual checklist.

---

## Scope Boundaries

**In scope:** R1–R11 — extension cutover, session helpers, repaired durability engine, supercronic save scheduler (flock-serialized), opencode-aware snapshot/restore on the `work` socket, readable history, bell notifications, verification harness, incidental fill-toggl repair, healthcheck fix, docs.

### Deferred to Follow-Up Work
- **ntfy phone-push notifications** — on `TODO.md` (linked to origin); bell ships now.
- **Pilot Warp native persistent sessions** (#9233) — on `TODO.md`; revisit when shipped.
- **Deep `opencode.db` pruning/rotation** — make history readable now; bloat management later.
- **Deeper fill-toggl rework** — only the incidental supercronic repair ships here.

### Outside this product's identity (cannot fix from our side)
- Native Warp blocks for tmux panes (only `-CC`/deprecated provided them).
- Warp's reattach bootstrap internals and the agent sidebar/permission-chip UI through tmux.

---

## Risks & Dependencies

- **Risk — concurrent save corruption.** Resolved by design: `flock` on a shared lockfile serializes every `save.sh` call (scheduled or manual), since a single socket alone does not prevent concurrent writers (the reason continuum's guard existed). Verified by U5's concurrent-save test.
- **Risk — TPM plugin update doesn't fix the restore crash** (OQ1 open). Mitigation: pin to a known-good tag; if still broken, U4's decision gate requires extending `tmux-restore` to reproduce layout+contents (not just opencode resume) before R5 is met. The harness catches it immediately.
- **Risk — extension doesn't engage over Tailscale SSH** (A-DEP1, gates R1's affirmative half). Mitigation: durability is tmux-owned, so the plan still delivers; resolved early in U2 and documented either way.
- **Risk — supercronic dies and saves silently stop.** Mitigation: launch under a restart loop in `entrypoint.sh` (tini reaps but doesn't restart); U5 tests respawn.
- **Risk — removing classic cron breaks the compose healthcheck.** Mitigation: U8 updates the healthcheck alongside the cron removal.
- **Risk — bell too coarse** (no rich agent context). Accepted; ntfy (richer) is on the roadmap.
- **Dependency:** supercronic installable in the image; persistent volume for the resurrect dir; tini remains PID 1.

---

## Open Questions (deferred to implementation)

- **OQ1:** Exact `restore.sh` crash cause — plugin version vs save-format vs tmux 3.3a. Resolve during U4; if the plugin update doesn't fix it, the U4 decision gate routes to a layout+content restorer.
- **OQ2 (resolved):** Notifications = bell only; ntfy on roadmap.
- **OQ3 (resolved):** Single named socket `work`, multiple sessions, injected via `WARP_TMUX_SOCKET` (KTD5).

---

## Sources & Research

- Origin requirements + investigation evidence: `docs/brainstorms/2026-06-20-warp-extension-tmux-remote-dev-requirements.md`.
- continuum self-disable + attached-only root cause: `~/.tmux/plugins/tmux-continuum/continuum.tmux` `main()` → `another_tmux_server_running` + status-right interpolation.
- Warp deprecation/extension/roadmap: docs.warp.dev/terminal/warpify/ssh-legacy; warpdotdev/warp#9233.
- Agent-notification-in-tmux breakage: warpdotdev/warp#12329, #10549, #9086.
- TPM install mechanism: `.chezmoiscripts/run_onchange_install-tpm.sh.tmpl` (installs missing only — never updates).
- chezmoi deployment constraint: `.chezmoiignore` excludes `tests` and `docs` (harness is source-tree/SSH-driven, not deployed); `dot_warp/settings.toml.tmpl` renders macOS-only (two-host apply).
