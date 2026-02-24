# Mega-Container Implementation Handoff

**Date:** 2026-02-24
**Status:** Phase 1 in progress

## Key Principles

1. **FAIL HARD, NOT SOFT** - If something is broken, exit with error. Never silently continue with degraded functionality. Missing secrets = immediate exit. Broken dependencies = immediate exit.

2. **Fail Fast** - Validate all requirements at startup before doing any work.

3. **Explicit over Implicit** - Log what's happening. Show key counts, connection status, etc.

## Overall Project

Containerized development environment for Claude Code with:
- **Tailscale** sidecar for METR network access (interactive login, persists across restarts)
- **1Password** for secrets injection via Service Account Token
- **chezmoi** for dotfiles/config management
- **mise** for pre-installed dev tools (node, python, kubectl, helm, gh, k9s, aws-cli, etc.)
- **SSH Agent** forwarding via Docker Desktop magic path
- **SSH Server** for remote access (publickey auth only, no passwords)

**Plan file:** `~/code/docs/plans/2026-02-21-feat-claude-setup-mega-container-plan.md`

## What's Working

1. **Docker image built successfully** - All tools pre-installed
   - Debian Bookworm base with UID 501 (matches macOS)
   - 1Password CLI, chezmoi, mise
   - mise tools: node 22, python 3.12, opentofu, kubectl, helm, gh, yq, uv, k9s, aws-cli
   - OpenCode and Claude Code via npm

2. **Tailscale connected** - `mega-dev` hostname
   - Interactive login completed (browser auth)
   - State persists in `tailscale-state` volume

3. **SSH access working** - `ssh mega-dev`
   - Password authentication disabled
   - Publickey auth from forwarded SSH agent
   - Host key checking disabled in `~/.ssh/config`

4. **SSH Agent forwarding working**
   - Uses Docker Desktop magic path: `/run/host-services/ssh-auth.sock`
   - `ssh-add -l` works inside container
   - `ssh -T git@github.com` works

5. **Claude Code and OpenCode working over SSH**
   - Tested: `ssh mega-dev claude` launches successfully
   - Tested: `ssh mega-dev opencode` launches successfully

6. **tmux persistence working**
   - `tmux new -s dev` creates session
   - `Ctrl+B D` detaches
   - `tmux attach -t dev` reattaches after reconnect

## Remaining Tests

- [x] Phone SSH test - Connect from iOS ✅
- [x] oh-my-opencode installed (plan item 1.6.2) ✅
- [x] MCP servers credentials in config (plan item 1.6.5) ✅ (Linear, Sentry tokens via chezmoi)
- [x] gh CLI auto-authentication via GH_TOKEN ✅
- [x] Claude Code API key injection (skips login prompt) ✅
- [ ] /where-am-i skill test (plan items 1.7.2-1.7.3)

## Files

All in `~/.local/share/chezmoi/mega-container/`:

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-tool container image |
| `docker-compose.yml` | Tailscale sidecar + mega container |
| `start.sh` | Host wrapper (keychain → env var → compose up) |
| `entrypoint.sh` | Container bootstrap (1Password, SSH, chezmoi, mise) |
| `.config/mise/config.toml` | Pre-installed tool versions (uses asdf backends) |
| `.dockerignore` | Excludes docs and git from build context |

Related files:
- `~/.local/share/chezmoi/dot_bash_profile.tmpl` - mise activation for SSH login shells
- `~/.local/share/chezmoi/private_dot_claude/skills/mega:where-am-i/SKILL.md`
- `~/.ssh/config` - mega-dev host entry (skip host key checking)

## Key Fixes Made During Build

1. **SSH socket**: Used Docker Desktop magic path `/run/host-services/ssh-auth.sock` instead of 1Password socket
2. **UID 501**: Container user matches macOS for socket permissions
3. **asdf backends**: Switched from aqua to asdf backends to avoid GitHub API rate limits
4. **Direct install for helm/gh**: asdf plugins broken, installed via curl
5. **SSH in login shell**: Added mise to `.bash_profile` (SSH reads this, not `.bashrc`)
6. **chezmoi ordering**: entrypoint runs mise activation AFTER chezmoi apply
7. **Removed no-new-privileges**: Blocked sudo for sshd

## Commands Reference

```bash
# Start containers
cd ~/.local/share/chezmoi/mega-container && ./start.sh

# SSH into container
ssh mega-dev

# Inside container - start tmux session
tmux new -s dev

# Detach from tmux
Ctrl+B D

# Reattach after reconnect
ssh mega-dev
tmux attach -t dev

# Rebuild after changes
cd ~/.local/share/chezmoi/mega-container
docker compose up -d --build mega
```

## Session Context

- Working directory: `/Users/rafaelcarvalho/code`
- chezmoi source: `~/.local/share/chezmoi/`
- User: rafaelcarvalho (METR)
- Platform: macOS arm64 (Apple Silicon)
