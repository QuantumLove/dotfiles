---
title: "feat: keyboard-driven, mouse-minimized Mac workflow + interactive cheatsheet web app"
status: in-review
date: 2026-06-21
decisions_locked: 2026-06-21
revised: 2026-06-21 (r2 — incorporates Proof review round 1)
build_order: web-app-first
---

# feat: keyboard-driven, mouse-minimized Mac workflow + interactive cheatsheet web app

## Summary

Make the daily Mac dev stack keyboard-driven and mouse-minimized, built on the **Glove80 (ZMK) firmware** as the primary layer plus **Raycast** as the host-side hub, and document the whole system in a **local, interactive cheatsheet web app** that also documents every manual setup step and trains the workflows. Go-to-app is bilateral Hyper chords; window placement + window cycling run through Raycast; tmux gets a dedicated Glove80 thumb key (tap = prefix, hold = a layer carrying the full set of session/window/pane ops). Gmail and GitHub become Chrome PWAs across **two Chrome profiles (Work + Rafael)**; Spotlight is disabled and `Cmd+Space` reclaimed for Raycast. The VS Code dev-container→host gap is closed with a parameterized Raycast command. **Build order is web-app-first** — the cheatsheet is the visual spec + manual-steps reference the later phases implement against. Proof runs **only locally** (self-hosted on the host now, a container service later); a guardrail ensures the agent never talks to the hosted Proof service.

---

## Problem Frame

The stack — Slack, Chrome (Gmail + many windows, two profiles), Warp, VS Code, Notion, Linear — needs too much mouse and repetitive motion. The Glove80 Hyper key is unused for app control; go-to-app is on `F1–F5` Raycast deeplinks (to retire); tmux still uses the default `Ctrl+B`; opening a remote dev-container folder in host VS Code is manual across ~10 parallel sessions; and there's no single place to learn or discover the workflows or the manual setup steps.

---

## Goals

- **G1** — Go-to-app via bilateral Hyper chords (left thumb engages, right hand picks); retire `F1–F5` deeplinks. → U3
- **G2** — Window placement + window cycling in 1–2 keys via Raycast. → U3
- **G3** — Gmail + GitHub as Chrome PWAs across two profiles (Work + Rafael). → U2, U3
- **G4** — tmux: Glove80 thumb key tap=prefix / hold=layer; the layer carries session/window/pane ops; prefix → `Ctrl+Space`. → U4
- **G5** — VS Code dev-container→host open via a parameterized Raycast command. → U5
- **G6** — Adopt Homerow (deferred purchase) + Vimium; native-first everywhere else. → U2, U7
- **G7** — Raycast as a scriptable hub; track scripts + a binding inventory in chezmoi. → U6
- **G8** — Proof for HITL plan review, **local only**, with a guardrail blocking the hosted service. → U8
- **G9** — One interactive, local cheatsheet web app (React SPA) documenting workflows **and every manual setup step**, plus a practice trainer. **Built first.** → U1, U9
- **G10** — Disable Spotlight; reclaim `Cmd+Space` for Raycast. → U3

---

## Key Technical Decisions

- **KTD1 — Glove80 firmware is the only host-remap layer.** It emits Hyper (`Ctrl+Shift+Cmd+Alt`) natively, so no host remapper is needed.
- **KTD2 — Raycast owns app-focus, window placement, and window cycling** (G1, G2). Every Window Management command takes its own recorded hotkey (halves/thirds/two-thirds/maximize/center/move-display), so there's no typing/search. Window *cycling* (within an app and across apps) is bound too — see KTD8.
- **KTD3 — PWAs over multi-window ambiguity** (G3). Gmail and GitHub install as Chrome PWAs so each is a distinct, focusable macOS app with its own Hyper hotkey.
- **KTD4 — Two Chrome profiles: Work + Rafael** (G3). Separate profiles for work and personal; PWAs and go-to-app are profile-aware (work PWAs live in the Work profile).
- **KTD5 — Bilateral Hyper, chords not a nav layer** (G1). Mappings live in Raycast (rebind without reflashing). Hyper is on the **left** thumb, so app letters go on the **right** hand and window-management letters on the **left** hand → every chord is bilateral. **Letters = pure adjacency** (right-hand home cluster for apps, left-hand mirror for window-management). Per-app *related* commands may later sit behind Hyper on adjacent keys.
- **KTD6 — Disable Spotlight; Raycast on `Cmd+Space`** (G10). Spotlight is turned off entirely (System Settings → Keyboard → Keyboard Shortcuts → Spotlight). `Cmd+Space` is reclaimed as Raycast's hotkey; the Glove80 Raycast thumb (pos 56) also triggers Raycast.
- **KTD7 — tmux thumb key reuses the existing `lt_thumb` hold-tap** (G4). Bind the free **RH inner-lower thumb (pos 72)**: **tap** sends the prefix, **hold** activates a momentary `tmux_layer`. Prefix → `Ctrl+Space` (avoids the `Ctrl+B` readline collision). The layer carries the full op set (KTD9).
- **KTD8 — Window cycling is explicit** (G2). `Cmd+`` ` `` (backtick) cycles windows of the current app natively (the missing piece beyond `Cmd+~`/tab cycling); a Raycast "Switch Windows" hotkey cycles across all app windows. Both documented in the cheatsheet.
- **KTD9 — The tmux ZMK layer carries the whole vocabulary** (G4). Holding the tmux thumb turns the home row into: rename session, new window, kill/close window, next/prev/by-number window switch, new pane (split right/down), resize panes, pane nav (h/j/k/l), zoom, session tree, copy-mode, detach. The prefix tap remains for anything not on the layer.
- **KTD10 — Web app is a local React SPA, content-first, built first** (G9). Vite + React + TS + Tailwind. It documents target workflows **and the full manual-setup checklist**, runs on `localhost` (started manually, never auto), and is never published.
- **KTD11 — Raycast tracking is partial-by-nature** (G7). Script-command files in chezmoi (plain files; also feed the web app). The **web app's binding list is the canonical human-readable source**; a `.rayconfig` export is committed for one-time migration/recovery. No Raycast Pro.
- **KTD12 — Proof is local-only with a guardrail** (G8). The agent talks only to the self-hosted Proof on `localhost`; a guardrail (hook + CLAUDE.md/AGENTS.md note) forbids any call to `proofeditor.ai`/Proof AI. (The host auto-mode classifier already blocks such uploads; the hook is belt-and-suspenders.)

---

## Not Adopting (and why)

Kept short on purpose — these are simply not part of the build:

- **Karabiner-Elements** — the Glove80 emits Hyper and all needed remaps in firmware, so a host remapper has no job; also has an Apple-Silicon stability bug. Revisit only if a per-app conditional remap of a *non-Glove80* key ever becomes necessary.
- **AeroSpace (tiling WM)** — Raycast covers app-focus + window placement + cycling; PWAs solve the multi-Chrome case. Revisit only if persistent tiling workspaces become a stated want.
- **Google Docs as a PWA / dedicated section** — used ad hoc in the browser; not worth its own app or cheatsheet section.
- **Spotlight** — disabled; Raycast replaces it.

---

## High-Level Technical Design

```mermaid
flowchart TB
    subgraph kb["Glove80 (ZMK firmware)"]
        HY[Hyper — left thumb 52]
        TM[tmux thumb 72 — tap=prefix / hold=tmux layer]
        RC[Raycast thumb 56]
        HRM[home-row mods + existing layers]
    end
    subgraph host["macOS host"]
        RAY[Raycast — app focus (R hand) · window mgmt + cycling (L hand) · Cmd+Space · scripts]
        VIM[Vimium — Chrome]
        HR[Homerow — system-wide (deferred)]
        TMUXCONF[tmux.conf — prefix C-Space]
        NOSPOT[Spotlight disabled]
    end
    subgraph apps["App stack"]
        L[Linear app] ; S[Slack] ; W[Warp] ; V[VS Code] ; N[Notion]
        CW[Chrome — Work profile: Gmail PWA, GitHub PWA] ; CR[Chrome — Rafael profile]
    end
    subgraph doc["Local cheatsheet web app (localhost, manual start)"]
        DATA[curated workflow data + manual-steps checklist]
        SPA[React SPA: search · board · tracker · practice game]
    end
    subgraph bridge["VS Code bridge"]
        RCMD[Raycast cmd (path arg, clipboard default) → code-remote-open]
        CPWD[container: cpwd OSC52 / vsc OSC8]
    end
    subgraph proof["Proof (local only)"]
        PL[proof-local: API :4000 + editor :3000, SQLite, no telemetry]
    end

    HY --> RAY ; RC --> RAY ; TM --> TMUXCONF
    RAY --> apps ; VIM --> CW
    CPWD --> RCMD --> V
    DATA --> SPA
```

---

## Implementation Units

> **Build order:** U1 (web app) first and alone. U2–U9 are specified but built in later approved rounds.

### U1. Cheatsheet web app (React SPA) — BUILD FIRST

**Goal:** A local, interactive, keyboard-navigable cheatsheet that renders the per-app workflow catalog, a native Glove80 board, **and a full manual-setup checklist**.
**Goals:** G9.
**Files:** `cheatsheet/` in chezmoi (`.chezmoiignore`d — repo-only): Vite + React + TS + Tailwind app; `src/data/` (workflows, goToApp, windowMgmt, grammar, homerow, **manualSteps**); components (AppCard, ShortcutRow, CommandPalette, KeyboardBoard, GoToAppGrid, **SetupChecklist**, LearnTracker); a `npm run dev` start.
**Approach:**
- **Stack:** Vite + React + TS + Tailwind (+ Framer Motion, Fuse.js/cmdk). Dark theme (Tokyo-Night-ish, matching the tmux palette).
- **Native Glove80 board:** port `~/code/glove80/docs/app.js` to React — pixel-positioned 80-key board from `keymap.yaml` geometry, key-type coloring, SVG combo overlay, layer tabs + activation hints, and the live **Test-mode key-tester**. The existing Glove80 site is the quality bar. **Do not** use the static `keymap.svg`. The tmux (pos 72) and Raycast (pos 56) thumbs are shown on the board, plus the tmux layer.
- **Information architecture:** (1) Go-to-app grid (bilateral Hyper, profile badges); (2) Window management + **window cycling**; (3) Glove80 board; (4) tmux (incl. the full layer); (5) per-app workflows (Warp, Slack, Linear, Gmail, GitHub, Notion, VS Code, Chrome+Vimium); (6) Transferable grammar; (7) Homerow + Vimium (Homerow marked deferred); (8) **Manual setup steps** (the checklist — see below); (9) Learning tracker; (10) Practice game (U9).
- **Manual-setup checklist (per comment #4):** an explicit, ordered, checkable list of every manual action the system needs — create the two Chrome profiles, install Gmail/GitHub PWAs per profile, record each Raycast hotkey, disable Spotlight, flash the Glove80 firmware, add the `raf-dev` SSH config Host, register the Raycast scripts dir, start Proof via `proof-local`. Each item: what to do, where, and the resulting binding. This is the "how to actually set it up" companion to the reference.
- **Interactivity:** global fuzzy search (`/` or `Cmd+K`); filter by app/source/"learn first"; keyboard-navigable (dogfoods the ethos); per-item "learned" toggles in `localStorage` with progress bars.
- **Hosting:** **localhost only**, manual start (no GitHub Pages, no auto-start). Never published.
**Verification:** the user opens it locally, sees every table + the board + the setup checklist, searches/filters, tracks learning.

### U2. Installs, Chrome profiles & PWAs (no firmware, no chords)

**Goal:** Prereqs in place. **Goals:** G3, G6.
**Files:** `Brewfile` (add `cask "linear"`; keep `cask "raycast"`); manual steps documented in U1's checklist.
**Approach:** Add the Linear cask. Create **two Chrome profiles: "Work" and "Rafael"** (personal). In the Work profile, install **Gmail** and **GitHub** as PWAs (Install page as app). Install Vimium; configure per-site excluded-keys (Gmail partial passthrough `?jknpxercgilsafd#ubm/`, plus GitHub/Linear/Notion). Homerow documented, not purchased yet.
**Verification:** Linear launches; two Chrome profiles exist; Gmail/GitHub are standalone PWAs in the Work profile; Vimium coexists with Gmail.

### U3. Raycast go-to-app + window management + cycling; disable Spotlight

**Goal:** Bilateral Hyper hotkeys; window placement + cycling in 1–2 keys; Spotlight off. **Goals:** G1, G2, G10.
**Files:** Raycast config (captured in `docs/raycast-hotkeys.md`); macOS System Settings (manual, in U1 checklist).
**Approach:** Disable Spotlight (Keyboard Shortcuts → Spotlight). Set Raycast hotkey = `Cmd+Space`. Delete the `F1–F5` deeplinks. Record Hyper+letter app-focus (focus-or-open) — right-hand letters — for Linear, Slack, Warp, VS Code, Notion, Gmail PWA, GitHub PWA, Chrome. Record Hyper+left-letter Window Management (halves/thirds/two-thirds/maximize/center/move-display/restore). Bind **window cycling**: `Cmd+`` ` `` (native, cycle current-app windows) + a Raycast "Switch Windows" hotkey for cross-app window cycling.
**Verification:** every chord focuses/places/cycles in ≤2 keys; Spotlight gone; `Cmd+Space` opens Raycast; F1–F5 retired.

### U4. Glove80 firmware: tmux thumb + tmux layer + Raycast thumb; tmux.conf

**Goal:** tmux thumb (tap=prefix/hold=layer with the full op set), Raycast thumb, prefix → `Ctrl+Space`. **Goals:** G4.
**Files:** `~/code/glove80/config/glove80.keymap`; `dot_tmux.conf`.
**Approach:** `#define TMUX 11`; add a `tmux_key` prefix-then-key macro (modeled on `mod_tab`); pos-72 → `&lt_thumb TMUX LC(SPACE)`; pos-56 → Raycast (Cmd+Space or F13→Raycast); add a `tmux_layer{}` after `symbol_layer` mapping home-row + neighbors to: **rename session, new window, kill window, next/prev/by-number window, new pane (split `|`/`_`), resize panes, pane nav h/j/k/l, zoom, session tree, copy-mode, detach** (per comments #5/#8). `dot_tmux.conf`: `set -g prefix C-Space; bind C-Space send-prefix`; keep the existing custom binds (they're what the layer drives). Batch all firmware edits into one flash.
**Verification:** tap = prefix; hold + letter = each tmux op without a prefix tap; Raycast opens from the thumb; `Ctrl+Space` prefix works.

### U5. VS Code dev-container → host bridge

**Goal:** Open an arbitrary remote path in local VS Code from any session, explicitly. **Goals:** G5.
**Files:** `private_dot_local/bin/executable_code-remote-open`; a Raycast Script Command (path arg, clipboard fallback); container-side `cpwd` OSC52 alias (+ optional `vsc` OSC8); `~/.ssh/config` Host `raf-dev`.
**Approach:** `code-remote-open <host> <path>` runs `open "vscode://vscode-remote/ssh-remote+<host><path>"`. The Raycast command takes a path arg (blank → `pbpaste`), then calls it. `cpwd` copies `$PWD` to the Mac clipboard (tmux `set-clipboard on` already set). Add the `raf-dev` SSH Host. No push/auto-open (revisit later).
**Verification:** any session's cwd opens in local VS Code in ≤2 deliberate steps; no last-handoff ambiguity.

### U6. Raycast as a hub + tracking in chezmoi

**Goal:** Script-command hub + recovery-grade config tracking. **Goals:** G7.
**Files:** `private_dot_config/raycast/scripts/` (existing + `open-in-vscode`, `switch-project`); `run_onchange_chmod-raycast-scripts.sh`; `docs/raycast-hotkeys.md`; a committed `.rayconfig` export.
**Approach:** Consolidate script commands under chezmoi (also feed the web app). The web app's binding list is the canonical human-readable source; `.rayconfig` is recovery/migration. No Pro.
**Verification:** scripts executable after `chezmoi apply`; a fresh machine reconstructable from repo + inventory.

### U7. Homerow adoption (deferred trigger)

**Goal:** System-wide hint-clicking for the catalogued gaps. **Goals:** G6.
**Approach:** Purchase + install when the documented gaps (Slack reactions, Notion DB chrome, Warp block-output copy) become daily friction; activate on a Glove80 thumb/Hyper chord (not `Shift+Space`). Documented in the web app now.

### U8. Proof — local only, with guardrail

**Goal:** HITL plan review entirely on `localhost`, never the hosted service. **Goals:** G8.
**Files:** `proof-local` helper (done); a guardrail hook (e.g. a PreToolUse/network guard blocking `proofeditor.ai`); a note in CLAUDE.md/AGENTS.md.
**Approach:** Run self-hosted Proof via `proof-local` (host now; container service later, exposed like opencode web). **Guardrail (per comment #3):** ensure the agent only ever calls `localhost:4000`; add a hook that blocks any request to `proofeditor.ai`/Proof AI, and document the rule in CLAUDE.md/AGENTS.md. (The host auto-mode classifier already blocks such uploads — confirmed in practice — so this is defense-in-depth.)
**Verification:** review loop works on localhost; any attempt to reach the hosted service is blocked.

### U9. Practice/tutorial game in the web app (final phase)

**Goal:** A lightweight, self-graded recall trainer. **Goals:** G9.
**Approach:** A flashcard/drill over the same workflow data: show a task ("split the pane right in Warp"), you recall the keys, self-grade; spaced-repetition-lite weighted to "learn first" + not-yet-learned; ties into the U1 tracker. Not elaborate — just enough to not forget.

---

## Scope Boundaries

**In scope:** G1–G10. **This build round: U1 (web app) only.** U2–U9 in later approved rounds. **Deferred:** Homerow purchase (U7); config-driven web-app data (v1 is curated). **Not adopting:** see the section above.

---

## Per-app workflow catalog (web-app seed content)

Source legend: native unless **[V]** Vimium / **[H]** needs Homerow (deferred). tmux prefix = `Ctrl+Space` after U4; the **bold tmux rows are the ones bound on the ZMK tmux layer**.

### Warp
| Task | Keys |
|------|------|
| New tab / window | `Cmd+T` / `Cmd+N` |
| Close pane/tab | `Cmd+W` |
| Split right / down | `Cmd+D` / `Cmd+Shift+D` |
| Cycle pane next / prev | `Cmd+]` / `Cmd+[` |
| Directional pane nav | `Cmd+Opt+Arrow` |
| Resize pane | `Ctrl+Cmd+Arrow` |
| Zoom pane | `Cmd+Shift+Return` |
| Command Palette / AI | `Cmd+P` / `` Ctrl+` `` |
| Unified command search | `Ctrl+R` |

**Learn first:** `Cmd+D` · `Cmd+]`/`[` · `Ctrl+Cmd+Arrow` · `Cmd+Shift+Return` · `Cmd+P` · `Ctrl+R`
**[H] gaps:** copy block output text · arbitrary output selection

### tmux (custom config; prefix → `Ctrl+Space`; **bold = on the ZMK tmux layer**)
| Task | Keys |
|------|------|
| **Rename session** | `prefix $` |
| **New window** | `prefix c` |
| **Kill / close window** | `prefix &` |
| **Next / prev / by-number window** | `prefix n` / `p` / `1-9` |
| **Session tree (switch)** | `prefix s` |
| **New pane — split right / down** | `prefix \|` / `prefix _` |
| **Resize panes** | `prefix Arrow` (repeatable) |
| **Pane nav** | `prefix h/j/k/l` |
| **Zoom pane** | `prefix z` |
| **Detach** | `prefix d` |
| Copy mode + search | `prefix [` → `/` `n`, `v`/`y` |
| Reload config | `prefix r` |

> With the firmware tmux layer (hold pos-72), every **bold** row becomes hold-thumb + a single home-row key — no prefix tap.

**Learn first:** rename `$` · new window `c` · switch `n`/`p` · split `|`/`_` · resize arrows · nav `h/j/k/l` · zoom `z`

### Slack (desktop)
| Task | Keys |
|------|------|
| Quick switcher | `Cmd+K` |
| Next / prev unread | `Opt+Shift+Down`/`Up` |
| Mark read / all read | `Esc` / `Shift+Esc` |
| Unreads / Activity / Threads | `Cmd+Shift+A` / `M` / `T` |
| Message-nav → actions | `Up` (empty compose) → arrows → `R`/`E`/`T` |
| Back / forward | `Cmd+[` / `Cmd+]` |

**Learn first:** `Cmd+K` · `Opt+Shift+Down` · `Esc` · `Up→arrows→R/E/T` · `Cmd+Shift+M`
**[H] gaps:** click emoji/reaction · @mention/link · drag-reorder sidebar

### Linear (desktop app)
| Task | Keys |
|------|------|
| Command menu / help | `Cmd+K` / `?` |
| Create issue | `C` |
| Go-to Inbox/MyIssues/Triage/Active/Backlog | `G` then `I`/`M`/`T`/`A`/`B` |
| List nav / open | `J`/`K` / `Enter` |
| Status / priority / label / assignee | `S` / `P` / `L` / `A` |
| Comment | `Cmd+M` → `Cmd+Enter` |
| Search / copy ID | `/` / `Cmd+.` |

**Learn first:** `Cmd+K` · `C` · `G`+`I/M/T/A/B` · `J`/`K`+`Enter` · `S`/`P`/`L`/`A` · `Cmd+.` · `?`

### Gmail (Chrome PWA — Work profile; needs shortcuts enabled + Vimium passthrough)
| Task | Keys |
|------|------|
| Compose / send | `c` / `Cmd+Enter` |
| Reply / reply-all / forward | `r` / `a` / `f` |
| List down/up / open / back | `j`/`k` / `o` / `u` |
| Archive / delete / select | `e` / `#` / `x` |
| Go-to Inbox/Starred/Sent | `g` then `i`/`s`/`t` |
| Search / undo | `/` / `z` |
| Click a link/attachment | `f` **[V]** |

**Learn first:** `j`/`k` · `e` · `c`/`r`/`a`/`f` · `u` · `g`+`i/s/t` · `x`→`e/#` · `/` · `z`
**Setup:** Gmail Settings → Keyboard shortcuts ON; Vimium excluded-keys for `mail.google.com/*` = `?jknpxercgilsafd#ubm/`

### GitHub (Chrome PWA — Work profile)
| Task | Keys |
|------|------|
| File finder / github.dev | `t` / `.` |
| Go-to Code/Issues/PRs/Notifications | `g` then `c`/`i`/`p`/`n` |
| Search | `s` or `/` |
| Notifications: nav/done/read | `j`/`k` / `e` / `Shift+I` |
| PR diff: file nav / toggle whitespace | `j`/`k` / `w` |
| Submit review / comment | `Cmd+Shift+Enter` / `Cmd+Enter` |

**Learn first:** `t` · `.` · `g`+`c/i/p` · `j`/`k`→`e` · `/` · `w`
**Gaps:** next *unviewed* file (use **[V]** `f`) · approve/request-changes (no key)

### Notion (desktop)
| Task | Keys |
|------|------|
| Quick-find / in-page find | `Cmd+P` / `Cmd+F` |
| Sidebar / back / forward / up-level | `Cmd+\` / `Cmd+[` / `Cmd+]` / `Cmd+Shift+U` |
| Insert block / turn-into | `/` / `Esc` then `Cmd+/` |
| Select / move block | `Esc` + `Shift+Up/Down` → `Cmd+Shift+Up/Down` |
| Indent / outdent | `Tab` / `Shift+Tab` |
| Comment / new page | `Cmd+Shift+M` / `Cmd+N` |

**Learn first:** `Cmd+P` · `Esc`→`Cmd+/` · `/` · `Cmd+\` · `Cmd+[`/`]` · `Tab`/`Shift+Tab`
**[H] gaps:** database chrome — switch view, filter/sort/group, "New" row, nested sidebar, `...` menu

### VS Code (host — git review + plan reading)
| Task | Keys |
|------|------|
| Command Palette / quick-open | `Shift+Cmd+P` / `Cmd+P` |
| Source Control / open diff | `Ctrl+Shift+G` / `Enter` on row |
| Next / prev change | `Opt+F5` / `Shift+Opt+F5` |
| Stage / unstage / revert hunk | `Cmd+K Cmd+Opt+S` / `Cmd+K Cmd+U` / `Cmd+K Cmd+R` |
| Commit staged | `Cmd+Enter` |
| Terminal / Markdown preview | `` Ctrl+` `` / `Cmd+K V` |

**Learn first:** `Ctrl+Shift+G` · `Opt+F5`/`Shift+Opt+F5` · `Cmd+K Cmd+Opt+S` · `Cmd+Enter` · `Cmd+K V` · `Cmd+P`
**Custom binds (`keybindings.json`, chezmoi):** `git.stageFile → Cmd+K Cmd+A` · `git.push → Cmd+K Cmd+P` · GitLens next/prev changed file `Opt+]`/`Opt+[`

### Chrome + Vimium
| Task | Keys |
|------|------|
| Follow link same/new tab | `f` / `F` |
| Scroll line / half-page / extremes | `j`/`k` / `d`/`u` / `gg`/`G` |
| History back / forward | `H` / `L` |
| Find in page | `/` then `n`/`N` |
| Vomnibar (url/history) | `o` / `O` |
| Fuzzy switch open tab | `T` |
| **Cycle windows of current app** | `Cmd+`` ` `` (native, per comment #1) |
| New / close / restore tab | `t` / `x` / `X` |

**Learn first:** `f`/`F` · `j`/`k`/`d`/`u` · `T` · `o`/`O` · `H`/`L` · `Cmd+`` ` `` · `x`/`X`
**Setup:** install Vimium; per-site excluded-keys for Gmail/GitHub/Linear/Notion

## Transferable grammar (teach once, use everywhere)

- **`g`-then-letter navigation:** Gmail, GitHub, Linear — one model, three apps.
- **`j`/`k` list navigation:** Gmail, GitHub, Linear, Vimium, tmux pane-nav.
- **`Cmd+K` / `Cmd+P` command palette:** Slack, Linear / Warp, VS Code, Notion.
- **`/` to search/filter:** Gmail, GitHub, Linear, Vimium, the cheatsheet itself.

## Resolved Decisions

- **Hyper letter mapping → pure adjacency** (apps right hand, window-mgmt left hand); rebindable in Raycast.
- **Web app stack → Vite + React + TS + Tailwind**, native React Glove80 board (not the SVG), **localhost only** (not GitHub Pages).
- **Raycast tracking → free** (scripts in chezmoi + `.rayconfig` export + web app as canonical list); no Pro.
- **Practice game → simple self-graded recall.**
- **VS Code bridge → parameterized command only** (no push for now).
- **Homerow → in the plan + web app, not built/purchased yet.**
- **Proof → local only**, self-hosted via `proof-local`; guardrail blocks the hosted service.
- **r2 (this round):** slimmed (Karabiner/AeroSpace moved to "Not adopting"); Google Docs removed; window cycling added; tmux layer carries the full op set; two Chrome profiles (Work + Rafael); Spotlight disabled + Raycast on `Cmd+Space`; web app documents all manual setup steps.

## Open Questions

- **Q1 — Final Hyper letter grid** — drafted in U3 when hotkeys are recorded.
- **Q2 — Raycast thumb keycode** — `Cmd+Space` directly vs `F13`→Raycast (both reach Raycast; decide at U4).

## Sources & Research

- ce-ideate session (2026-06-21): 48 candidates → 7 survivors → 19-agent deep-dive → this plan → Proof review r1.
- VS Code bridge / Raycast args / OSC52: Raycast `script-commands/ARGUMENTS.md`; VS Code Remote-SSH docs; OSC52/OSC8 patterns.
- Proof self-hosting: `github.com/EveryInc/proof-sdk` (MIT; local SQLite; telemetry off); run via the `proof-local` helper.
- Plan format mirrors `docs/plans/2026-06-20-002-...md`.
