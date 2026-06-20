---
title: "Warp SSH extension + plain-tmux remote dev: durability, history, notifications"
status: draft
date: 2026-06-20
type: requirements
actors: [A1-developer, A2-cli-agents]
flows: [F1-start-session, F2-reconnect, F3-snapshot-restore, F4-agent-notify]
acceptance_examples: [AE1..AE8]
supersedes: docs/plans/2026-06-20-001-feat-warp-tmux-resilience-plan.md
---

# Warp SSH extension + plain-tmux remote dev: durability, history, notifications

## Problem Frame

Remote development happens on the mega-container, reached from laptop/phone via **Warp over Tailscale SSH**. The current setup rides Warp's **deprecated `-CC` tmux wrapper** (`use_ssh_tmux_wrapper = true`), which causes a cluster of failures — and investigation revealed the durability that was *supposed* to protect against them is itself broken:

- The `-CC` wrapper is **deprecated and frozen** (Warp's own docs); it spawns a fresh numbered tmux session per reconnect (no `-A`, no session-name knob), so after a long disconnect work appears lost / reattach fails.
- The **resurrect/continuum durability stack is broken on the box**: continuum auto-save **never wires up** (it self-disables when more than one tmux server runs — and there are always several), and `restore.sh` **crashes the server** ("server exited unexpectedly").
- **Cron is unreliable** in the container (chezmoi `run_onchange`/`run_once` don't re-fire on rebuild, and the crontab spool is ephemeral), so scheduled durability silently vanished.
- **Agent notifications break in tmux**: Warp's OSC-777 agent UI (toasts, permission chips) doesn't survive tmux+SSH, so Claude Code / opencode running in tmux give no signal.

**Goal:** a maintained, robust remote-dev setup built on the **Warp SSH extension** (not the deprecated wrapper) with **plain tmux as the persistence layer**, where durability, history, and notifications actually work — and are **proven by a verification harness**, because the current stack fails silently.

---

## Actors

- **A1 — Developer.** Works on the mega-container remotely (laptop, phone) via Warp + Tailscale SSH. Wants painless session management, durable sessions across disconnects/reboots, and visibility into history.
- **A2 — CLI agents (Claude Code, opencode).** Run *inside* tmux on the container; need to surface "done" / "needs permission" signals to A1 despite tmux+SSH breaking Warp's native agent UI.

---

## Requirements

- **R1 — Use the Warp SSH extension; retire the `-CC` wrapper.** Set `use_ssh_tmux_wrapper = false`; keep `ssh_extension_install_mode = "always_install"`. **Verify the extension actually engages over Tailscale SSH** (it is not currently installed on the box — likely a transport bypass).
- **R2 — Plain tmux is the persistence layer.** All durability/multiplexing works around normal-mode tmux, not Warp control mode.
- **R3 — Painless session helpers.** Short commands to (a) create/start a new named session and (b) list + attach an existing one, replacing verbose `tmux new -s …` / `tmux attach -t …`. Must be nesting-safe (work even if invoked from inside another tmux).
- **R4 — Durable saves via an explicit trigger.** Do **not** rely on continuum's auto-save (self-disables under multiple servers). Trigger the working `save.sh` ourselves: a **status-right throttle hook** (live saves while attached) **plus a supercronic backstop** (detached/idle). No systemd, no entrypoint-installed cron.
- **R5 — Fix resurrect restore.** `restore.sh` currently crashes the server; restore must reliably bring back sessions/windows/panes (with pane contents). Likely requires updating the plugins (2023–24 versions vs tmux 3.3a).
- **R6 — Keep the opencode-aware custom snapshot.** `tmux-snapshot`/`tmux-restore` must capture and restore opencode session IDs + layout, targeting the correct socket.
- **R7 — History is readable and restorable.** tmux scrollback (via `@resurrect-capture-pane-contents`) AND opencode history (`opencode.db`). Address the ~1.8 GB `opencode.db` bloat enough that history stays usable.
- **R8 — Agent notifications via side-channel.** "Done" / "needs permission" from Claude Code & opencode must reach A1 through tmux+SSH via a side-channel (terminal bell and/or ntfy), since Warp's native agent notifications are confirmed broken in tmux.
- **R9 — Container-native scheduling (supercronic).** Replace unreliable cron with supercronic reading a chezmoi-managed crontab file; survives rebuilds. Also repairs the silently-broken fill-toggl cron.
- **R10 — Verification harness (the spine).** A first-class, repeatable test implementing AE1–AE8 that proves durability/history/restore actually work. It is how we know restore is fixed — not an afterthought.
- **R11 — Durability artifacts survive rebuilds.** Resurrect dir + snapshots live on persistent volumes; save trigger (hook + supercronic) is reinstalled reliably on every container start.

---

## Key Flows

- **F1 — Start a session.** A1 runs the new-session helper → lands in a named tmux session, warpified by the extension.
- **F2 — Reconnect.** A1 closes laptop / loses network → tmux server keeps running container-side → on reconnect, A1 re-attaches to the same session(s); no lost work, no numbered-session sprawl.
- **F3 — Snapshot & restore.** Saves happen automatically (hook + supercronic); after a container restart, restore brings sessions/windows/panes/opencode-sessions/scrollback back.
- **F4 — Agent notify.** An agent in tmux finishes or needs permission → A1 is notified via bell/ntfy.

---

## Acceptance Examples (the verification harness)

- **AE1** — Create 2–3 sessions via the helper; each is listed and attachable.
- **AE2** — In one session, run opencode and issue 1–2 commands; the opencode session is registered/persisted.
- **AE3** — Run `tmux-snapshot`; the snapshot contains the expected windows/panes **and** the opencode session IDs.
- **AE4** — Read history: tmux scrollback shows prior output; opencode history shows the issued commands/session.
- **AE5** — Kill the tmux server (simulate container restart); run `tmux-restore`; sessions/windows/panes return, opencode sessions resume, and captured pane contents are present.
- **AE6** — Trigger an agent "done" / "needs permission"; the notification reaches A1 through tmux+SSH (bell/ntfy).
- **AE7** — Disconnect and reconnect; reattach lands in the same session(s) with no lost work and no numbered-session sprawl.
- **AE8** — After a container rebuild, the save trigger (status-right hook + supercronic entry) is present and functioning, and a save/restore cycle still works.

---

## Key Decisions & Rationale

- **KD1 — Drop the `-CC` wrapper; use the extension.** Source-confirmed deprecated/frozen ("will eventually be removed; use the SSH extension"). Native Warp panes for tmux existed *only* under `-CC`, so that experience is going away regardless; betting on it is betting on sand.
- **KD2 — Don't trust continuum auto-save.** Root cause (read in `continuum.tmux`): `main()` only wires the save hook `if ! another_tmux_server_running` — it self-disables whenever multiple tmux servers exist, which is always true on this box. `save.sh` itself works, so we trigger it ourselves.
- **KD3 — Save trigger = status-right hook + supercronic; no systemd, no entrypoint cron.** systemd is heavy (replaces tini as PID 1, cgroup/privileged rework). Entrypoint/`run_onchange` cron is unreliable (doesn't re-fire on rebuild; ephemeral spool). The hook gives free live saves while attached; supercronic gives a robust container-native backstop and a declarative, rebuild-surviving crontab.
- **KD4 — tmux is persistence; the extension is UX only.** Source-confirmed: the remote-server daemon's lifetime is tied to the SSH ControlMaster (`ssh -O exit` on shell exit) — it does **not** survive disconnects and does not own the shell PTY. Warp's roadmap native persistent sessions (#9233) are **unshipped**; track, don't depend.
- **KD5 — Notifications via side-channel.** Warp's OSC-777 agent protocol is broken in tmux+SSH (open issues #12329, #10549, #9086; plugins don't DCS-wrap, and `WARP_CLI_AGENT_PROTOCOL_VERSION` env-starves). A bell/ntfy side-channel bypasses the terminal protocol entirely and works today.
- **KD6 — Verify, don't assume.** The durability stack is empirically broken (restore crashes; auto-save disabled). The harness (R10) is therefore the spine, and "fix restore" / "wire saves" are gated on it passing.

---

## Scope Boundaries

**In scope:** R1–R11 — extension cutover, plain-tmux persistence, session helpers, working durability (hook + supercronic + fixed restore + custom snapshot), readable history, side-channel notifications, verification harness.

### Deferred for later
- **Piloting Warp's native persistent sessions** (roadmap #9233) — unshipped; track and re-evaluate when it lands (specifically whether it survives a container reboot).
- **Deep `opencode.db` pruning/rotation** beyond keeping history usable.
- **fill-toggl cron** beyond the incidental repair that supercronic provides.

### Outside this product's identity (cannot fix from our side)
- **Native Warp blocks for tmux panes** — only `-CC` (deprecated) ever provided per-pane blocks; not recoverable on the extension.
- **Warp's reattach bootstrap internals** and **Warp's agent sidebar / permission-chip UI through tmux** — internal to Warp; mitigated by durable tmux + side-channel notifications.

---

## Dependencies & Assumptions

- **A-DEP1 (unverified, prerequisite):** the Warp SSH extension engages over Tailscale SSH. Currently no `remote-server` is installed on the box. If it cannot, Warp features apply only to non-tmux shells.
- **A-DEP2:** resurrect/continuum plugins likely need updating (old versions × tmux 3.3a) to fix `restore.sh`; the exact crash cause is a plan/debug item.
- **A-DEP3:** supercronic is installable in the container image.
- **A-DEP4:** a notification side-channel (terminal bell and/or ntfy) is acceptable to A1; ntfy requires a reachable ntfy endpoint.
- **A-DEP5:** tini remains PID 1 (`init: true`).
- **A-DEP6:** resurrect dir + snapshots can live on persistent Docker volumes.

---

## Open Questions

- **OQ1:** Exact cause of the `restore.sh` crash — plugin version vs save-format vs tmux 3.3a? (Resolve in plan/debug; likely plugin update.)
- **OQ2:** Notification channel preference — terminal bell, ntfy, or both? (bell is zero-infra; ntfy reaches phone.)
- **OQ3:** Do we consolidate to a single tmux socket, or keep multiple? (We no longer depend on continuum's single-server guard, so multiple is fine — but the save hook/supercronic must target the right socket(s).)

---

## Investigation Evidence (load-bearing context)

- Warp `-CC` wrapper deprecated/frozen; SSH extension is the maintained path (docs.warp.dev/terminal/warpify/ssh-legacy).
- Warp open-sourced (AGPL, Apr 2026): remote-server daemon lifetime tied to SSH ControlMaster (`crates/remote_server/src/ssh.rs`); persistence is snapshot-to-`warp.sqlite`, processes not restarted; persistent-sessions roadmap (#9233) unshipped as of v0.2026.06.03.
- continuum auto-save self-disables under multiple tmux servers (`continuum.tmux` `main()` → `another_tmux_server_running`). `save.sh` works; `restore.sh` crashes the server (verified live).
- Agent notifications broken in tmux+SSH: Warp issues #12329, #10549, #9086; plugins emit un-DCS-wrapped OSC-777.
- `opencode.db` ≈ 1.8 GB on the box. tini is PID 1. Container reached via Tailscale SSH (`tailscaled be-child ssh`); extension not installed.
