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
- **Copy the dir without leaving your work:** in tmux, tap the tmux thumb (= prefix) then **`o`** — tmux copies the focused pane's directory to the Mac clipboard via OSC52, even while opencode/a TUI owns the pane (it reads `pane_current_path` at the multiplexer level; nothing is interrupted). `cpwd` is the manual fallback when you have a free shell.
- Then trigger Raycast **"Open in VS Code"** (blank arg = clipboard) → the folder opens in local VS Code.

## 5. Glove80 firmware (U4)
- Keymap changes live on branch `feat-tmux-thumb` in `~/code/glove80` (tmux thumb on RAlt, Raycast thumb on LGui→`Cmd+Space`, `tmux_layer`).
- Build: `cd ~/code/glove80 && ./build.sh` (Docker; ~5–10 min) → `glove80_lh.uf2` + `glove80_rh.uf2`.
- Flash each half (bootloader mode → drag-drop its UF2). See the glove80 `README.md` §Flash.
- `tmux.conf` prefix `Ctrl+Space` is already in chezmoi.
- After any keymap change: `./bin/draw-keymap.sh` regenerates the diagram.

## 6. Proof — local plan review (U8)
Proof runs **on the container** (raf-dev); the host reaches it over an SSH tunnel. Both ends are **automated** — you shouldn't start either by hand.
- **Container (one-time):** clone the fork (it carries the loopback bind + self-hosting proxy fix):
  ```
  git clone -b local-run https://github.com/QuantumLove/proof-sdk ~/code/proof-sdk
  (cd ~/code/proof-sdk && npm install)
  ```
  After that, the **supercronic crontab** (`proof-local ensure`, chezmoi-managed) keeps Proof up: it starts within a minute of container boot and restarts it if it dies. API `127.0.0.1:4000`, editor `127.0.0.1:3000`, telemetry off.
- **Host (one-time):** `launchctl load -w ~/Library/LaunchAgents/com.rafael.proof-tunnel.plist`. The `com.rafael.proof-tunnel` LaunchAgent (chezmoi-managed) then runs the SSH tunnel at login and re-establishes it (`KeepAlive` + `ServerAliveInterval`) whenever the container comes back. Manual fallback: `proof-local tunnel`.
- Review with the **`/plan-review <file.md>`** skill; `localhost:3000` shows the docs in the browser. Never use the hosted `proofeditor.ai`.
