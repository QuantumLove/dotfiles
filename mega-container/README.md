# Mega-Container Development Environment

Persistent development environment accessible via Tailscale SSH from any device.

## Features

- **Tailscale SSH** - Access from laptop, phone, tablet via `ssh <hostname>`
- **OpenCode web** - Browser UI at `https://raf-dev.koi-moth.ts.net` (tailnet-only, HTTPS via tailscale serve). Works from phone.
- **1Password Integration** - Secrets injected at startup via Service Account
- **chezmoi** - Dotfiles and configuration management
- **mise** - Tool version management (Node, Python, etc.)
- **Claude Code + OpenCode** - AI coding assistants
- **MCP Servers** - Linear, Sentry, GitHub, Toggl, Datadog integrations
- **`mega-doctor`** - One-shot health check (binaries, secrets, mounts, MCPs, opencode web)

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
~/mega-container/start.sh

# First time only: authenticate Tailscale
docker compose exec mega sudo tailscale up --ssh --hostname=raf-dev --accept-routes
# Follow the URL to authenticate with your account
```

## Daily Usage

```bash
# SSH in (hostname may have suffix like raf-dev-1)
ssh raf-dev

# Create or attach a durable work session (work socket)
ws                # session 'main'  (or: ws myproj)
wsl               # list sessions

# Start work on an issue
/setup-work METR-123

# Verify everything is healthy
mega-doctor               # full check (~10-20s, includes MCP/AWS probes)
mega-doctor --quick       # fast, no network probes
```

**From a phone** (or any browser on your tailnet): open `https://raf-dev.koi-moth.ts.net` for the OpenCode web UI — skips tmux entirely.

## Session durability

Work runs in plain tmux on the **`work`** socket (Warp's deprecated `-CC` wrapper is retired in favor of the SSH extension). The tmux server lives in the container, so it survives SSH disconnects — reconnect and `ws` drops you back in. Across container restarts, **supercronic** saves every 5 min (tmux-resurrect, flock-serialized, pane contents included, to a persistent volume) and tmux-resurrect restores on the next start; `tmux-snapshot`/`tmux-restore` additionally capture and resume OpenCode sessions by ID. Agent alerts reach Warp via a terminal bell, since Warp's native agent notifications don't survive tmux+SSH. Requires tmux ≥ 3.5 (built from source in the image — Debian's 3.3a has a resurrect restore crash).

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

## One-Time Auth Setup

### Google Workspace CLI (gws) — Gmail Access

This is a one-time setup. The credential persists in 1Password across container rebuilds.

**Do this on a machine with a browser:**

1. Install gws:
   ```bash
   npm install -g @googleworkspace/cli
   ```

2. Authenticate with your Google account:
   ```bash
   gws auth login
   ```
   When prompted for scopes, ensure `gmail.readonly` and `gmail.modify` are included.

3. Export the credentials:
   ```bash
   gws auth export --unmasked > gws-credentials.json
   ```

4. Store the JSON in 1Password:
   - Vault: **Development**
   - Item name: **GWS Credentials JSON**
   - Type: Secure Note (paste the full JSON into the note body)

5. Delete the local file:
   ```bash
   rm gws-credentials.json
   ```

The mega-container entrypoint fetches this at boot and writes it to `~/.config/gws/credentials.json` automatically.

**If the token expires:** re-run steps 2-4 to refresh the credential in 1Password.

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
./rebuild.sh    # build image + recreate container + full mega-doctor (preserves volumes)
./start.sh      # just start (no rebuild)
```

Volumes are preserved by both scripts. **Never `docker compose down -v`** — the `-v` flag wipes the Tailscale state and re-auth is required.

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Container orchestration (init: true for zombie reaping, healthcheck) |
| `Dockerfile` | Container image definition (apt + binary tools; mise tools live in `.config/mise/config.toml`) |
| `entrypoint.sh` | Bootstrap: 1Password, chezmoi, sshd, cron, opencode web, tailscale serve |
| `start.sh` | Host-side startup wrapper (no rebuild) |
| `rebuild.sh` | Host-side rebuild wrapper (build + recreate + full mega-doctor) |
| `.config/mise/config.toml` | Tool versions (Node, Python, age, sops, gitleaks, tflint, bun, ...) |

## Managed by Chezmoi

This directory is part of the chezmoi dotfiles repo. Changes should be made here and applied with `chezmoi apply`.

Related chezmoi files:
- `private_dot_claude/CLAUDE.md.tmpl` - Claude Code instructions
- `private_dot_claude/plugin-list.txt` - Auto-installed plugins
- `.chezmoiexternal.toml` - Auto-cloned repos (METR plugins)
- `modify_dot_claude.json.tmpl` - MCP server configuration
