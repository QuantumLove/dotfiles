---
title: "feat: keyboard-driven, mouse-minimized Mac workflow + interactive cheatsheet web app"
status: in-review
date: 2026-06-21
decisions_locked: 2026-06-21
revised: 2026-06-21 (r6 — CE review r2: LOWER thumb is NOT free (keep it), avoid pos-53 combo thumb, confirm firmware on-device, Wispr MacBook trigger via its own app hotkey, web-app open-trigger + one-card-on-open, chezmoiignore + Proof-bind hardening)
build_order: config-first
---

# feat: keyboard-driven, mouse-minimized Mac workflow + interactive cheatsheet web app

## Summary

Make the daily Mac dev stack keyboard-driven and mouse-minimized, built on the **Glove80 (ZMK) firmware** as the primary layer plus **Raycast** as the host-side hub, documented in a **local, interactive cheatsheet web app**. **Build order is config-first** (revised after review): land the daily ergonomic wins (Raycast go-to-app + window management, the tmux thumb/layer, Spotlight-shortcut reclaim) and the VS Code bridge first — these take an afternoon each and produce the *real* binding inventory — **then** build the web app to document what you actually run. Go-to-app is bilateral Hyper chords; **Raycast is reached via `Cmd+Space`** (reclaimed by disabling the Spotlight shortcut) — no dedicated Raycast thumb is needed. The tmux key is a *conscious reassignment* of an HRM-duplicated inner thumb (the Glove80's thumbs are already full — Wispr Flow dictation must not be clobbered). Gmail and GitHub become Chrome PWAs across **two profiles (Work + Rafael)**. Proof runs **only locally** (self-hosted; already running via `proof-local`). **Cross-device:** every important action also has a host-level chord that works on the MacBook built-in keyboard (Raycast on `Cmd+Space`; Hyper via Raycast's Caps-Lock Hyper key; tmux prefix `Ctrl+Space`), so the Glove80 thumbs are pure ergonomic conveniences, never the only path.

---

## Problem Frame

The stack — Slack, Chrome (Gmail + many windows, two profiles), Warp, VS Code, Notion, Linear — needs too much mouse and repetitive motion. The Glove80 Hyper key is unused for app control; go-to-app is on `F1–F5` Raycast deeplinks (to retire); tmux uses the default `Ctrl+B`; opening a remote dev-container folder in host VS Code is manual across ~10 parallel sessions; and there's no single place to learn the workflows or the manual setup steps.

---

## Goals

- **G1** — Go-to-app via bilateral Hyper chords (left thumb engages, right hand picks); retire `F1–F5`. → U3
- **G2** — Window placement + window cycling in 1–2 keys via Raycast. → U3
- **G3** — Gmail + GitHub as Chrome PWAs across two profiles (Work + Rafael). → U2, U3
- **G4** — tmux: a Glove80 thumb key tap=prefix / hold=layer; the layer carries session/window/pane ops; prefix → `Ctrl+Space`. → U4
- **G5** — VS Code dev-container→host open via a parameterized Raycast command. → U5
- **G6** — Adopt Homerow (deferred purchase) + Vimium; native-first everywhere else. → U2, U7
- **G7** — Raycast as a scriptable hub; track scripts + a binding inventory in chezmoi (secrets sanitized). → U6
- **G8** — Proof for HITL plan review, **local only**, with a guardrail blocking the hosted service. → U8
- **G9** — One interactive, local cheatsheet web app documenting workflows **and every manual setup step**; built **after** the config wins so it documents reality. → U1
- **G10** — Reclaim `Cmd+Space` for Raycast by disabling the Spotlight **shortcut** (not indexing). → U3
- **G11** — Cross-device: every important action is usable on the MacBook built-in keyboard, not only via the Glove80. → U3, KTD13

---

## Key Technical Decisions

- **KTD1 — Glove80 firmware is the primary remap layer; the only host-side remap is Raycast's Hyper key.** Remapping lives in the firmware — which we *do* edit (thumbs, layers) — so **no Karabiner**. The single exception is cross-device parity: on the MacBook, Raycast's built-in **Caps Lock → Hyper** is one host-level remap so `Hyper+letter` works without the Glove80 (KTD13). No general host remapper beyond that.
- **KTD2 — Raycast owns app-focus, window placement, and window cycling** (G1, G2). Every Window Management command takes its own recorded hotkey, so there's no typing/search.
- **KTD3 — PWAs over multi-window ambiguity** (G3). Gmail and GitHub install as Chrome PWAs so each is a distinct, focusable macOS app with its own Hyper hotkey.
- **KTD4 — Two Chrome profiles: Work + Rafael** (G3). PWAs and go-to-app are profile-aware (work PWAs live in the Work profile).
- **KTD5 — Bilateral Hyper, chords not a nav layer** (G1). Mappings live in Raycast (rebind without reflashing). Hyper is the HOLD side of a hold-tap on the **left** thumb (`&hyper_mt HYPER LSHFT`, pos verified), so app letters go on the **right** hand and window-management letters on the **left** hand. **Letters = pure adjacency.** *Caveat:* chord speed is gated by the hold-tap tapping-term — if go-to-app feels laggy, tune `hyper_mt`, and do a quick on-device head-to-head vs. a nav layer before locking the grid (mappings are cheap to rebind).
- **KTD6 — Disable the Spotlight shortcut; Raycast on `Cmd+Space`; no Raycast thumb** (G10). Disable *only* the `Cmd+Space` Spotlight shortcut (leave indexing/Finder-search/Look-Up intact). Raycast's hotkey = `Cmd+Space`. **No dedicated Raycast thumb** — `Cmd+Space` is enough, and the thumb cluster is full (see KTD7).
- **KTD7 — Free thumbs reserved for tmux + Homerow + app-actions; positions chosen by feel at U4** (G4). **Locked thumbs:** Hyper, Wispr (`&wispr LG(F18) LG(F19)` — dictation, never clobber), and Backspace/Delete/Enter/Space (whose holds carry the kept Cursor/Number/Mouse/Symbol layers). The **5 genuinely-free thumbs** — `LCtrl`, `LAlt`, `LGui`, `RCtrl`, `RAlt` (all true home-row-mod duplicates) — cover the three functions we need (we don't need all 5). **Leave the LOWER thumb alone:** it's the *sole* gateway to the LOWER layer (media keys, brightness/volume, F11/F12, full numpad, CAPS/INS — `keymap:638-646`), so reassigning it deletes those with no fallback. **Avoid the `LCtrl` thumb (pos 53) for frequently-tapped functions** — it's half of the `Ctrl+Tab` combo (positions 53+70); prefer LAlt/LGui/RCtrl/RAlt. The three functions: **tmux** (tap = prefix `Ctrl+Space`, hold = `tmux_layer`, reusing the existing `lt_thumb` hold-tap), **Homerow activation**, and an **app-actions layer** (a right-hand hold layer; contents defined later). Exact thumb→function placement is decided **hands-on by feel when flashing (U4)** against the live keymap — KTD13 (cross-device) makes this low-stakes and fully reversible. **All four V3/V4 layers are kept.**
- **KTD8 — Window cycling, with a known gap** (G2). `Cmd+`` ` `` cycles windows of the current app, and a Raycast "Switch Windows" hotkey cycles across apps. **Gap:** `Cmd+`` ` `` skips minimized and other-Space windows — U3 includes a falsification test for these cases (see Not Adopting → AeroSpace).
- **KTD9 — The tmux ZMK layer carries the whole vocabulary** (G4). Holding the tmux thumb maps the home row to: rename session, new window, kill window, next/prev/by-number window, new pane (split right/down), resize panes, pane nav (h/j/k/l), zoom, session tree, copy-mode, detach.
- **KTD10 — Web app is a local React SPA, content-first, built AFTER the config wins** (G9). Vite + React + TS + Tailwind (+ Fuse.js/cmdk; **no Framer Motion** until a transition needs it). Runs on `localhost`, started manually, never published. Built once the real bindings exist so its content is accurate. Split: **U1a** (searchable workflow tables + setup checklist + learning tracker — ships first, can use the existing `keymap.svg` for the board) and **U1b** (the from-scratch interactive React board + key-tester — later).
- **KTD11 — Raycast tracking is partial-by-nature, and the export is sanitized** (G7). Script-command files in chezmoi (plain files; feed the web app). The web app's binding list is the canonical human-readable source. A `.rayconfig` export may be committed **only after** grepping it for `token|apiKey|secret|password` (Raycast exports include extension prefs — Linear/GitHub/Slack/1Password keys); redact or keep it in 1Password + `.gitignore`. No Raycast Pro.
- **KTD12 — Proof is local-only with a guardrail** (G8). The agent talks only to `localhost`; a guardrail (hook + CLAUDE.md/AGENTS.md note) forbids any call to `proofeditor.ai`/Proof AI. The host classifier already blocks such uploads. Verify Proof binds `127.0.0.1` (not `0.0.0.0`) so the local servers aren't exposed on shared WiFi.
- **KTD13 — Cross-device: every action works on the MacBook built-in keyboard too** (G11). Rafael isn't always on the Glove80, so every important action has a **host-level chord reachable on the MacBook**, and the Glove80 thumbs/layers only *emit* those chords (pure ergonomics, never the only path). Concretely: Raycast = `Cmd+Space` (universal); enable **Raycast's built-in Hyper key (Caps Lock → Hyper)** on the MacBook so all `Hyper+letter` go-to-app/window-mgmt chords work without the Glove80; tmux prefix = `Ctrl+Space` (universal) — the ZMK tmux layer is a convenience and prefix+key is the MacBook fallback; Wispr's MacBook trigger is its **own app-level hotkey** (already configured in Wispr Flow for laptop use) — *not* `Cmd+F18`, which is only the Glove80 firmware trigger (F13–F19 don't exist on the MacBook function row). This is *why* the thumb layout can stay relaxed — the firmware adds comfort, not capability.
- **KTD14 — Verify live as you go.** Every unit is implement → **test on the spot, live** (automated where possible; with the user's input where automation isn't) → only then continue. No batching unverified work; breakage is caught at the step that caused it. Each unit's *Verification* runs immediately after its *Approach*, not deferred.

---

## Not Adopting (and why)

- **Karabiner-Elements** — the Glove80 emits Hyper + all remaps in firmware; revisit only for a per-app conditional remap of a non-Glove80 key.
- **AeroSpace (tiling WM)** — Raycast covers app-focus + placement + cycling; PWAs solve multi-Chrome. *Caveat:* the ROADMAP's V6 still lists AeroSpace, and `Cmd+`` ` `` cycling skips minimized/other-Space windows. **Revisit trigger:** if cross-Space or minimized-window cycling becomes daily friction — tallied over **~2 weeks** in the learning tracker (not one day; you adapt around gaps too fast to judge in a day). Re-adding it later is `brew install aerospace` + a TOML.
- **Google Docs as a PWA / dedicated section** — used ad hoc in the browser.
- **Spotlight (the shortcut only)** — `Cmd+Space` reclaimed for Raycast; indexing/search left intact.

---

## Build Sequence (revised r3 — config-first)

**U2 → U3 → U4 → U5 → U6 → U1** (then deferred: **U7** Homerow, **U9** practice game). **U8** (local Proof) is already running. Rationale: U2–U6 are short, high-payoff, and generate the real binding inventory; U1 (the web app) documents that reality afterward, so its content can't drift from what was actually configured. Unit numbers are identifiers, not order — follow this sequence. **Verify live as you go (KTD14):** after each step, test it on the spot — automated where possible, with your input where not — before moving on.

---

## Implementation Units

### U2. Installs, Chrome profiles & PWAs

**Goal:** Prereqs. **Goals:** G3, G6. **Files:** `Brewfile` (add `cask "linear"`); manual steps in U1's checklist.
**Approach:** Add the Linear cask. Create **two Chrome profiles: "Work" and "Rafael"**. In Work, install **Gmail** + **GitHub** as PWAs. Install Vimium; per-site excluded-keys (Gmail `?jknpxercgilsafd#ubm/`, + GitHub/Linear/Notion). Homerow documented, not purchased.
**Verification:** Linear launches; two profiles exist; Gmail/GitHub are PWAs in Work; Vimium coexists with Gmail.

### U3. Raycast go-to-app + window management + cycling; reclaim Cmd+Space

**Goal:** Bilateral Hyper hotkeys; window placement + cycling in 1–2 keys; `Cmd+Space` → Raycast. **Goals:** G1, G2, G10.
**Files:** Raycast config (captured in `docs/raycast-hotkeys.md`); macOS System Settings (manual).
**Approach:** Disable the Spotlight `Cmd+Space` shortcut; set Raycast hotkey = `Cmd+Space`. Delete `F1–F5`. Record Hyper+right-letter app-focus (focus-or-open) for Linear, Slack, Warp, VS Code, Notion, Gmail PWA, GitHub PWA, Chrome. Record Hyper+left-letter Window Management. Bind cycling: `Cmd+`` ` `` + Raycast "Switch Windows". Enable **Raycast's Hyper key (Caps Lock → Hyper)** so the `Hyper+letter` chords also work on the MacBook built-in keyboard (cross-device, KTD13). **Falsification test:** tally minimized/other-Space cycling friction over **~2 weeks** (a tick in the tracker), not a single day → if it's real, trigger the AeroSpace revisit.
**Verification:** every chord focuses/places/cycles in ≤2 keys; `Cmd+Space` opens Raycast; F1–F5 retired.

### U4. Glove80 firmware: tmux thumb + tmux layer; tmux.conf

**Goal:** tmux thumb (tap=prefix/hold=layer with the full op set), prefix → `Ctrl+Space`. **Goals:** G4.
**Files:** `~/code/glove80/config/glove80.keymap`; `dot_tmux.conf`.
**Approach (order matters):**
1. **Confirm the flashed firmware version on-device first** (README says "V5 current"; ROADMAP says "not yet flashed" — reconcile those docs and check what the board actually runs). If already on V4/V5, just add the tmux layer; if on V3, flash V4/V5 first and verify, then add tmux. Then **audit live thumb occupancy** against the keymap and place tmux, Homerow activation, and the app-actions layer onto the **5 free modifier thumbs (prefer LAlt, LGui, RCtrl, RAlt — avoid `LCtrl`/pos-53, it's in the Ctrl+Tab combo)** by feel. **Keep the LOWER thumb (sole access to media/numpad/F-keys) and never touch `&wispr`.**
2. **Flash V4 + V5 first** (currently unflashed — board is on V3) and verify on-device, so the tmux change can be bisected from the V4/V5 changes.
3. Then add: `#define TMUX 11`; a `tmux_key` prefix-then-key macro (modeled on `mod_tab`); the chosen thumb → `&lt_thumb TMUX LC(SPACE)`; a `tmux_layer{}` after `symbol_layer` mapping home-row + neighbors to rename session, new window, kill window, next/prev/by-number window, new pane (`|`/`_`), resize panes, pane nav h/j/k/l, zoom, session tree, copy-mode, detach. Flash as a second step.
4. `dot_tmux.conf`: `set -g prefix C-Space; bind C-Space send-prefix`; keep the existing custom binds.
**Verification:** dictation still works; tap = prefix; hold + key = each tmux op; `Ctrl+Space` prefix works.

### U5. VS Code dev-container → host bridge

**Goal:** Open an arbitrary remote path in local VS Code from any session, explicitly. **Goals:** G5.
**Files:** `private_dot_local/bin/executable_code-remote-open`; a Raycast Script Command (path arg, clipboard fallback); container `cpwd` OSC52 alias (+ optional `vsc` OSC8); `~/.ssh/config` Host `raf-dev`.
**Approach:** `code-remote-open <host> <path>` → `open "vscode://vscode-remote/ssh-remote+<host><path>"`. Raycast command takes a path arg (blank → `pbpaste`). `cpwd` copies `$PWD` to the Mac clipboard. No push/auto-open.
**Verification:** any session's cwd opens in local VS Code in ≤2 steps.

### U6. Raycast as a hub + tracking in chezmoi

**Goal:** Script-command hub + recovery-grade, **secret-free** config tracking. **Goals:** G7.
**Files:** `private_dot_config/raycast/scripts/`; `run_onchange_chmod-raycast-scripts.sh`; `docs/raycast-hotkeys.md`; optionally a sanitized `.rayconfig`.
**Approach:** Consolidate script commands under chezmoi. The web app's binding list is canonical. **Before** committing any `.rayconfig`, grep for `token|apiKey|secret|password` and redact (or keep it in 1Password + `.gitignore`). No Pro.
**Verification:** scripts executable after `chezmoi apply`; no secrets in git.

### U1. Cheatsheet web app (React SPA) — built AFTER the config wins

**Goal:** A local, interactive cheatsheet of the per-app workflows, a Glove80 board, and the **manual-setup checklist**. **Goals:** G9.
**Files:** `cheatsheet/` in chezmoi. **First step (before `npm create vite`): add `cheatsheet` to `.chezmoiignore`** so `chezmoi apply` never renders `node_modules` into `$HOME`. Stack: Vite + React + TS + Tailwind + **Fuse.js** (drop cmdk — we need table-filtering, not a command palette).
**Approach:**
- **U1a (first):** searchable workflow tables (the catalog below), the **manual-setup checklist** (every manual action: Chrome profiles, PWAs, each Raycast hotkey, reclaim Cmd+Space, firmware flash, SSH host, register scripts dir, start `proof-local`), and a **learning tracker** — all keyboard-navigable, global fuzzy search (`/`), filters (by-app + learned/unlearned). Tracker = per-row inline toggle keyed on row id; "Learn first" rows visually marked; the "tracker" is just the tables filtered to unchecked (no separate view). **Default the "one card on open"** (show one not-yet-learned binding on load — promoted from U9 as the zero-discipline retention hook). Give the app an **open-trigger**: a Hyper go-to-app chord (U3) + auto-open on login for the first weeks, so opening it is part of the keyboard grammar. The board can use the existing `keymap.svg` here.
- **U1b (later):** port `~/code/glove80/docs/app.js` to a native React 80-key board (key-type coloring, SVG combo overlay, layer tabs, live key-tester), showing the tmux thumb + tmux layer.
- **Persistence:** both "learned" toggles and the SetupChecklist persist to `localStorage` (`learn/` and `setup/` namespaces) so progress survives reload and is resumable mid-setup.
- The setup checklist is authored as a **provisional stub** and its concrete "resulting binding" values are filled in as U2–U6 actually execute.
- **Hosting:** localhost only, manual start. Never published.
**Verification:** opens locally; tables + checklist + tracker work; progress persists.

### U7. Homerow adoption (deferred trigger)

Purchase + install when the catalogued gaps (Slack reactions, Notion DB chrome, Warp block-output copy) become daily friction; activate on a Glove80 thumb/Hyper chord (not `Shift+Space`). Documented in the web app now. **Goals:** G6.

### U8. Proof — local only, with guardrail (already running)

**Goal:** HITL review entirely on `localhost`. **Goals:** G8.
**Status:** the `proof-local` helper is built + committed; Proof runs locally (SQLite, telemetry off). **Remaining:** add the guardrail hook + CLAUDE.md/AGENTS.md note blocking `proofeditor.ai`; **first step: `lsof -iTCP -nP | grep -i proof` — if it binds `0.0.0.0`, add `--host 127.0.0.1` to the `proof-local` invocation and commit it (structural, not a one-time check)**; the loop is "re-publish a fresh doc per round" (agent writes are refused while a browser holds the doc open). **Make plan-review a one-command skill:** a `/plan-review` skill wrapping `proof-local open` + the publish→comment→ingest→re-publish loop, plus a **CLAUDE.md note — when a plan/doc is ready, review it via the local Proof loop** (never the hosted service).

### U9. Practice trainer — speculative, gated on observed need (deferred)

**Goal:** A lightweight recall trainer, **only if** real forgetting is observed. **Goals:** G9.
**Approach:** Ship U1 without it; use the cheatsheet for a few weeks. **Cheap alternative needing zero discipline:** a "one card on open" — when the localhost app loads, show one not-yet-learned binding. If a full drill is still wanted, first decide three things in one sentence: grade scale (pass/fail vs 3-tier), when the answer is revealed, and what "spaced-repetition-lite" means (next-due timestamp vs. shuffle toward low-confidence).

---

## Scope Boundaries

**In scope:** G1–G10, sequenced config-first (U2→U3→U4→U5→U6→U1). **Deferred:** Homerow purchase (U7); the interactive board (U1b); the practice trainer (U9, gated on need); config-driven web-app data (curated first). **Not adopting:** see that section.

---

## Per-app workflow catalog (web-app seed content)

Source legend: native unless **[V]** Vimium / **[H]** needs Homerow (deferred). tmux prefix = `Ctrl+Space` after U4; **bold tmux rows = on the ZMK tmux layer**.

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

**Learn first:** rename `$` · new window `c` · switch `n`/`p` · split `|`/`_` · resize arrows · nav `h/j/k/l` · zoom `z`

### Slack (desktop)
| Task | Keys |
|------|------|
| Quick switcher | `Cmd+K` |
| Next / prev unread | `Opt+Shift+Down`/`Up` |
| Mark read / all read | `Esc` / `Shift+Esc` |
| Unreads / Activity / Threads | `Cmd+Shift+A` / `M` / `T` |
| Message-nav → actions | `Up` → arrows → `R`/`E`/`T` |
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
| Comment / search / copy ID | `Cmd+M`→`Cmd+Enter` / `/` / `Cmd+.` |

**Learn first:** `Cmd+K` · `C` · `G`+`I/M/T/A/B` · `J`/`K`+`Enter` · `S`/`P`/`L`/`A` · `Cmd+.` · `?`

### Gmail (Chrome PWA — Work profile; shortcuts on + Vimium passthrough)
| Task | Keys |
|------|------|
| Compose / send | `c` / `Cmd+Enter` |
| Reply / reply-all / forward | `r` / `a` / `f` |
| List down/up / open / back | `j`/`k` / `o` / `u` |
| Archive / delete / select | `e` / `#` / `x` |
| Go-to Inbox/Starred/Sent | `g` then `i`/`s`/`t` |
| Search / undo | `/` / `z` |
| Click link/attachment | `f` **[V]** |

**Learn first:** `j`/`k` · `e` · `c`/`r`/`a`/`f` · `u` · `g`+`i/s/t` · `x`→`e/#` · `/` · `z`
**Setup:** Gmail Settings → Keyboard shortcuts ON; Vimium excluded-keys `mail.google.com/*` = `?jknpxercgilsafd#ubm/`

### GitHub (Chrome PWA — Work profile)
| Task | Keys |
|------|------|
| File finder / github.dev | `t` / `.` |
| Go-to Code/Issues/PRs/Notifications | `g` then `c`/`i`/`p`/`n` |
| Search | `s` or `/` |
| Notifications: nav/done/read | `j`/`k` / `e` / `Shift+I` |
| PR diff: file nav / whitespace | `j`/`k` / `w` |
| Submit review / comment | `Cmd+Shift+Enter` / `Cmd+Enter` |

**Learn first:** `t` · `.` · `g`+`c/i/p` · `j`/`k`→`e` · `/` · `w`
**Gaps:** next *unviewed* file (use **[V]** `f`) · approve/request-changes (no key)

### Notion (desktop)
| Task | Keys |
|------|------|
| Quick-find / in-page find | `Cmd+P` / `Cmd+F` |
| Sidebar / back / forward / up | `Cmd+\` / `Cmd+[` / `Cmd+]` / `Cmd+Shift+U` |
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
**Custom binds (`keybindings.json`):** `git.stageFile → Cmd+K Cmd+A` · `git.push → Cmd+K Cmd+P` · GitLens changed-file `Opt+]`/`Opt+[`

### Chrome + Vimium
| Task | Keys |
|------|------|
| Follow link same/new tab | `f` / `F` |
| Scroll line / half-page / extremes | `j`/`k` / `d`/`u` / `gg`/`G` |
| History back / forward | `H` / `L` |
| Find in page | `/` then `n`/`N` |
| Vomnibar (url/history) | `o` / `O` |
| Fuzzy switch open tab | `T` |
| **Cycle windows of current app** | `Cmd+`` ` `` (skips minimized/other-Space — see KTD8) |
| New / close / restore tab | `t` / `x` / `X` |

**Learn first:** `f`/`F` · `j`/`k`/`d`/`u` · `T` · `o`/`O` · `H`/`L` · `Cmd+`` ` `` · `x`/`X`

## Transferable grammar (teach once, use everywhere)

- **`g`-then-letter navigation:** Gmail, GitHub, Linear.
- **`j`/`k` list navigation:** Gmail, GitHub, Linear, Vimium, tmux pane-nav.
- **`Cmd+K` / `Cmd+P` command palette:** Slack, Linear / Warp, VS Code, Notion.
- **`/` to search/filter:** Gmail, GitHub, Linear, Vimium, the cheatsheet itself.

## Resolved Decisions

- **Build order → config-first** (r3): U2→U3→U4→U5→U6→U1; web app documents reality after the bindings exist.
- **Thumb layout (r4): keep all four V3/V4 layers + Bksp/Del/Enter/Space + Hyper + Wispr.** The **5 free modifier thumbs** (LCtrl, LAlt, LGui, RCtrl, RAlt) cover tmux + Homerow + app-actions (need 3 of 5); **keep LOWER** (sole numpad/media/F-key layer) and avoid `LCtrl`/pos-53 (Ctrl+Tab combo). Placement chosen **by feel at U4** (reversible per KTD13). **Raycast needs no thumb** — `Cmd+Space`.
- **Cross-device (r4): every action reachable on the MacBook** — Raycast `Cmd+Space`; Raycast Hyper key (Caps Lock) for go-to-app on the laptop; tmux prefix `Ctrl+Space`; firmware thumbs are conveniences (KTD13/G11).
- **KTD1 corrected (r5):** firmware is the *primary* remap layer (we do edit it); the only host-side remap is Raycast's Caps-Lock→Hyper for MacBook parity. No Karabiner.
- **Verify-live (r5, KTD14):** implement → test live on the spot (automated where possible, HITL where not) → continue.
- **Plan-review skill (r5):** wrap the local Proof loop in a `/plan-review` skill + a CLAUDE.md note to use it for plans.
- **CE review r2 (r6):** keep LOWER (not free — media/numpad/F-keys); avoid pos-53 LCtrl (Ctrl+Tab combo); confirm flashed firmware on-device; Wispr laptop trigger = its own app hotkey; web app gets an open-trigger + "one card on open"; `.chezmoiignore` for `cheatsheet` and `.rayconfig`; Proof binds 127.0.0.1 structurally; AeroSpace test window → ~2 weeks; drop cmdk; guard the `pbpaste` path in `code-remote-open` (`[[ "$path" =~ ^/ ]] || exit 1`).
- **Spotlight → disable the shortcut only** (r3), not indexing.
- **U9 practice trainer → deferred + speculative** (r3), gated on observed need; "one card on open" as the cheap default.
- **`.rayconfig` → sanitized before commit** (r3).
- **Web app stack → Vite + React + TS + Tailwind**, no Framer Motion yet; localhost only; U1a (tables/checklist/tracker) before U1b (interactive board).
- **Hyper mapping → pure adjacency** (apps right, window-mgmt left); validate hold-tap latency on-device before locking.
- **VS Code bridge → parameterized command only.** **Homerow → deferred.** **Proof → local only** via `proof-local`.

## Open Questions

- **Q1 — Final Hyper letter grid** — drafted in U3 when hotkeys are recorded; validate hold latency first.
- **Q2 — App-actions layer contents** — the only thumb question left open: what the app-actions hold-layer does (per-app commands). Defined at U4/later. (Thumb layout itself is resolved: keep all four layers + Bksp/Del/Enter/Space + Hyper + Wispr; the 6 free thumbs reserved for tmux / Homerow / app-actions, placed by feel at U4.)

## Sources & Research

- ce-ideate session (2026-06-21): 48 candidates → 7 survivors → 19-agent deep-dive → plan → Proof review r1 → CE multi-lens review (Coherence/Feasibility/Scope/Design/Product/Security/Adversarial) → r3.
- Keymap occupancy verified against `~/code/glove80/config/glove80.keymap:633` + README/ROADMAP (Wispr Flow on a RH thumb; RALT restored in V4; V4/V5 unflashed).
- Proof self-hosting: `EveryInc/proof-sdk` (MIT; local SQLite; telemetry off); run via `proof-local`.
