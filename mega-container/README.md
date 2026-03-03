# Mega-Container Development Environment

Persistent development environment accessible via Tailscale SSH from any device.

## Features

- **Tailscale SSH** - Access from laptop, phone, tablet via `ssh <hostname>`
- **1Password Integration** - Secrets injected at startup via Service Account
- **chezmoi** - Dotfiles and configuration management
- **mise** - Tool version management (Node, Python, etc.)
- **Claude Code + OpenCode** - AI coding assistants
- **MCP Servers** - Linear, Sentry, GitHub, Toggl, Datadog integrations

## Prerequisites

**On your Mac:**

1. **1Password Service Account Token** in macOS Keychain:
   ```bash
   # Check if exists
   security find-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w | head -c 20

   # Add if missing (get token from 1Password Dashboard → Service Accounts)
   security add-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w 'YOUR_TOKEN'
   ```

2. **Docker Desktop** running

3. **1Password SSH Agent** enabled (Settings → Developer → SSH Agent)

## Quick Start

```bash
# Start the container
cd ~/.local/share/chezmoi/mega-container
./start.sh

# First time only: authenticate Tailscale
docker compose exec mega sudo tailscale up --ssh --hostname=raf-dev --accept-routes
# Follow the URL to authenticate with your account
```

## Daily Usage

```bash
# SSH in (hostname may have suffix like raf-dev-1)
ssh raf-dev

# Start or attach to tmux session
tmux attach || tmux new -s dev

# Start work on an issue
/start-work METR-123
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Mega Container                                  │
│  ─────────────────────────────────────────────  │
│  • Tailscale daemon (SSH access)                │
│  • User: rafaelcarvalho (matches Tailscale ID)  │
│  • Tools: mise, Claude Code, OpenCode           │
│  • MCP: Linear, Sentry, GitHub, Toggl, Datadog  │
│  └── Secrets via 1Password Service Account      │
└─────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────┐
│  Volumes                                         │
│  • tailscale-state (persists identity)          │
│  • code (~/code - your repositories)            │
└─────────────────────────────────────────────────┘
```

## Troubleshooting

### Container won't start / 1Password auth fails
```bash
# Verify token on host
export OP_SERVICE_ACCOUNT_TOKEN=$(security find-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w)
op account get

# Check logs
docker compose logs mega
```

### SSH connection refused
```bash
# Check container health
docker compose ps

# Re-enable Tailscale SSH
docker compose exec mega sudo tailscale up --ssh --hostname=raf-dev --accept-routes
```

### Tailscale hostname changed (raf-dev-1, raf-dev-2, etc.)
This happens when volumes are deleted. The new hostname is permanent.
Just use the new hostname: `ssh raf-dev-1`

**IMPORTANT: Never use `docker compose down -v`**
The `-v` flag deletes volumes including Tailscale state.

## Rebuilding

```bash
# Rebuild without losing state
docker compose build mega
docker compose up -d

# Full rebuild (will need Tailscale re-auth)
docker compose down
docker compose build --no-cache mega
./start.sh
```

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Container orchestration |
| `Dockerfile` | Container image definition |
| `entrypoint.sh` | Bootstrap script (1Password, chezmoi, plugins) |
| `start.sh` | Host-side startup wrapper |
| `.config/mise/` | Tool versions (baked into image) |

## Managed by Chezmoi

This directory is part of the chezmoi dotfiles repo. Changes should be made here and applied with `chezmoi apply`.

Related chezmoi files:
- `private_dot_claude/CLAUDE.md.tmpl` - Claude Code instructions
- `private_dot_claude/plugin-list.txt` - Auto-installed plugins
- `.chezmoiexternal.toml` - Auto-cloned repos (METR plugins, private-config)
- `modify_dot_claude.json.tmpl` - MCP server configuration
