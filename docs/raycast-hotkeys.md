# Raycast hotkey inventory (canonical source of truth)

Hand-maintained list of every Raycast / macOS global hotkey. This is the canonical
record (Raycast's own config lives in an encrypted store that can't be diffed), and
the seed for the cheatsheet web app. Update this when you add/change a binding.

**Scheme:** `Hyper` = `Ctrl+Shift+Cmd+Alt` (Glove80 left-thumb key; Raycast records it as `⌃⌥⌘⇧`).
Bilateral & adjacency: **go-to-app = `Hyper` + right-hand letters**, **window-management = `Hyper` + left-hand letters** (disjoint, no collisions).
On the MacBook (no Hyper key): launch via `Cmd+Space` (Raycast) + type — the Hyper chords are a Glove80 speed-up.

## Launcher
| Chord | Action |
|------|--------|
| `Cmd+Space` | **Raycast** (Spotlight shortcut disabled; convenience kept, points at Raycast) |

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
| _(unbound)_ | VS Code | reach via `Cmd+Space`+type or the U5 code-host bridge; bind to a free right key (`P`, `/`, `M`) if wanted |

GitHub: not a hotkey — a Chrome tab (use `Cmd+Shift+A` tab search + Switch Windows below).

## Window management — `Hyper` + left hand (Raycast Window Management)
*(Rafael customized the exact letters — transcribe the final mapping here when ready.)*
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
| `Hyper + ;` | **Raycast "Switch Windows"** — fuzzy-pick ANY open window by title/app. Best for multiple Chrome windows (see + pick, no awkward reach). Pick any free, comfortable key. |
| `Cmd+Shift+A` | Chrome tab search (within a window) |
| `Cmd+`` ` `` | native cycle current-app windows (fallback — awkward on the Glove80) |

## Retired
- `F1`–`F5` Raycast deeplinks (replaced by the Hyper go-to-app chords above).
