# Raycast hotkey inventory (canonical source of truth)

Hand-maintained list of every Raycast / macOS global hotkey. This is the canonical
record (Raycast's own config lives in an encrypted store that can't be diffed), and
the seed for the cheatsheet web app. Update this when you add/change a binding.

**Scheme:** `Hyper` = `Ctrl+Shift+Cmd+Alt` (Glove80 left-thumb key; Raycast records it as `⌃⌥⌘⇧`).
Bilateral & adjacency: **go-to-app = `Hyper` + right-hand letters**, **window-management = `Hyper` + left-hand letters** (disjoint, no collisions).
On the MacBook (no Hyper key): launch via `Cmd+Space` (Raycast) + type — the Hyper chords are a Glove80 speed-up.

## Recommended thumb placement (U4 — final by feel at flash)

```
                   LEFT THUMBS                                  RIGHT THUMBS
           outer     mid      inner                    inner     mid      outer
         ┌───────┬───────┬───────┐                  ┌───────┬───────┬───────┐
   upper │ HYPER │ LCtrl │ LOWER │                  │ LGui  │ RCtrl │ Wispr │
         │ keep  │ spare │ keep  │                  │→RAYCST│→APPACT│ keep  │
         ├───────┼───────┼───────┤                  ├───────┼───────┼───────┤
   lower │ Bksp  │ Del   │ LAlt  │                  │ RAlt  │ Enter │ Space │
         │CURSOR │NUMBER │→HOMROW│                  │→TMUX  │ MOUSE │SYMBOL │
         └───────┴───────┴───────┘                  └───────┴───────┴───────┘

   keep = unchanged   →WORD = recommended new function   spare = leave (Ctrl+Tab combo)
```

- **TMUX** → right lower-inner (RAlt): tap = prefix `Ctrl+Space`, hold = tmux layer. Sits with the terminal thumbs.
- **RAYCAST** → right upper-inner (LGui): emits `Cmd+Space` (one-tap Raycast; `Cmd+Space` stays universal).
- **APP-ACTIONS** → right upper-mid (RCtrl): hold-layer ("right hand = actions"); contents TBD.
- **HOMEROW** → left lower-inner (LAlt): activation key (when Homerow is adopted).
- **spare** → left upper-mid (LCtrl): leave free (it's half of the `Ctrl+Tab` combo, pos 53).

## Launcher
| Chord | Action |
|------|--------|
| `Cmd+Space` | **Raycast** (Spotlight shortcut disabled; convenience kept, points at Raycast) — universal, works on the MacBook too |
| Glove80 Raycast thumb (free thumb #7/#8, set at U4) | emits `Cmd+Space` → one-tap Raycast on the board |

## Go-to-app — `Hyper` + right hand (focus-or-open) — AS RECORDED
Layout logic: **top row (U/I/O) = comms**, **middle row (J/K/L) = daily drivers**.
| Chord | App | Note |
|------|-----|------|
| `Hyper + J` | Warp | middle row = daily |
| `Hyper + K` | Chrome | |
| `Hyper + L` | Notion | |
| `Hyper + U` | Slack | top row = comms |
| `Hyper + I` | Gmail | the **PWA named "Gmail"** (metr.org profile) |
| `Hyper + O` | Linear | desktop app |
| (left-hand key) | VS Code | bound on the left hand (kept live) |

GitHub: not a hotkey — a Chrome tab (use `Cmd+Shift+A` tab search + Switch Windows below).

## Window management — `Hyper` + left hand (Raycast Window Management)
*(Kept live by Rafael — ~10 left-hand bindings, plus the VS Code go-to-app on the left. Not transcribed (intentional); room for more if needed.)*
| Chord | Command |
|------|---------|
| `Hyper + A` | Left half |
| `Hyper + F` | Right half |
| `Hyper + E` | Top half |
| `Hyper + C` | Bottom half |
| `Hyper + S` | Maximize |
| `Hyper + D` | Center (reasonable size) |
| `Hyper + W` | Left two-thirds |
| `Hyper + R` | Right two-thirds |
| `Hyper + X` | Move to next display |
| `Hyper + Z` | Restore (undo last placement) |

## Window switching / cycling
| Chord | Action |
|------|--------|
| `Hyper + H` | **Cycle current-app windows** — macOS "Move focus to next window" rebound (from the awkward backtick) to `Hyper+H`: System Settings → Keyboard → Keyboard Shortcuts → **Keyboard**. Cycles ONLY the front app's windows (e.g. Chrome), system-wide, no backtick, works on the MacBook too. **Not a Chrome setting** — Chrome can't cycle windows. (Hyper already includes Shift → forward-only, fine for a few windows.) |
| `Hyper + ;` | Raycast "Switch Windows" — fuzzy-pick a *specific* window across all apps (a picker, not a cycler) |
| `Cmd+Shift+A` | Chrome tab search (within a window) |

## Retired
- `F1`–`F5` Raycast deeplinks (replaced by the Hyper go-to-app chords above).
