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

## Go-to-app — `Hyper` + right hand (focus-or-open)
Home row = most-used; reorder freely (Raycast rebinds instantly, no reflash).
| Chord | App | Note |
|------|-----|------|
| `Hyper + J` | Warp | terminal |
| `Hyper + K` | VS Code | |
| `Hyper + L` | Chrome | catch-all browser |
| `Hyper + ;` | Slack | |
| `Hyper + U` | Linear | desktop app |
| `Hyper + I` | Gmail | the **PWA named "Gmail"** (metr.org profile) |
| `Hyper + O` | Notion | |

GitHub: not a hotkey — it's a Chrome tab (use `Cmd+Shift+A` tab search + `Cmd+`` ` `` window cycling).

## Window management — `Hyper` + left hand (Raycast Window Management)
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

## Cycling (native — no Raycast)
| Chord | Action |
|------|--------|
| `Cmd+`` ` `` | Cycle windows of the current app |
| `Cmd+Shift+A` | Chrome tab search |

## Retired
- `F1`–`F5` Raycast deeplinks (replaced by the Hyper go-to-app chords above).
