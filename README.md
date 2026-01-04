# Minimal Chezmoi Dotfiles

A lightweight dotfile management system using chezmoi for seamless shell configuration across Warp (local Zsh) and VS Code Dev Containers (Bash).

## Features

- **POSIX-compliant shell functions** that work in both Zsh and Bash
- **AWS profile management** (`awstg`, `awspr`)
- **Environment variable loading** (`loadenv`)
- **Project-specific minikube reset** for METR/inspect-action (`minikube_reset`)
- **Non-invasive** - appends to existing configs without overwriting
- **Minimal overhead** - no heavy frameworks, just what you need

## Available Functions

### `awstg [environment]`
Set AWS profile to staging with optional custom environment name.

```sh
awstg          # Sets AWS_PROFILE=staging, ENVIRONMENT=staging
awstg dev4     # Sets AWS_PROFILE=staging, ENVIRONMENT=dev4
```

### `awspr`
Set AWS profile and environment to production.

```sh
awspr          # Sets AWS_PROFILE=production, ENVIRONMENT=production
```

### `loadenv <file>`
Load and export environment variables from a file.

```sh
loadenv .env
```

### `minikube_reset`
Reset minikube cluster for the METR/inspect-action project (only works within that repository).

```sh
minikube_reset
```

---

## Setup Instructions

### 🖥️ Local Machine (macOS/Linux with Zsh or Bash)

**First time setup:**

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" && ./bin/chezmoi init --apply QuantumLove
```

**After setup:**
- Open a new terminal window/tab
- Functions will be available automatically
- In existing terminals, run: `source ~/.zshrc` (or `source ~/.bashrc`)

**To update dotfiles later:**
```sh
chezmoi update
```

---

### 🐳 VS Code Dev Containers (Automatic)

**One-time VS Code configuration:**

1. Open VS Code User Settings JSON:
   - Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
   - Type: "Preferences: Open User Settings (JSON)"
   - Click on the result

2. Add these settings to your `settings.json`:

```json
{
  "dotfiles.repository": "https://github.com/QuantumLove/dotfiles.git",
  "dotfiles.targetPath": "~/dotfiles",
  "dotfiles.installCommand": "install.sh"
}
```

3. Save the file

**How it works:**
- When you open **any** project in a Dev Container, VS Code will:
  1. Clone this dotfiles repo to `~/dotfiles` in the container
  2. Run the `install.sh` script automatically
  3. Apply all your custom functions

**After rebuilding a container:**
- Open a new terminal in VS Code
- Functions are available immediately!
- No need to source anything - they load automatically

**To test:**
```sh
awstg dev4
echo $ENVIRONMENT  # Should show: dev4
```

---

### 🆕 New VS Code Installation

When setting up VS Code on a new machine:

1. **Install VS Code** (if not already installed)
2. **Configure dotfiles** (follow "VS Code Dev Containers" section above)
3. **For local shell**, also run the local machine setup:
   ```sh
   sh -c "$(curl -fsLS get.chezmoi.io)" && ./bin/chezmoi init --apply QuantumLove
   ```

This ensures:
- ✅ Your local terminals (Warp, Terminal.app, etc.) have the functions
- ✅ VS Code's integrated terminal has the functions
- ✅ All Dev Containers automatically get the functions

---

## How It Works

### Architecture

```
┌─────────────────────────────────────────┐
│  dot_sh_functions.tmpl                  │  ← Core POSIX functions
│  (Works in both Bash and Zsh)          │
└─────────────────────────────────────────┘
                    ▲
                    │
        ┌───────────┴───────────┐
        │                       │
┌───────┴─────────┐    ┌───────┴──────────┐
│  dot_zshrc.tmpl │    │  Bash (Container)│
│  (Local Warp)   │    │  Appends to      │
│                 │    │  existing .bashrc│
└─────────────────┘    └──────────────────┘
```

### Files Explained

- **`dot_sh_functions.tmpl`** - All custom shell functions (POSIX-compliant)
- **`dot_zshrc.tmpl`** - Minimal Zsh config that loads functions (for local Warp/terminal)
- **`dot_bash_profile.tmpl`** - Loads functions in Bash login shells
- **`run_once_after_configure_bashrc.sh`** - Appends function loading to existing `.bashrc` (for Dev Containers)
- **`install.sh`** - VS Code dotfiles installer (runs automatically in containers)

### Why Non-Invasive?

Unlike traditional dotfiles that replace entire config files:
- **Zsh (local)**: Creates a new `.zshrc` (Warp doesn't need much config)
- **Bash (containers)**: *Appends* to existing `.bashrc` to preserve colors, prompts, and container-specific settings

---

## Manual Operations

### Update dotfiles from GitHub
```sh
chezmoi update
```

### Preview changes before applying
```sh
chezmoi diff
```

### Force reapply all dotfiles
```sh
chezmoi apply --force
```

### Edit a dotfile template
```sh
chezmoi edit ~/.sh_functions
```

### View chezmoi source directory
```sh
chezmoi source-path
# Usually: ~/.local/share/chezmoi
```

---

## Troubleshooting

### Functions not available in Dev Container

**Symptom:** `awstg: command not found` in Dev Container terminal

**Solution:**
1. Open a new terminal in VS Code (important!)
2. Or restart your terminal: `bash -l`
3. Or manually source: `source ~/.bashrc`

### Functions not available locally

**Symptom:** Functions don't work in local Warp/terminal

**Solution:**
```sh
# Check if dotfiles were applied
ls -la ~ | grep sh_functions

# If missing, reapply
chezmoi apply

# Source immediately
source ~/.zshrc  # or ~/.bashrc for Bash
```

### Lost terminal colors in Dev Container

**Cause:** Old version of dotfiles overwrote `.bashrc`

**Solution:** Already fixed! Current version appends instead of replacing.

---

## Repository

- **GitHub:** https://github.com/QuantumLove/dotfiles
- **Bootstrap URL:** `QuantumLove` (for chezmoi init)

## License

MIT
