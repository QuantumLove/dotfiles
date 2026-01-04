# Minimal Chezmoi Dotfiles

A lightweight dotfile management system using chezmoi for seamless shell configuration across Warp (local Zsh) and VS Code Dev Containers (Bash).

## Features

- **POSIX-compliant shell functions** that work in both Zsh and Bash
- **AWS profile management** (`awstg`, `awspr`)
- **Environment variable loading** (`loadenv`)
- **Project-specific minikube reset** for METR/inspect-action (`minikube_reset`)
- **Minimal overhead** - no heavy frameworks, just what you need

## Quick Start

Bootstrap your environment with a single command:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" && ./bin/chezmoi init --apply QuantumLove
```

## Available Functions

### `awstg [environment]`
Set AWS profile to staging with optional custom environment name.

```sh
awstg          # Sets ENVIRONMENT=staging
awstg dev4     # Sets ENVIRONMENT=dev4
```

### `awspr`
Set AWS profile and environment to production.

```sh
awspr
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

## Dev Container Integration

Add this to your VS Code global `settings.json`:

```json
"dotfiles.repository": "QuantumLove/dotfiles",
"dotfiles.targetPath": "~/dotfiles",
"dotfiles.installCommand": "sh -c \"$(curl -fsLS get.chezmoi.io)\" && ./bin/chezmoi init --apply QuantumLove"
```

## Manual Usage

```sh
# Update your dotfiles
chezmoi update

# See what changes would be applied
chezmoi diff

# Apply changes
chezmoi apply
```

## Structure

- `dot_sh_functions.tmpl` - Core POSIX-compliant functions
- `dot_zshrc.tmpl` - Minimal Zsh config for Warp
- `dot_bashrc.tmpl` - Bash config for Dev Containers
- `run_once_install.sh` - One-time setup script for containers

## License

MIT
