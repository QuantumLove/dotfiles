---
title: "feat: keyboard-driven, mouse-minimized Mac workflow + interactive cheatsheet web app"
status: in-review
date: 2026-06-21
decisions_locked: 2026-06-21
revised: 2026-06-21 (r8)
build_order: config-first
---

# feat: keyboard-driven, mouse-minimized Mac workflow + interactive cheatsheet web app

## Summary

Make the daily Mac dev stack keyboard-driven and mouse-minimized: the **Glove80 (ZMK) firmware** as the primary remap layer, **Raycast** (`Cmd+Space`) as the host-side hub, and a **local interactive cheatsheet** to document it. **Build order is config-first** — land the daily ergonomic wins (Raycast go-to-app + window management, the tmux thumb/layer, the VS Code bridge) first so the real binding inventory exists, then build the web app to document reality. Decisions and rationale live in the KTDs below; every action is also reachable on the MacBook built-in keyboard (KTD13).

---

## Problem Frame

The stack — Slack, Chrome (Gmail + many windows, two profiles), Warp, VS Code, Notion, Linear — needs too much mouse and repetitive motion. The Glove80 Hyper key is unused for app control; go-to-app is on `F1–F5` Raycast deeplinks (to retire); tmux uses the default `Ctrl+B`; opening a remote dev-container folder in host VS Code is manual across ~10 parallel sessions; and there's no single place to learn the workflows or the manual setup steps.

---

## Goals

- **G1** — Go-to-app via bilateral Hyper chords (left thumb engages, right hand picks); retire `F1–F5`. → U3
- **G2** — Window placement + window cycling in 1–2 keys via Raycast. → U3
- **G3** — Gmail as a Chrome PWA (named "Gmail"); two profiles (metr.org + Rafael); GitHub stays a tab. → U2, U3
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

- **KTD1 — Glove80 firmware is the only remap layer; no host remapper at all.** Remapping lives in the firmware — which we *do* edit (thumbs, layers) — so **no Karabiner and no Caps-Lock remap**. Raycast is a *launcher* bound to `Cmd+Space` (a hotkey, not a remap). On the MacBook (no Hyper key) you launch via Raycast `Cmd+Space` + type; `Hyper+letter` go-to-app is a Glove80-only speed-up (KTD13).
- **KTD2 — Raycast owns app-focus, window placement, and window cycling** (G1, G2). Every Window Management command takes its own recorded hotkey, so there's no typing/search.
- **KTD3 — Gmail as a PWA; GitHub stays a tab** (G3). **Gmail** installs as a Chrome PWA (app named "Gmail") — a distinct, focusable macOS app with its own go-to-app hotkey. **GitHub is *not* a PWA** (PWAs handle multiple tabs poorly); it stays a normal Chrome tab, reached via Chrome's tab search (`Cmd+Shift+A`) + window cycling (KTD8).
- **KTD4 — Two Chrome profiles: metr.org (work) + Rafael (personal)** (G3). The Gmail PWA lives in the **metr.org** profile.
- **KTD5 — Bilateral Hyper, chords not a nav layer** (G1). Mappings live in Raycast (rebind without reflashing). Hyper is the HOLD side of a hold-tap on the **left** thumb (`&hyper_mt HYPER LSHFT`, pos verified), so app letters go on the **right** hand and window-management letters on the **left** hand. **Letters = pure adjacency.** *Caveat:* chord speed is gated by the hold-tap tapping-term — if go-to-app feels laggy, tune `hyper_mt`, and do a quick on-device head-to-head vs. a nav layer before locking the grid (mappings are cheap to rebind).
- **KTD6 — `Cmd+Space` opens Raycast (taken from Spotlight); plus an optional Raycast thumb** (G10). Disable *only* the `Cmd+Space` Spotlight shortcut (indexing/Finder-search/Look-Up stay intact) and set Raycast's hotkey = `Cmd+Space`. The convenient launcher chord is **kept** — just pointed at the better tool — and it works on the MacBook built-in keyboard, so Raycast is always reachable without the Glove80. **We also have a spare free thumb, so a dedicated Raycast thumb** (a clean right free thumb #7/#8, *emitting `Cmd+Space`*) gives one-tap Raycast on the Glove80 while `Cmd+Space` stays universal.
- **KTD7 — Free thumbs reserved for tmux + Raycast + Homerow + app-actions; positions chosen by feel at U4** (G4). **Locked thumbs:** Hyper, Wispr (`&wispr LG(F18) LG(F19)` — dictation, never clobber), and Backspace/Delete/Enter/Space (whose holds carry the kept Cursor/Number/Mouse/Symbol layers). The **5 genuinely-free thumbs** — `LCtrl`, `LAlt`, `LGui`, `RCtrl`, `RAlt` (all true home-row-mod duplicates) — cover the four functions below (1 of the 5 still spare). **Leave the LOWER thumb alone:** it's the *sole* gateway to the LOWER layer (media keys, brightness/volume, F11/F12, full numpad, CAPS/INS — `keymap:638-646`), so reassigning it deletes those with no fallback. **Avoid the `LCtrl` thumb (pos 53) for frequently-tapped functions** — it's half of the `Ctrl+Tab` combo (positions 53+70); prefer LAlt/LGui/RCtrl/RAlt. The four functions: **tmux** (tap = prefix `Ctrl+Space`, hold = `tmux_layer`, reusing the existing `lt_thumb` hold-tap), a **Raycast thumb** (emits `Cmd+Space` — one-tap Raycast on the Glove80; `Cmd+Space` stays the universal/MacBook path), **Homerow activation**, and an **app-actions layer** (a right-hand hold layer; contents defined later). Exact thumb→function placement is decided **hands-on by feel when flashing (U4)** against the live keymap — KTD13 (cross-device) makes this low-stakes and fully reversible. **All four V3/V4 layers are kept.**
- **KTD8 — Window cycling, with a known gap** (G2). `Cmd+`` ` `` cycles windows of the current app, and a Raycast "Switch Windows" hotkey cycles across apps. **Gap:** `Cmd+`` ` `` skips minimized and other-Space windows — U3 includes a falsification test for these cases (see Not Adopting → AeroSpace).
- **KTD9 — The tmux ZMK layer carries the whole vocabulary** (G4). Holding the tmux thumb maps the home row to: rename session, new window, kill window, next/prev/by-number window, new pane (split right/down), resize panes, pane nav (h/j/k/l), zoom, session tree, copy-mode, detach.
- **KTD10 — Web app is a local React SPA, content-first, built AFTER the config wins** (G9). Vite + React + TS + Tailwind (+ Fuse.js/cmdk; **no Framer Motion** until a transition needs it). Runs on `localhost`, started manually, never published. Built once the real bindings exist so its content is accurate. Split: **U1a** (searchable workflow tables + setup checklist + learning tracker — ships first, can use the existing `keymap.svg` for the board) and **U1b** (the from-scratch interactive React board + key-tester — later). **Migration (per Rafael):** when U1 lands, fold the existing Glove80 keymap viewer (`~/code/glove80/docs`) into this same React architecture — ingest the regenerated `keymap.yaml`, retire the hand-maintained `keymap-data.js`, and serve one unified local app.
- **KTD11 — Raycast tracking is partial-by-nature** (G7). Script-command files in chezmoi (plain files; feed the web app); the web app's binding list + `raycast-hotkeys.md` / `manual-setup.md` are the canonical human-readable source. **No `.rayconfig` export** (decided against — a password-encrypted blob, not diffable; the scripts + inventories already make a new machine reproducible). No Raycast Pro.
- **KTD12 — Proof is local-only with a guardrail** (G8). Proof runs on the container, reached via the tunnelled `localhost`; a `deny` rule + CLAUDE.md note forbid any call to `proofeditor.ai`/Proof AI (the host classifier also blocks such uploads).
- **KTD13 — Cross-device: every action works on the MacBook built-in keyboard too** (G11). Rafael isn't always on the Glove80, so every important action has a **host-level chord reachable on the MacBook**, and the Glove80 thumbs/layers only *emit* those chords (pure ergonomics, never the only path). Concretely: Raycast = `Cmd+Space` (universal); on the MacBook, launch apps via Raycast (`Cmd+Space` + type the app name) — the `Hyper+letter` go-to-app chords are a Glove80 speed-up, **not** needed on the laptop (no Caps-Lock remap); tmux prefix = `Ctrl+Space` (universal) — the ZMK tmux layer is a convenience and prefix+key is the MacBook fallback; Wispr's MacBook trigger is its **own app-level hotkey** (already configured in Wispr Flow for laptop use) — *not* `Cmd+F18`, which is only the Glove80 firmware trigger (F13–F19 don't exist on the MacBook function row). This is *why* the thumb layout can stay relaxed — the firmware adds comfort, not capability.
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
**Approach:** Add the Linear cask (done ✓). Create **two Chrome profiles: "metr.org"** (work) and **"Rafael"** (personal). In metr.org, install **Gmail** as a PWA (app named "Gmail"); **GitHub stays a tab**. Install Vimium; per-site excluded-keys are **optional/as-needed** — only if Vimium conflicts with an app's native keys (Gmail's coexist fine for Rafael, so likely skip). Homerow documented, not purchased.
**Verification:** Linear launches ✓; metr.org + Rafael profiles exist; Gmail is a standalone PWA (named "Gmail"); GitHub opens as a tab; Vimium coexists with Gmail's native keys.

### U3. Raycast go-to-app + window management + cycling; reclaim Cmd+Space

**Goal:** Bilateral Hyper hotkeys; window placement + cycling in 1–2 keys; `Cmd+Space` → Raycast. **Goals:** G1, G2, G10.
**Files:** Raycast config (captured in `docs/raycast-hotkeys.md`); macOS System Settings (manual).
**Approach:** Disable the Spotlight `Cmd+Space` shortcut; set Raycast hotkey = `Cmd+Space` (the universal launcher — works on the MacBook too). Delete `F1–F5`. Record `Hyper`+right-letter app-focus (focus-or-open) for Linear, Slack, Warp, VS Code, Notion, **Gmail** (the PWA named "Gmail"), Chrome. Record `Hyper`+left-letter Window Management. Multi-tab/window: Chrome **tab search (`Cmd+Shift+A`)** + window cycling (`Cmd+`` ` ``). No Caps-Lock remap — on the MacBook, launch via Raycast `Cmd+Space` + type. **Falsification test:** tally minimized/other-Space cycling friction over **~2 weeks** (a tick in the tracker), not a single day → if it's real, trigger the AeroSpace revisit.
**Verification:** every chord focuses/places/cycles in ≤2 keys; `Cmd+Space` opens Raycast; F1–F5 retired.

### U4. Glove80 firmware: tmux thumb + tmux layer; tmux.conf

**Goal:** tmux thumb (tap=prefix/hold=layer with the full op set), prefix → `Ctrl+Space`. **Goals:** G4.
**Files:** `~/code/glove80/config/glove80.keymap`; `dot_tmux.conf`.
**Approach (order matters):**
1. **Confirm the flashed firmware version on-device first** (README says "V5 current"; ROADMAP says "not yet flashed" — reconcile those docs and check what the board actually runs). If already on V4/V5, just add the tmux layer; if on V3, flash V4/V5 first and verify, then add tmux. Then **audit live thumb occupancy** against the keymap and place tmux, a **Raycast thumb** (emits `Cmd+Space`), Homerow activation, and the app-actions layer onto the **5 free modifier thumbs (prefer LAlt, LGui, RCtrl, RAlt — avoid `LCtrl`/pos-53, it's in the Ctrl+Tab combo)** by feel. **Keep the LOWER thumb (sole access to media/numpad/F-keys) and never touch `&wispr`.**

**Status (written, building):** on branch `feat-tmux-thumb` in `~/code/glove80`: `#define TMUX 11`, `tmux_key` macro, `tmux_layer`, RAlt→`&lt_thumb TMUX LC(SPACE)` (tmux thumb), LGui→`&kp LG(SPACE)` (Raycast thumb); chezmoi `tmux.conf` prefix→`Ctrl+Space`. Homerow (LAlt) + app-actions (RCtrl) left as modifiers until those features exist. `build.sh` is compiling the UF2; **next: flash + on-device tune.** `keymap.yaml`/`keymap.svg` regenerated; interactive `keymap-data.js` stale until the U1 migration.
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
**Files:** `private_dot_config/raycast/scripts/` (cloud-search, open-in-vscode); `docs/raycast-hotkeys.md`; `docs/manual-setup.md`.
**Approach (done):** Script commands consolidated under chezmoi (Cloud Search resolves the Chrome profile by name; legacy `~/raycast-scripts/` retired). The web app's binding list + inventory docs are canonical. No `.rayconfig`, no Pro.
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
**Status (done):** Proof runs **on the container** (loopback-bound via the QuantumLove/proof-sdk fork), kept up by a supercronic watchdog; the host reaches it through `proof-local tunnel` (or the `com.rafael.proof-tunnel` LaunchAgent). Driven by the **`/plan-review`** skill (publish → annotate → ingest → re-publish per round, since agent writes are refused while a browser holds the doc). Guardrail: a `deny` rule blocks `proofeditor.ai` + a CLAUDE.md "local only" note. Full setup in manual-setup.md §6.

### U9. Practice trainer — speculative, gated on observed need (deferred)

**Goal:** A lightweight recall trainer, **only if** real forgetting is observed. **Goals:** G9.
**Approach:** Deferred — the U1a "one card on open" hook covers retention for now. If a full drill is later wanted, decide three things first: grade scale (pass/fail vs 3-tier), when the answer is revealed, and what "spaced-repetition-lite" means (next-due vs. shuffle-toward-low-confidence).

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

### GitHub (Chrome tab — metr.org profile; tab search `Cmd+Shift+A` + `Cmd+`` ` `` to reach windows)
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

- **Build order: config-first** — U2→U3→U4→U5→U6→U1; the web app documents reality after the bindings exist.
- **Thumb layout** (full rules in KTD7): keep all four V3/V4 layers + Bksp/Del/Enter/Space + Hyper + Wispr; the 5 free modifier thumbs carry tmux + Raycast (done) and reserve Homerow + app-actions; keep LOWER, avoid `LCtrl`/pos-53; placed by feel.
- **Cross-device** (KTD13): every action works on the MacBook — Raycast `Cmd+Space`, tmux prefix `Ctrl+Space`. **No Caps-Lock→Hyper remap** — the `Hyper`+letter go-to-app chords are a Glove80-only speed-up.
- **Firmware is the only remap layer** — no Karabiner.
- **Verify-live** (KTD14): implement → test on the spot → continue.
- **Chrome:** two profiles (metr.org work + Rafael personal); only Gmail is a PWA, GitHub stays a tab.
- **Spotlight:** disable the `Cmd+Space` shortcut only (not indexing); it points at Raycast.
- **Proof: local only** — runs on the container, reached via `proof-local tunnel`; a `deny` rule blocks `proofeditor.ai`; driven by `/plan-review`.
- **No `.rayconfig` export** — scripts + `raycast-hotkeys.md`/`manual-setup.md` cover reproduction.
- **Web app:** Vite + React + TS + Tailwind + Fuse.js, localhost only; U1a (tables/checklist/tracker) before U1b (interactive board).
- **Hyper mapping: pure adjacency** (apps right, window-mgmt left); validate hold-tap latency on-device first.
- **Deferred:** Homerow (U7 — buy when gaps bite); practice trainer (U9 — "one card on open" covers retention).

## Open Questions

- **Q1 — Final Hyper letter grid** — drafted in U3 when hotkeys are recorded; validate hold latency first.
- **Q2 — App-actions layer contents** — what the app-actions hold-layer does (per-app commands). Deferred; RCtrl stays a plain modifier until then. Thumb layout otherwise resolved per KTD7.

## Sources & Research

- ce-ideate session (2026-06-21): 48 candidates → 7 survivors → 19-agent deep-dive → plan → Proof review r1 → CE multi-lens review (Coherence/Feasibility/Scope/Design/Product/Security/Adversarial) → r3.
- Keymap occupancy verified against `~/code/glove80/config/glove80.keymap:633` + README/ROADMAP (Wispr Flow on a RH thumb; RALT restored in V4; V4/V5 unflashed).
- Proof self-hosting: `EveryInc/proof-sdk` (MIT; local SQLite; telemetry off); run via `proof-local`.
