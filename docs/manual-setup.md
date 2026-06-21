# Manual setup steps (new-machine reproduction)

`chezmoi apply` + the Brewfile handle the automatable parts. These are the GUI /
System-Settings steps that **can't be scripted** — run them on a new Mac (e.g. the
second laptop). Exact chords live in [raycast-hotkeys.md](raycast-hotkeys.md).

## 0. Base (automatable)
- `chezmoi apply` — deploys configs, scripts (`code-remote-open`, Raycast scripts), `~/.ssh/config`, `sh_functions` (incl. `cpwd`).
- `brew bundle --file ~/.local/share/chezmoi/Brewfile` — installs Linear, Raycast, Chrome, Warp, VS Code, Slack, Notion, Wispr Flow, etc.

## 1. Raycast — launcher + hotkeys
- Settings → General → **Raycast Hotkey = `Cmd+Space`**.
- System Settings → Keyboard → Keyboard Shortcuts → **Spotlight** → uncheck "Show Spotlight search" (frees `Cmd+Space`).
- Settings → Extensions → **Script Commands** → add directory **`~/.config/raycast/scripts`** (enables the "Open in VS Code" bridge command).
- Record **go-to-app** hotkeys (`Hyper` + right hand, focus-or-open) — see raycast-hotkeys.md.
- Record **window-management** hotkeys (`Hyper` + left hand) — see raycast-hotkeys.md.
- Bind **Switch Windows** → `Hyper+;`.

## 2. macOS
- System Settings → Keyboard → Keyboard Shortcuts → **Keyboard** → "Move focus to next window" → record **`Hyper+H`** (ergonomic current-app window cycling).

## 3. Chrome
- Create two profiles: **metr.org** (work) + **Rafael** (personal).
- In metr.org: `mail.google.com` → ⋮ → Cast/Save & Share → **Install page as app** → the Gmail PWA (named "Gmail").
- Install **Vimium** (per-site passthrough only if a conflict appears).
- The Raycast **Cloud Search** script resolves the Chrome profile *directory* from its display name (`metr.org`) at runtime, so it works on any machine regardless of profile creation order — **no per-machine edit needed.** (Needs `jq`; the script adds Homebrew to PATH.) Tracked scripts live in `~/.config/raycast/scripts/`; the legacy `~/raycast-scripts/` folder is retired.

## 4. VS Code bridge (U5)
- Install the Remote-SSH extension.
- `~/.ssh/config` already has `Host raf-dev` (via chezmoi).
- Test: from a `raf-dev` session run `cpwd`, then trigger Raycast **"Open in VS Code"** → the folder opens in local VS Code.

## 5. Glove80 firmware (U4, later)
- Flash firmware (confirm version on-device); add the tmux thumb (tap=prefix `Ctrl+Space`, hold=tmux layer); choose thumb placement by feel. See the plan, U4.
