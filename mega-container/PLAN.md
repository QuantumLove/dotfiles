---
title: Claude Setup Improvements - Mega-Container Master Plan
type: feat
date: 2026-02-21
status: phase-4-complete
source: docs/brainstorms/2026-02-21-claude-setup-improvements-brainstorm.md
deepened: 2026-02-21
reviewed: 2026-02-22
phase1-completed: 2026-02-24
phase2-completed: 2026-02-25
phase3-completed: 2026-02-26
phase4-completed: 2026-02-26
todos: todos/001-025
---

# Claude Setup Improvements - Mega-Container Master Plan

## Key Principles

1. **FAIL HARD, NOT SOFT** - If something is broken, exit with error. Never silently continue with degraded functionality. Missing secrets = immediate exit. Broken dependencies = immediate exit.

2. **Fail Fast** - Validate all requirements at startup before doing any work.

3. **Explicit over Implicit** - Log what's happening. Show key counts, connection status, etc.

---

## Enhancement Summary

**Deepened on:** 2026-02-21
**Research agents used:** 11 (DevPod, Tailscale, 1Password, MCP servers, mise, security, architecture, agent-native, simplicity, OpenCode, skill templates)

### Key Improvements from Research
1. **Tailscale works with userspace networking** - no `--privileged` needed for Tailscale itself
2. **GitHub MCP moved** to `github/github-mcp-server` (not the old @modelcontextprotocol package)
3. **Toggl MCP exists** - use `@verygoodplugins/mcp-toggl`
4. **Security concerns** - `--privileged` flag has CRITICAL security implications; use specific capabilities
5. **Agent-native gap** - `/where-am-i` should be Phase 1 priority for context awareness
6. **Simplification opportunity** - Consider docker compose instead of DevPod initially

### New Considerations Discovered
- DevPod maintenance concerns (community fork exists)
- OpenCode has SSH display issues - test early
- oh-my-opencode imports Claude Code config via dedicated loaders
- 1Password Service Account Token rotation is manual - document procedure

---

## Technical Review Decisions (2026-02-22)

All findings from technical review have been resolved. See `todos/` for full details.

### P1 Decisions (Critical)

| # | Issue | Decision |
|---|-------|----------|
| 001 | mise install blocks 30s startup | **Pre-install all tools in Dockerfile**. mise.toml in chezmoi, mise.lock for exact pinning. Host and container share same versions. |
| 002 | DinD socket exposure | **Socket mount with Docker Desktop VM isolation**. On Docker Desktop Mac, socket connects to VM (not macOS). Risk is container-to-container, not host escape. Document risk in README. |
| 003 | chezmoi secret materialization | **`onepasswordRead` in chezmoi templates**. Secrets injected once at `chezmoi apply`, not every shell startup. SSH keys via 1Password SSH Agent forwarding. Env files/TF outputs in private repo. |

### P2 Decisions (Important)

| # | Issue | Decision |
|---|-------|----------|
| 004 | Tailscale auth | **Interactive login (superseded)**. One-time `tailscale up` with browser auth. Container is YOU on tailnet. No keys needed. |
| 005 | Bootstrap fail-fast | **Verify 1Password before chezmoi apply**. Bootstrap script exits immediately if `op account get` fails. |
| 006 | Named volume secrets | **Don't persist config dirs as volumes**. `~/.claude/` and `~/.config/` stay in container filesystem. Only persist `~/code/`. |
| 007 | MCP startup latency | **Accept latency, 5 MCPs**. GitHub, Linear, Sentry, Toggl, Notion. Config via `onepasswordRead` in chezmoi templates. (1Password MCP unnecessary - we have `op` CLI) |
| 008 | Pre-built image | **ghcr.io (GitHub Container Registry)**. Image has NO secrets (tools only). Secrets injected at runtime via chezmoi. Multi-arch (amd64/arm64). |
| 009 | AI tools | **Both - OpenCode primary, Claude Code backup**. Prioritize getting OpenCode working first. Keep Claude Code while learning OpenCode. |
| 010 | MCP count | **All 6 from start** (resolved by 007). |
| 011 | DinD needed | **Resolved by 002** - socket mount chosen. |

### P3 Decisions (Polish)

| # | Issue | Decision |
|---|-------|----------|
| 012 | DevPod config format | **Skip for now**. Document when implementing Phase 5 (K8s/VM). |
| 013 | Skill naming | **`namespace:skill-name` convention**. Follow compound-engineering pattern. |
| 014 | MCP config pattern | **Document each MCP individually**. No forced template - each MCP has different structure. |
| 015 | Skill frontmatter | **Use compound-engineering SKILL.md format**. |
| 016 | Tailscale sidecar | **Keep sidecar, document rationale**. Required for Docker Desktop Mac userspace networking. |

### Second Review Decisions (2026-02-22)

| # | Issue | Decision |
|---|-------|----------|
| 017 | Tailscale auth | **Interactive login (supersedes auth keys)**. One-time `tailscale up` with browser login. Container authenticates AS YOU. No keys, no rotation, no IT requests. |
| 018 | MCP list mismatch | **Standardized to 5 MCPs**. GitHub, Linear, Sentry, Toggl, Notion. (1Password MCP unnecessary - we have `op` CLI) |
| 019 | Interactive prompts | **Not applicable** - preventative warning, no actual prompts in plan. |
| 020 | Health check strategy | **Add Docker Compose healthchecks**. Nice-to-have for cleaner startup (system self-heals anyway). |
| 021 | Private repo mount | **Chezmoi externals**. Clone inside container via `.chezmoiexternal.toml`, not host mount. |
| 022 | `/where-am-i` scope | **Environment + project + branch + current task**. More useful than just "container vs host". |

---

## Overview

Transform the current 45+ per-repo devcontainer setup into a single powerful mega-container accessible from any device via SSH. OpenCode becomes the primary AI tool with mobile access NOW; Claude Code remains available as secondary.

**Key Constraints:**
- Local Docker MUST work before K8s/VM backends
- Test incrementally at each step
- Commit milestones to chezmoi repo
- All themes proven locally before expanding

## Problem Statement

Current setup has friction:
- 45+ devcontainer.json files with redundant tooling
- No mobile access to check long-running tasks
- Claude Code works in VSCode but not from terminal exec
- Per-repo containers don't share state or tools

## Proposed Solution

Single mega-container with:
- OpenCode as primary AI tool (SSH-accessible from phone)
- All dev tools consolidated (Python, Node, Terraform, AWS, K8s)
- Tailscale SSH for multi-device access
- tmux for session persistence
- mise for consistent tool versions
- 1Password Service Account Token for secrets

## Technical Approach

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Any Device (phone, laptop, tablet)                         │
│  └── Tailscale app → SSH to mega-dev                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Docker Desktop (macOS)                                      │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Linux VM                                                ││
│  │  ┌───────────────────┬───────────────────────────────┐  ││
│  │  │  Tailscale Sidecar│  Mega Container               │  ││
│  │  │  ─────────────────│  ─────────────────────────────│  ││
│  │  │  • Joins tailnet  │  • network_mode: service:ts   │  ││
│  │  │  • Hostname:      │  • OpenCode (PRIMARY)         │  ││
│  │  │    mega-dev       │  • Claude Code (backup)       │  ││
│  │  │  • SSH server     │  • tmux, chezmoi, mise        │  ││
│  │  │  • Userspace net  │  • All tools pre-installed    │  ││
│  │  └───────────────────┴───────────────────────────────┘  ││
│  │                           │                              ││
│  │                           ▼                              ││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │  Docker Daemon (in VM)                              │││
│  │  │  └── Socket mounted into mega container             │││
│  │  └─────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
│ 1Password    │  │ ghcr.io          │  │ Private Repo │
│ Service Acct │  │ (pre-built image)│  │ (env files)  │
└──────────────┘  └──────────────────┘  └──────────────┘

INSIDE MEGA CONTAINER:
├── AI: OpenCode + oh-my-opencode (primary), Claude Code (backup)
├── MCPs: GitHub, Linear, Sentry, Toggl, Notion (5 total)
├── Tools: Python, Node, OpenTofu, AWS CLI, kubectl, k9s, Helm, gh
├── Secrets: Injected via chezmoi onepasswordRead at apply time
├── SSH Keys: 1Password Agent forwarding (never on disk)
└── Storage: Only ~/code persists (config dirs ephemeral)
```

### Research Insights: Architecture

**Architectural Validation (from architecture-strategist):**
- Single container is architecturally sound for single-developer workstation
- OpenCode primary + Claude Code secondary adds complexity but valid for mobile constraint
- tmux is the correct choice for SSH session persistence
- Hybrid tool installation (Dockerfile + mise) is a good pattern

**Simplification Option (from code-simplicity-reviewer):**
- Consider plain `docker compose` instead of DevPod initially
- DevPod adds abstraction that may not be needed until K8s migration
- Decision: Keep DevPod in plan but note docker compose as fallback

### Dependency Graph

```
Theme 2: Mega-Container (FOUNDATION)
    │
    └──► Theme 1: MCP Integrations (needs 1Password working)
            │
            └──► Theme 3: Workflow Skills (needs MCPs)
                    │
                    └──► Theme 4 & 5: Permissions & QoL (parallel with Theme 3)
```

---

## Implementation Phases

### Phase 1: Local Docker Prototype

**Goal:** Validate core architecture locally (skip cloud VM - start local per constraint)

> **Research Note:** Phase 1 was originally "Cloud VM Prototype" but moved to local Docker first per the "Local Docker MUST work before K8s/VM backends" constraint.

**1.1 Tailscale Setup (Sidecar Pattern + Interactive Login)**

> **Research Insight (Tailscale best practices):**
> - Tailscale works on Docker Desktop macOS with **userspace networking** (default mode)
> - `TS_USERSPACE=true` is the default - no TUN device or `--privileged` needed for Tailscale
> - Use Tailscale SSH instead of OpenSSH - eliminates key management

> **Simplified Approach (from Paarth):**
> - Use `tailscale up` with interactive login instead of auth keys
> - Container authenticates AS YOU (your METR gmail)
> - Inherits all your permissions - no separate ACLs needed
> - One-time setup, then persistent (survives restarts)
> - No auth key rotation, no IT requests

- [x] 1.1.1 **Create `start.sh` wrapper:**
  ```bash
  #!/bin/bash
  # mega-container/start.sh - Single entry point for starting the container
  set -e

  echo "=== Mega Container Startup ==="

  # 1. Fetch 1Password Service Account Token (from macOS Keychain)
  echo "Fetching 1Password token from keychain..."
  export OP_SERVICE_ACCOUNT_TOKEN=$(security find-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w 2>/dev/null)
  if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "ERROR: OP_SERVICE_ACCOUNT_TOKEN not in keychain"
    echo "Add it with: security add-generic-password -a $USER -s OP_SERVICE_ACCOUNT_TOKEN -w 'your-token'"
    exit 1
  fi
  echo "✓ 1Password token ready"

  # 2. Start containers
  echo "Starting containers..."
  docker compose up -d

  # 3. Check Tailscale status
  echo "Checking Tailscale..."
  if docker compose exec tailscale tailscale status &>/dev/null; then
    echo "✓ Tailscale already connected"
    docker compose exec tailscale tailscale status
  else
    echo ""
    echo "⚠️  Tailscale not yet authenticated. Run one-time setup:"
    echo "   docker compose exec tailscale tailscale up --accept-routes --ssh --hostname=mega-dev"
    echo ""
    echo "   Then follow the login URL and authenticate with your METR gmail."
    echo "   After that, Tailscale will persist across restarts."
  fi

  echo "=== Startup Complete ==="
  ```

- [x] 1.1.2 **One-time Tailscale setup (first run only):**
  ```bash
  # Start containers
  ./start.sh

  # Run interactive Tailscale login
  docker compose exec tailscale tailscale up --accept-routes --ssh --hostname=mega-dev

  # You'll see a URL like:
  # To authenticate, visit:
  #   https://login.tailscale.com/a/xxxxx
  #
  # Open the URL, log in with your METR gmail.
  # Container is now authenticated AS YOU on the tailnet.
  ```

  **What this gives you:**
  - Container has YOUR identity (same as your laptop)
  - Inherits all your Tailscale permissions
  - Can access anything you can access (EKS, dev4, etc.)
  - No auth keys, no rotation, no ACL configuration

- [x] 1.1.3 **Verify Tailscale connection:**
  ```bash
  docker compose exec tailscale tailscale status
  # Should show: mega-dev logged in as rafael.carvalho@metr.org
  ```

- [x] 1.1.4 **Test SSH from phone via Tailscale app:**
  ```bash
  # From any device with Tailscale
  ssh mega-dev
  ```

- [x] 1.1.5 **Verify persistent across restarts:**
  ```bash
  docker compose down
  ./start.sh
  # Should reconnect automatically without re-authentication
  ```

**1.2 1Password Service Account Token Injection**

> **Research Insight (1Password best practices):**
> - Use Service Account Token for containers (not regular API tokens)
> - Inject via environment variable, NOT baked into image
> - Scope Service Account to specific vault(s) with minimal access
> - Token rotation is manual - document procedure
> - Consider mounted secret file with restricted permissions (more secure than env var)

- [x] 1.2.1 Create 1Password Service Account:
  ```bash
  # Create with 90-day expiration, read-only on Development vault
  op service-account create "DevPod Mega" \
    --expires-in 2160h \
    --vault "Development:read_items"
  ```
- [x] 1.2.2 Store token reference securely (macOS Keychain or secure file)
- [x] 1.2.3 Test: container can run `op read` with Service Account
  (Note: Token fetching consolidated into `start.sh` - see 1.1.4)

**1.3 Docker Configuration**

> **Research Insight (Security review - CRITICAL):**
> - `--privileged` flag is CRITICAL security risk - grants root-equivalent access to host
> - For DinD: privileged IS required, but understand the risk
> - For Tailscale: NOT required with userspace networking
> - Minimize blast radius: use specific capabilities where possible

- [x] 1.3.1 Create `mega-container/docker-compose.yml`:
  ```yaml
  services:
    tailscale:
      image: tailscale/tailscale:stable
      hostname: mega-dev
      environment:
        # No TS_AUTHKEY - using interactive login instead
        - TS_STATE_DIR=/var/lib/tailscale
        - TS_USERSPACE=true
      volumes:
        - tailscale-state:/var/lib/tailscale  # Persists auth across restarts
      restart: unless-stopped
      # TODO-020: Healthcheck for proper startup sequencing
      healthcheck:
        test: ["CMD", "tailscale", "status", "--json"]
        interval: 5s
        timeout: 3s
        retries: 5
        start_period: 10s

    mega:
      build: .
      network_mode: service:tailscale
      depends_on:
        tailscale:
          condition: service_healthy  # Wait for Tailscale to be ready
      environment:
        - OP_SERVICE_ACCOUNT_TOKEN
        - SSH_AUTH_SOCK=/ssh-agent
      volumes:
        # Code directory - ONLY persistent volume
        - code:/home/metr/code
        # Docker socket for building images (connects to Docker Desktop VM)
        - /var/run/docker.sock:/var/run/docker.sock
        # 1Password SSH Agent forwarding (macOS)
        - ${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock:/ssh-agent:ro
      security_opt:
        - no-new-privileges:true
      command: sleep infinity
      # TODO-020: Healthcheck for container health visibility
      healthcheck:
        test: ["CMD", "op", "account", "get"]
        interval: 30s
        timeout: 5s
        retries: 3

  volumes:
    tailscale-state:
    code:
    # NOTE: No 'home' volume - config files stay in container filesystem
    # Secrets injected at runtime via chezmoi apply, not persisted
  ```

  **Key decisions reflected:**
  - Docker socket mount for image building (TODO-002)
  - SSH agent forwarding from 1Password (TODO-003)
  - Only `code` volume persists (TODO-006)
  - No `home` volume - secrets stay ephemeral
  - `no-new-privileges` security hardening
- [x] 1.3.2 Create `mega-container/Dockerfile`:
  ```dockerfile
  # Multi-stage build for mise binary
  FROM jdxcode/mise:latest AS mise

  FROM debian:bookworm-slim

  # System packages
  RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo tmux openssh-server \
      build-essential libssl-dev pkg-config \
      && rm -rf /var/lib/apt/lists/*

  # Install 1Password CLI
  RUN curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
      gpg --dearmor -o /usr/share/keyrings/1password.gpg && \
      echo "deb [signed-by=/usr/share/keyrings/1password.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" > \
      /etc/apt/sources.list.d/1password.list && \
      apt-get update && apt-get install -y 1password-cli && \
      rm -rf /var/lib/apt/lists/*

  # Install chezmoi
  RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

  # Copy mise binary from official image
  COPY --from=mise /usr/local/bin/mise /usr/local/bin/mise

  # Create user
  RUN useradd -m -s /bin/bash metr && \
      echo 'metr ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

  USER metr
  WORKDIR /home/metr

  # Configure mise environment
  ENV MISE_DATA_DIR="/home/metr/.local/share/mise"
  ENV MISE_CONFIG_DIR="/home/metr/.config/mise"
  ENV PATH="/home/metr/.local/share/mise/shims:$PATH"
  ENV MISE_YES=true

  # Copy mise config and PRE-INSTALL all tools (TODO-001 decision)
  # This ensures <30s container startup
  COPY --chown=metr:metr .config/mise/config.toml .config/mise/mise.lock* ./.config/mise/
  RUN mise trust -a && mise install

  # Tools are now baked into image - no runtime install needed
  ```

  **Key decisions reflected (TODO-001):**
  - Multi-stage build copies mise binary from official image
  - mise.toml (config.toml) and mise.lock copied into image
  - `mise install` runs at BUILD time, not runtime
  - Container starts in <30s (tools pre-installed)
  - chezmoi installed for runtime config application
- [x] 1.3.3 Test: build locally, container starts

**1.4 mise Configuration (Single Source of Truth)**

> **Research Insight (mise best practices):**
> - Use `mise.toml` (not `.tool-versions`) for full feature access
> - Set `MISE_YES=true` in containers for non-interactive operation
> - Use aqua backend for DevOps tools (direct binary downloads, no plugins)
> - mise should own ALL developer tools, Dockerfile only has system packages

> **TODO-001 Decision:**
> - mise.toml lives in chezmoi (`~/.local/share/chezmoi/dot_config/mise/config.toml`)
> - mise.lock enabled for exact version pinning
> - Same file controls BOTH host and container versions
> - Tools pre-installed in Dockerfile (not runtime)

- [x] 1.4.1 Create `~/.local/share/chezmoi/dot_config/mise/config.toml`:
  ```toml
  [tools]
  node = "22.11.0"       # Pin exact versions
  python = "3.12.4"
  opentofu = "1.8.0"
  "aqua:aws/aws-cli" = "2.22.0"
  kubectl = "1.31.0"
  "aqua:derailed/k9s" = "0.32.0"
  helm = "3.16.0"
  gh = "2.62.0"
  jq = "1.7.1"
  yq = "4.44.0"
  "aqua:astral-sh/uv" = "0.5.0"

  [settings]
  experimental = true
  yes = true
  lockfile = true        # Generate mise.lock for exact reproducibility

  [env]
  EDITOR = "vim"
  ```
- [x] 1.4.2 Run `mise install` locally to generate mise.lock
- [x] 1.4.3 Add mise.lock to chezmoi: `chezmoi add ~/.config/mise/mise.lock`
- [x] 1.4.4 Version update workflow:
  ```bash
  # 1. Edit config.toml
  vim ~/.local/share/chezmoi/dot_config/mise/config.toml
  # 2. Apply to host and regenerate lock
  chezmoi apply && mise install
  # 3. Add updated lock
  chezmoi add ~/.config/mise/mise.lock
  # 4. Commit
  cd ~/.local/share/chezmoi && git add -A && git commit -m "chore: bump tool versions"
  # 5. Rebuild container (picks up new config)
  docker compose build mega
  ```

**1.5 Bootstrap Script (Entrypoint)**

> **TODO-003 & TODO-005 Decisions:**
> - Fail immediately if 1Password auth fails (fail-fast)
> - `chezmoi apply` injects secrets via `onepasswordRead` templates
> - Tailscale uses interactive login (no auth keys)
> - mise tools already pre-installed in image (no runtime install)

- [x] 1.5.1 Create `mega-container/entrypoint.sh`:
  ```bash
  #!/bin/bash
  set -e

  echo "=== Mega Container Bootstrap ==="

  # 1. FAIL FAST: Verify 1Password token exists
  if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "ERROR: OP_SERVICE_ACCOUNT_TOKEN not set"
    echo "Pass via: docker compose run -e OP_SERVICE_ACCOUNT_TOKEN mega"
    exit 1
  fi

  # 2. FAIL FAST: Verify 1Password connectivity
  echo "Checking 1Password connection..."
  if ! op account get &>/dev/null; then
    echo "ERROR: 1Password authentication failed"
    echo "Check your OP_SERVICE_ACCOUNT_TOKEN is valid"
    exit 1
  fi
  echo "✓ 1Password connected"

  # 3. Verify SSH agent (needed for chezmoi externals - TODO-023)
  echo "Checking SSH agent..."
  if ! ssh-add -l &>/dev/null; then
    echo "ERROR: SSH agent not available"
    echo "Ensure 1Password SSH Agent is running on host"
    echo "Socket expected at: /ssh-agent"
    exit 1
  fi
  echo "✓ SSH agent connected"

  # 4. Apply chezmoi (secrets injected via onepasswordRead templates)
  # NOTE: Tailscale auth is handled separately via interactive login
  echo "Applying chezmoi configuration..."
  chezmoi init --apply rafaelcarvalho
  echo "✓ chezmoi applied (secrets injected)"

  # 5. Verify mise tools (already pre-installed in image)
  echo "Verifying mise tools..."
  mise doctor
  echo "✓ mise tools ready"

  echo "=== Bootstrap Complete ==="

  # Execute the main command
  exec "$@"
  ```
- [x] 1.5.2 Update Dockerfile to use entrypoint:
  ```dockerfile
  COPY --chown=metr:metr entrypoint.sh /usr/local/bin/entrypoint.sh
  RUN chmod +x /usr/local/bin/entrypoint.sh
  ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
  CMD ["sleep", "infinity"]
  ```
- [x] 1.5.3 Test: bootstrap fails cleanly without OP_SERVICE_ACCOUNT_TOKEN
- [x] 1.5.4 Test: bootstrap succeeds with valid token

**1.6 OpenCode + Claude Code Setup**

> **Research Insight (OpenCode research):**
> - Install via `npm install -g opencode-ai` or `curl -fsSL https://opencode.ai/install | bash`
> - oh-my-opencode imports Claude Code config via dedicated loaders for skills, commands, agents, MCP
> - OpenCode reads `CLAUDE.md` as fallback for `AGENTS.md`
> - **WARNING:** OpenCode has SSH display issues - outputs `[object Object]` over SSH
> - Test OpenCode over SSH early to validate mobile access works

- [x] 1.6.1 Install OpenCode:
  ```bash
  npm install -g opencode-ai
  # Or: curl -fsSL https://opencode.ai/install | bash
  ```
- [x] 1.6.2 Configure oh-my-opencode (installed in Dockerfile with `--claude=yes`)
- [x] 1.6.3 Install Claude Code as secondary:
  ```bash
  npm install -g @anthropic-ai/claude-code
  ```
- [x] 1.6.4 **CRITICAL TEST:** Verify OpenCode works over SSH (test display issues early)
- [x] 1.6.5 Test: both tools can access MCP servers (Linear, Sentry verified)

**1.7 /where-am-i Skill (Agent-Native Priority)**

> **Research Insight (Agent-native review):**
> - Agent context awareness is a critical gap - agents don't know runtime state
> - `/where-am-i` should be Phase 1 priority, not Phase 5
> - Provides: worktrees, open PRs, recent sessions, git state

- [x] 1.7.1 Create `skills/mega:where-am-i/SKILL.md` (TODO-022 expanded scope):
  ```markdown
  ---
  name: mega:where-am-i
  description: Quick orientation - environment, project, branch, current task
  allowed-tools: Bash(git *), Bash(hostname), Read
  ---

  ## Quick Start
  Gather and present current context for orientation.

  ## Output Format
  ```
  /where-am-i
  ───────────
  Environment: mega-container (via Tailscale)
  Project: inspect-ai
  Branch: feature/new-scorer
  Working on: Adding parallel evaluation support
  ```

  ## Implementation
  1. **Environment**: Check `$CONTAINER_NAME` or hostname
  2. **Project**: Parse `git remote get-url origin` or `basename $(pwd)`
  3. **Branch**: `git branch --show-current`
  4. **Working on**: Read from `.current-task` file if exists, else "No task set"

  ## Task Tracking
  Create a `.current-task` file in project root:
  ```bash
  echo "Adding parallel evaluation support" > .current-task
  ```
  ```
- [x] 1.7.2 Test: useful output on context switch (verified in Claude and OpenCode)
- [x] 1.7.3 Skipped `/set-task` - user decided not needed

**Milestone:** Local Docker mega-container with Tailscale SSH working from phone
**Commit:** `mega-container/` directory to chezmoi repo

#### Phase 1 Test Procedure

**Prerequisites:**
- 1Password app running with SSH Agent enabled
- OP_SERVICE_ACCOUNT_TOKEN in macOS Keychain
- Docker Desktop running

**Test 1.A: Fresh Start (First Time Setup)**
```bash
# From host machine
cd ~/mega-container

# Ensure clean state
docker compose down -v 2>/dev/null

# Run startup
./start.sh

# Expected output:
# === Mega Container Startup ===
# ✓ 1Password token ready
# Starting containers...
# ⚠️  Tailscale not yet authenticated. Run one-time setup:
#    docker compose exec tailscale tailscale up --accept-routes --ssh --hostname=mega-dev

# Run the one-time Tailscale setup:
docker compose exec tailscale tailscale up --accept-routes --ssh --hostname=mega-dev

# You'll see a login URL - open it and authenticate with your METR gmail
# After auth, verify:
docker compose exec tailscale tailscale status
# Expected: Shows mega-dev logged in as rafael.carvalho@metr.org
```

**Test 1.A2: Restart (After Initial Setup)**
```bash
# Verify Tailscale persists across restarts
docker compose down
./start.sh

# Expected output:
# === Mega Container Startup ===
# ✓ 1Password token ready
# Starting containers...
# ✓ Tailscale already connected
# [shows tailscale status with your identity]
```

**Test 1.B: Verify Container Health**
```bash
# Check container status
docker compose ps

# Expected: Both containers "healthy"
# NAME        STATUS
# tailscale   Up (healthy)
# mega        Up (healthy)

# Check health details
docker inspect mega --format='{{.State.Health.Status}}'
# Expected: healthy
```

**Test 1.C: Verify 1Password Inside Container**
```bash
docker compose exec mega op account get

# Expected: Shows service account info
# URL:          my.1password.com
# Email:        [service account email]
# User ID:      [uuid]
```

**Test 1.D: Verify SSH Agent Forwarding**
```bash
docker compose exec mega ssh-add -l

# Expected: Lists your SSH keys from 1Password
# 256 SHA256:xxxx... (none) [ED25519]
```

**Test 1.E: Verify chezmoi Applied**
```bash
docker compose exec mega cat ~/.chezmoi-applied 2>/dev/null || echo "Not applied"

# If using .chezmoi-applied marker:
# Expected: timestamp or "applied"

# Alternative: check for expected files
docker compose exec mega ls -la ~/.claude/
# Expected: Shows claude config files
```

**Test 1.F: Verify mise Tools**
```bash
docker compose exec mega mise doctor

# Expected: All checks pass
# mise doctor
# ✓ Build tools installed
# ✓ Plugin backends healthy
# ...

docker compose exec mega node --version
# Expected: v22.11.0 (or your pinned version)

docker compose exec mega python --version
# Expected: Python 3.12.4 (or your pinned version)
```

**Test 1.G: Verify Tailscale SSH (from phone)**
```bash
# From your phone with Tailscale app:
ssh mega-dev

# Expected: Connects to container, shows bash prompt
# metr@mega-dev:~$

# Verify tmux works
tmux new -s test
# Expected: tmux session starts

# Detach and reconnect
# Ctrl+B, D (detach)
ssh mega-dev
tmux attach -t test
# Expected: Same session restored
```

**Test 1.H: Failure Scenarios**

```bash
# Test 1: Missing OP token
security delete-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" 2>/dev/null
./start.sh
# Expected: ERROR: OP_SERVICE_ACCOUNT_TOKEN not in keychain

# Restore token for remaining tests
security add-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w "your-token"

# Test 2: 1Password SSH Agent not running
# (Stop 1Password app, then)
docker compose exec mega ssh-add -l
# Expected: Could not open connection to authentication agent

# Test 3: Tailscale state cleared (re-auth needed)
docker compose down -v  # -v removes volumes including tailscale-state
./start.sh
# Expected: Prompts for one-time Tailscale setup again
# (This is expected - the auth state was in the volume)
```

**Test 1.I: OpenCode/Claude Code (CRITICAL)**
```bash
# SSH from phone
ssh mega-dev

# Test OpenCode
opencode --version
# Expected: Version number, no errors

# Test OpenCode interactive (watch for display issues)
opencode
# Expected: TUI renders correctly, no [object Object]
# If broken: Document the issue, fall back to Claude Code

# Test Claude Code
claude --version
# Expected: Version number

claude
# Expected: Interactive prompt works
```

**Phase 1 Success Criteria Checklist:**
- [x] `./start.sh` completes without errors
- [x] Both containers show "healthy" in `docker compose ps`
- [x] `op account get` works inside container
- [x] `ssh-add -l` shows keys from 1Password
- [x] `mise doctor` passes all checks
- [x] SSH from phone connects via Tailscale
- [x] tmux sessions persist across SSH disconnects
- [x] At least one AI tool (OpenCode or Claude Code) works

**If Any Test Fails:**
1. Check logs: `docker compose logs tailscale` / `docker compose logs mega`
2. Check health: `docker inspect mega --format='{{json .State.Health}}'`
3. Reset and retry: `docker compose down -v && ./start.sh`
4. Document the failure in `todos/` before proceeding

#### Key Fixes Made During Phase 1 Implementation

1. **SSH socket**: Used Docker Desktop magic path `/run/host-services/ssh-auth.sock` instead of 1Password socket
2. **UID 501**: Container user matches macOS for socket permissions
3. **asdf backends**: Switched from aqua to asdf backends to avoid GitHub API rate limits
4. **Direct install for helm/gh**: asdf plugins broken, installed via curl
5. **SSH in login shell**: Added mise to `.bash_profile` (SSH reads this, not `.bashrc`)
6. **chezmoi ordering**: entrypoint runs mise activation AFTER chezmoi apply
7. **Removed no-new-privileges**: Blocked sudo for sshd
8. **Linear MCP**: Switched from mcp-remote (OAuth) to @larryhudson/linear-mcp-server (API key)
9. **Secrets persistence**: Added ~/.secrets_env sourced by .bash_profile for SSH sessions
10. **Claude Code auto-login**: Inject primaryApiKey + hasCompletedOnboarding into ~/.claude.json

#### Commands Reference

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

# Force recreate (picks up new chezmoi changes)
docker compose up -d --force-recreate mega
```

---

### Phase 2: MCP Integrations

**Goal:** Add missing MCP servers, enhance existing ones

> **Research Insight (MCP server research):**
> - **GitHub MCP:** Use `github/github-mcp-server` (NOT the old @modelcontextprotocol package - deprecated)
> - **Toggl MCP:** Use `@verygoodplugins/mcp-toggl` (community, well-maintained)
> - **Datadog MCP:** Official is in Preview (allowlist required); use `@shelf/datadog-mcp` for now
> - **Slack MCP:** Official available; community `korotovsky/slack-mcp-server` has stealth mode

> **TODO-007 & TODO-014 Decisions:**
> - 5 MCPs from start (GitHub, Linear, Sentry, Toggl, Notion)
> - 1Password MCP not needed - we have `op` CLI and `onepasswordRead`
> - Each MCP has different config structure - document individually
> - Secrets via `onepasswordRead` in chezmoi templates (injected once at `chezmoi apply`)

**2.1 Core MCPs (5 Total)**

Per TODO-007 decision, configure all 5 MCPs:

- [ ] 2.1.1 Update `modify_dot_claude.json.tmpl` with GitHub MCP:
  ```json
  {
    "mcpServers": {
      "github": {
        "command": "docker",
        "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
                 "ghcr.io/github/github-mcp-server"],
        "env": {
          "GITHUB_PERSONAL_ACCESS_TOKEN": "{{ onepasswordRead \"op://Development/GitHub PAT/credential\" }}"
        }
      }
    }
  }
  ```
- [ ] 2.1.2 Verify Linear MCP works (existing)
- [ ] 2.1.3 Verify Sentry MCP works (existing)
- [ ] 2.1.4 Add Toggl MCP:
  ```json
  "toggl": {
    "command": "npx",
    "args": ["-y", "@verygoodplugins/mcp-toggl@latest"],
    "env": {
      "TOGGL_API_KEY": "{{ onepasswordRead \"op://Development/Toggl API Key/credential\" }}"
    }
  }
  ```
- [ ] 2.1.5 Add Notion MCP:
  ```json
  "notion": {
    "command": "npx",
    "args": ["-y", "@notionhq/notion-mcp-server"],
    "env": {
      "NOTION_API_KEY": "{{ onepasswordRead \"op://Development/Notion API Key/credential\" }}"
    }
  }
  ```
- [ ] 2.1.6 Add Slack MCP (User Token approach - acts as YOU):
  ```json
  "slack": {
    "command": "npx",
    "args": ["-y", "slack-mcp-server"],
    "env": {
      "SLACK_MCP_XOXP_TOKEN": "{{ onepasswordRead \"op://Development/Slack User Token/credential\" }}",
      "SLACK_MCP_ADD_MESSAGE_TOOL": "true"
    }
  }
  ```
- [ ] 2.1.7 Test: `/mcp` shows all 6 connected

**2.1.6a Manual Steps: Getting a Slack User Token**

This requires one-time admin approval, then you manage it yourself.

1. **Request admin approval** (if needed):
   > "Can I create a personal Slack app with user token scopes for AI-assisted workflow automation? It would act as me, not a bot."

2. **Create Slack App:**
   - Go to https://api.slack.com/apps
   - Click "Create New App" → "From scratch"
   - Name: "Claude Code Personal" (or similar)
   - Workspace: Select your METR workspace
   - Click "Create App"

3. **Configure OAuth Scopes:**
   - In left sidebar: "OAuth & Permissions"
   - Scroll to "User Token Scopes"
   - Add these scopes:
     ```
     channels:history    - View messages in public channels
     channels:read       - View basic channel info
     chat:write          - Send messages as yourself
     groups:history      - View messages in private channels
     groups:read         - View private channels you're in
     im:history          - View DM messages
     im:read             - View DM list
     mpim:history        - View group DM messages
     mpim:read           - View group DM list
     reactions:read      - View emoji reactions
     reactions:write     - Add/remove emoji reactions
     search:read         - Search messages
     users:read          - View user profiles
     users:read.email    - View user email addresses
     usergroups:read     - View user groups
     ```

4. **Install to Workspace:**
   - Scroll up to "OAuth Tokens for Your Workspace"
   - Click "Install to Workspace"
   - Review permissions and click "Allow"
   - Copy the **User OAuth Token** (starts with `xoxp-`)

5. **Store in 1Password:**
   - Create new item: "Slack User Token"
   - Vault: Development
   - Field "credential": paste the `xoxp-...` token

6. **Verify:**
   ```bash
   # Test the token works
   curl -s -H "Authorization: Bearer xoxp-YOUR-TOKEN" \
     https://slack.com/api/auth.test | jq
   # Should show your user info
   ```

**2.2 Sentry Enhancements**

- [ ] 2.2.1 Hard-code org in Sentry MCP env:
  ```json
  "env": {
    "SENTRY_ORG": "metr-sh",
    "SENTRY_DEFAULT_USER": "rafael.carvalho@metr.org"
  }
  ```
- [ ] 2.2.2 Add Sentry read operations to permissions allow list
- [ ] 2.2.3 Test: Sentry queries work without org prompts

**2.3 Validation**

- [ ] 2.3.1 Run `chezmoi apply`, verify ~/.claude.json updated
- [ ] 2.3.2 Run `/mcp-check` to verify all 5 servers connect
- [ ] 2.3.3 Test each MCP with simple query

**Milestone:** All MCP servers configured and working
**Commit:** Updated chezmoi templates

#### Phase 2 Test Procedure

**Prerequisites:**
- Phase 1 tests passing
- API keys for all 5 MCPs stored in 1Password
- chezmoi templates updated with MCP configs

**Test 2.A: Verify chezmoi Applied MCP Config**
```bash
# Inside container
chezmoi apply

# Check the generated config
cat ~/.claude.json | jq '.mcpServers | keys'

# Expected output:
# [
#   "github",
#   "linear",
#   "notion",
#   "sentry",
#   "slack",
#   "toggl"
# ]

# Verify no template syntax in output (secrets should be expanded)
grep -c "onepasswordRead" ~/.claude.json
# Expected: 0 (no unexpanded templates)
```

**Test 2.B: Test Each MCP Individually**

```bash
# Start Claude Code or OpenCode
claude

# Test GitHub MCP
> Use the GitHub MCP to list my recent repos
# Expected: Returns list of your GitHub repos

# Test Linear MCP
> Use Linear to show my assigned issues
# Expected: Returns Linear issues

# Test Sentry MCP
> Use Sentry to list recent issues in metr-sh org
# Expected: Returns issues WITHOUT asking for org name

# Test Toggl MCP
> Use Toggl to show my time entries from today
# Expected: Returns time entries or "no entries"

# Test Notion MCP
> Use Notion to search for "meeting notes"
# Expected: Returns search results or "no results"

# Test Slack MCP
> Use Slack to list my recent DMs
# Expected: Returns recent messages or channels
```

**Test 2.C: MCP Health Check Skill**
```bash
# Run the mcp-check skill
/mcp-check

# Expected output (example):
# MCP Server Status
# ─────────────────
# ✓ github    - connected (ghcr.io/github/github-mcp-server)
# ✓ linear    - connected
# ✓ sentry    - connected (org: metr-sh)
# ✓ toggl     - connected
# ✓ notion    - connected
#
# 5/5 servers healthy
```

**Test 2.D: MCP Failure Handling**
```bash
# Test with invalid credential (temporarily break one)
# Edit 1Password item to have wrong API key, then:
chezmoi apply
claude
> Use Toggl to show time entries

# Expected: Clear error message like:
# "Toggl MCP failed to authenticate. Check your API key."
# NOT a cryptic stack trace

# Restore the correct key after testing
```

**Test 2.E: Sentry Org Hardcoding**
```bash
claude
> List Sentry issues

# Expected: Returns issues from metr-sh org directly
# Should NOT prompt: "Which organization?"

# Verify the env var is set
cat ~/.claude.json | jq '.mcpServers.sentry.env'
# Expected: Shows SENTRY_ORG: "metr-sh"
```

**Phase 2 Success Criteria Checklist:**
- [ ] `~/.claude.json` contains all 5 MCP configs
- [ ] No unexpanded template syntax in config file
- [ ] GitHub MCP can list repos
- [ ] Linear MCP can list issues
- [ ] Sentry MCP works without org prompt
- [ ] Toggl MCP can query time entries
- [ ] Notion MCP can search
- [ ] `/mcp-check` shows all 5 healthy
- [ ] Invalid credentials produce clear error messages

**If Any MCP Fails:**
1. Check the credential in 1Password: `op read "op://Development/[MCP] API Key/credential"`
2. Test the MCP directly: `npx -y @package/mcp-server` with manual env vars
3. Check Claude Code logs: `~/.claude/logs/`
4. Document the failure before proceeding

---

### Phase 3: Workflow Skills

**Goal:** Create automation skills that leverage MCP integrations

> **Research Insight (Skill templates research):**
> - Use `disable-model-invocation: true` for skills with side effects
> - Use router pattern for skills with multiple workflows
> - Expose primitives, not just full workflows (agents can compose)
> - Include `allowed-tools` to explicitly list needed tools

**3.1 Linear Tags on PRs**

- [ ] 3.1.1 Document branch naming convention: `eng-XXX-description` or `METR-XXX-description`
- [ ] 3.1.2 Create skill with explicit parameters (not just auto-detection):
  ```markdown
  ---
  name: pr-create
  argument-hint: [--linear ISSUE-ID]
  disable-model-invocation: true
  ---
  ```
- [ ] 3.1.3 Test: create PR, verify [ENG-XXX] added to title

**3.2 Async Standup Skill**

- [ ] 3.2.1 Create skill that queries: git log, Linear issues, Toggl entries
- [ ] 3.2.2 Format into cohesive Slack message (see skill template in research)
- [ ] 3.2.3 Set up cron in container: `0 18 * * * TZ=Europe/Berlin`
- [ ] 3.2.4 Test: manual run generates correct summary
- [ ] 3.2.5 Test: confirm before posting (no auto-send)

**3.3 Deploy Dev4 Skill**

- [ ] 3.3.1 Create private config repo (metr-config)
- [ ] 3.3.2 Add dev4/terraform.tfvars and dev4/smoke-test.env
- [ ] 3.3.3 Create skill with safety principles (from skill template):
  - Pre-flight checks required
  - Health checks after deploy
  - One service at a time
- [ ] 3.3.4 Create separate primitive skills: `/ecr-login`, `/tf-plan`, `/tf-apply`, `/smoke-test`
- [ ] 3.3.5 Test: full deploy cycle

**3.4 Triage Skills (Sentry + Linear)**

- [ ] 3.4.1 Create Sentry triage skill with router pattern (investigate, bulk, create-linear)
- [ ] 3.4.2 Create Linear triage skill with router pattern (inbox, backlog, update, create)
- [ ] 3.4.3 Include severity assessment and duplicate checking
- [ ] 3.4.4 Test: both skills work end-to-end

**3.5 Kubernetes Context Switching (`/k8s-switch`)**

Similar to `/aws-switch`, provides quick context switching between k8s clusters.

- [ ] 3.5.1 Create `/k8s-switch` skill with router pattern:
  ```markdown
  ---
  name: mega:k8s-switch
  description: Switch kubectl context and verify connection
  argument-hint: <context-name|list>
  allowed-tools: Bash(kubectl *), Bash(aws eks *), Bash(k9s *)
  ---

  ## Usage
  /k8s-switch minikube     # Switch to minikube
  /k8s-switch dev4         # Switch to dev4 EKS cluster
  /k8s-switch list         # List available contexts
  /k8s-switch              # Show current context

  ## Contexts
  - `minikube` → `kubectl config use-context minikube`
  - `dev4` → `aws eks update-kubeconfig --name dev4-eks-cluster`
  - `prod` → `aws eks update-kubeconfig --name prod-eks-cluster`

  ## Implementation
  1. If "list": `kubectl config get-contexts`
  2. If no arg: `kubectl config current-context`
  3. If minikube: `kubectl config use-context minikube`
  4. If EKS cluster: `aws eks update-kubeconfig --name <cluster>`
  5. Verify: `kubectl cluster-info`
  6. Show: namespace count, node count, current namespace
  ```
- [ ] 3.5.2 Add k9s launch option:
  ```markdown
  ## K9s Integration
  /k8s-switch dev4 --k9s   # Switch and launch k9s
  ```
- [ ] 3.5.3 Store cluster configs in private-config repo:
  ```yaml
  # ~/.private-config/k8s/clusters.yaml
  clusters:
    minikube:
      type: local
      context: minikube
    dev4:
      type: eks
      name: dev4-eks-cluster
      region: us-east-1
    prod:
      type: eks
      name: prod-eks-cluster
      region: us-east-1
  ```
- [ ] 3.5.4 Test: switch between minikube and dev4

**Milestone:** Core workflow skills operational
**Commit:** Skills to chezmoi repo

#### Phase 3 Test Procedure

**Prerequisites:**
- Phase 2 tests passing
- Skills installed in `~/.claude/skills/`
- Private config repo accessible (if using deploy skills)

**Test 3.A: /where-am-i Skill**
```bash
# Navigate to a git repo
cd ~/code/inspect-ai
git checkout -b test-branch

# Run the skill
/where-am-i

# Expected output:
# /where-am-i
# ───────────
# Environment: mega-container (via Tailscale)
# Project: inspect-ai
# Branch: test-branch
# Working on: No task set

# Set a task and re-run
echo "Testing the where-am-i skill" > .current-task
/where-am-i

# Expected: "Working on: Testing the where-am-i skill"

# Cleanup
rm .current-task
git checkout main
git branch -d test-branch
```

**Test 3.B: /pr-create Skill with Linear Tag**
```bash
# Create a test branch with Linear format
cd ~/code/some-repo
git checkout -b eng-123-test-feature
echo "test" > test-file.txt
git add test-file.txt
git commit -m "test: add test file"

# Run PR create skill
/pr-create

# Expected:
# - PR title includes [ENG-123]
# - PR created successfully
# - Link to PR displayed

# Verify on GitHub
gh pr view --json title
# Expected: title contains "[ENG-123]"

# Cleanup
gh pr close --delete-branch
```

**Test 3.C: /async-standup Skill (Dry Run)**
```bash
# Run standup skill
/async-standup --dry-run

# Expected output (example):
# 📋 Standup Summary for 2026-02-22
#
# Yesterday:
# - Committed: "feat: add user auth" (inspect-ai)
# - Linear: Closed ENG-456
# - Toggl: 6.5 hours logged
#
# Today:
# - Linear: ENG-789 in progress
#
# [DRY RUN - Not posting to Slack]

# Verify it asks for confirmation before posting
/async-standup
# Expected: "Post this to #standup? [y/N]"
# Answer: N (don't actually post during testing)
```

**Test 3.D: Deploy Primitives (Without Actual Deploy)**
```bash
# Test ECR login
/ecr-login --dry-run
# Expected: Shows what would be run, doesn't actually login

# Test TF plan (if private config available)
/tf-plan dev4 --dry-run
# Expected: Shows terraform plan command that would run

# Test smoke test config exists
cat ~/code/.private-config/dev4/smoke-test.env
# Expected: Shows smoke test configuration
```

**Test 3.E: /sentry-triage Skill**
```bash
# Run triage in investigate mode
/sentry-triage investigate

# Expected:
# - Lists recent unresolved issues
# - Shows issue count and severity breakdown
# - Offers options: [I]gnore, [A]ssign, [L]ink to Linear

# Test bulk mode
/sentry-triage bulk --dry-run
# Expected: Shows what bulk actions would be taken
```

**Test 3.F: /linear-triage Skill**
```bash
# Run triage for inbox
/linear-triage inbox

# Expected:
# - Lists unassigned/untriaged issues
# - Shows priority and labels
# - Offers quick actions

# Test creating from triage
/linear-triage create --dry-run
# Expected: Shows what issue would be created
```

**Test 3.G: /k8s-switch Skill**
```bash
# List available contexts
/k8s-switch list

# Expected:
# Available Kubernetes Contexts:
# ─────────────────────────────
#   minikube (local)
#   dev4-eks-cluster (EKS)
# * current: minikube

# Show current context
/k8s-switch

# Expected: Shows current context and cluster info

# Switch to minikube
/k8s-switch minikube

# Expected:
# Switched to context: minikube
# ✓ Cluster: minikube
# ✓ Nodes: 1
# ✓ Namespaces: 4

# Switch to EKS (requires AWS auth)
/k8s-switch dev4

# Expected:
# Updating kubeconfig for dev4-eks-cluster...
# ✓ Cluster: dev4-eks-cluster
# ✓ Region: us-east-1
# ✓ Nodes: 3
# ✓ Namespaces: 12

# Switch and launch k9s
/k8s-switch dev4 --k9s

# Expected: Switches context and opens k9s TUI
```

**Test 3.H: Skill Error Handling**
```bash
# Test skill with missing dependency
cd /tmp  # Not a git repo
/where-am-i

# Expected: Graceful error
# "Not in a git repository. Navigate to a project first."

# Test skill with network issue (disconnect briefly)
# Then run any MCP-dependent skill
/sentry-triage investigate

# Expected: Clear error about MCP connectivity
```

**Phase 3 Success Criteria Checklist:**
- [ ] `/where-am-i` shows environment, project, branch, task
- [ ] `/pr-create` adds Linear tag to PR title
- [ ] `/async-standup` generates summary (dry-run works)
- [ ] `/async-standup` confirms before posting
- [ ] Deploy primitives exist and show dry-run output
- [ ] `/sentry-triage` lists issues with action options
- [ ] `/linear-triage` shows inbox with quick actions
- [ ] `/k8s-switch` lists contexts and switches between minikube/EKS
- [ ] `/k8s-switch --k9s` launches k9s after switching
- [ ] Skills fail gracefully with clear error messages

**If Any Skill Fails:**
1. Check skill exists: `ls ~/.claude/skills/mega:*/SKILL.md`
2. Check skill syntax: `cat ~/.claude/skills/mega:where-am-i/SKILL.md`
3. Test allowed-tools work: Run the underlying commands manually
4. Check Claude Code recognizes skill: `/skills` command

---

### Phase 4: Permissions & QoL

**Goal:** Polish the experience

> **Research Insight (Agent-native review):**
> - Current permissions block autonomous agent actions
> - Create separate permissions profile for container environment
> - Keep confirming external writes (Linear, GitHub, AWS, Slack)

**4.1 Permission Tuning**

- [ ] 4.1.1 Create container-specific permissions in settings.json:
  ```json
  {
    "permissions": {
      "allow": [
        "Bash(git commit *)",
        "Bash(docker build *)",
        "WebFetch",
        "WebSearch",
        "Read",
        "Glob",
        "Grep"
      ],
      "ask": [
        "Bash(tofu apply *)",
        "mcp__linear__create_*",
        "mcp__slack__*"
      ]
    }
  }
  ```

  **Rationale:**
  - `WebFetch` + `WebSearch`: Research actions, read-only, no side effects
  - `Read` + `Glob` + `Grep`: Local file reading, essential for coding
  - Still prompt for: infrastructure changes, external writes (Linear, Slack)
- [ ] 4.1.2 Note annoying permission prompts during usage
- [ ] 4.1.3 Relax specific permissions iteratively

**4.2 Update start-work Skill**

- [ ] 4.2.1 Modify to work with mega-container (no per-repo DevContainer)
- [ ] 4.2.2 Create worktree inside ~/code in mega-container
- [ ] 4.2.3 Test: workflow still smooth

**4.3 Deprecate Old Skills**

- [ ] 4.3.1 Add deprecation notices to: dev-open, dev-list, dev-clean
- [ ] 4.3.2 Keep for fallback initially
- [ ] 4.3.3 Remove after mega-container proven stable

**4.4 CLAUDE.md Updates**

- [ ] 4.4.1 Add mega-container workflow guidance
- [ ] 4.4.2 Add "Where to Put Learnings" section
- [ ] 4.4.3 Add context injection (MCP health, worktree status) to system prompt

**Milestone:** Smooth daily workflow
**Commit:** Updated skills and CLAUDE.md

#### Phase 4 Test Procedure

**Prerequisites:**
- Phase 3 tests passing
- Updated CLAUDE.md with mega-container guidance
- Permission settings configured

**Test 4.A: Permission Auto-Allow**
```bash
# Test git commit (should be auto-allowed)
cd ~/code/test-repo
echo "test" > test.txt
git add test.txt

# In Claude Code:
> Commit this file with message "test: permission check"

# Expected: Commits WITHOUT asking for permission
# (because settings.json allows "Bash(git commit *)")

# Verify
git log -1 --oneline
# Expected: Shows the commit

# Test WebFetch auto-allow
> Fetch the homepage of example.com and summarize it

# Expected: Fetches WITHOUT asking for permission

# Test WebSearch auto-allow
> Search the web for "Claude Code permissions"

# Expected: Searches WITHOUT asking for permission

# Test Read/Glob/Grep auto-allow
> Find all Python files in this directory
> Read the README.md file
> Search for "def main" in the codebase

# Expected: All complete WITHOUT permission prompts
```

**Test 4.B: Permission Prompts for Sensitive Actions**
```bash
# In Claude Code:
> Run tofu apply on dev4

# Expected: ASKS for permission
# "Allow Bash(tofu apply *)? [y/N]"
# Answer: N (don't actually apply)

# Test MCP write permissions
> Create a Linear issue titled "Test Issue"

# Expected: ASKS for permission
# "Allow mcp__linear__create_issue? [y/N]"
# Answer: N
```

**Test 4.C: start-work Skill in Mega Container**
```bash
# Run start-work skill
/start-work eng-999 "Test feature"

# Expected:
# 1. Creates worktree at ~/code/eng-999-test-feature
# 2. Initializes git branch
# 3. Shows: "Ready to work in ~/code/eng-999-test-feature"

# Verify worktree created
ls ~/code/eng-999-test-feature
git worktree list | grep eng-999

# Cleanup
git worktree remove ~/code/eng-999-test-feature
```

**Test 4.D: CLAUDE.md Context Injection**
```bash
# Start new Claude Code session
claude

# Ask about the environment
> Where am I and what tools are available?

# Expected: Response should mention:
# - Mega-container environment
# - Available MCPs (from CLAUDE.md)
# - Worktree workflow
# (This tests that CLAUDE.md guidance is being read)

# Check for MCP health in context
> What's the status of my MCP connections?

# Expected: Should be able to answer based on
# context injection or offer to run /mcp-check
```

**Test 4.E: Deprecated Skills Warning**
```bash
# Try old DevContainer skills
/dev-open

# Expected: Deprecation warning
# "⚠️ /dev-open is deprecated. Use mega-container workflow instead.
#  See: /where-am-i for current context"

/dev-list
# Expected: Similar deprecation warning
```

**Test 4.F: Full Workflow Simulation**
```bash
# Simulate a complete work session

# 1. Start work
/start-work eng-888 "Add feature X"

# 2. Check context
/where-am-i
# Expected: Shows eng-888-add-feature-x branch

# 3. Make changes
echo "feature code" > feature.py
git add feature.py
# In Claude: "Commit this"
# Expected: Auto-allowed, commits

# 4. Create PR
/pr-create
# Expected: Creates PR with [ENG-888] tag

# 5. Check with Sentry
/sentry-triage investigate
# Expected: Shows any related issues

# 6. Cleanup
gh pr close --delete-branch
git worktree remove ~/code/eng-888-add-feature-x
```

**Test 4.G: Session Persistence Across Devices**
```bash
# From laptop:
ssh mega-dev
tmux new -s work
cd ~/code/some-project
/where-am-i
# Note the output

# Detach: Ctrl+B, D

# From phone (Tailscale app):
ssh mega-dev
tmux attach -t work

# Expected:
# - Same directory
# - Same context
# - tmux history preserved

# Run /where-am-i again
# Expected: Same output as before
```

**Phase 4 Success Criteria Checklist:**
- [ ] `git commit` auto-allowed (no prompt)
- [ ] `tofu apply` prompts for permission
- [ ] MCP write operations prompt for permission
- [ ] `/start-work` creates worktree correctly
- [ ] CLAUDE.md context is available in sessions
- [ ] Deprecated skills show warnings
- [ ] Full workflow (start → code → commit → PR) works smoothly
- [ ] tmux sessions persist across device switches

**If Any Test Fails:**
1. Check settings.json: `cat ~/.claude/settings.json | jq '.permissions'`
2. Check CLAUDE.md loaded: Start Claude, ask "What's in my CLAUDE.md?"
3. Check worktree setup: `git worktree list`
4. Check tmux: `tmux ls`

---

### Phase 5: Multi-Backend Support (FUTURE)

**Goal:** Same setup works on K8s and VMs

**Only proceed after Phases 1-4 proven stable**

> **Reference:** See [METR/platform#8](https://github.com/METR/platform/pull/8) - Sami's rootless DinD approach for k8s.

**Key Difference: Docker Access on K8s**

On k8s, there's no Docker socket to mount. Use DinD sidecar instead:

```yaml
# k8s/mega-container.yaml
services:
  dind:
    image: docker:24.0-dind-rootless
    command: ["dockerd-entrypoint.sh"]
    securityContext:
      privileged: true  # Required for DinD
    nodeSelector:
      dind: "true"  # Route to dedicated Ubuntu nodes
    env:
      - DOCKER_TLS_CERTDIR=""  # Disable TLS for localhost

  mega:
    # ... existing config ...
    env:
      - DOCKER_HOST=tcp://localhost:2375  # Connect to DinD sidecar
    # NO socket mount - uses DinD instead
    dependsOn:
      - dind
```

**Infrastructure Requirements (from Sami's PR):**
- Karpenter NodePool with `dind: "true"` label
- EC2NodeClass with Ubuntu 22.04 AMI
- Nodes need: c7i-flex or similar (Nitro), 4-8 CPUs

**Tasks:**

- [ ] 5.1 Evaluate DevPod vs plain K8s manifests
- [ ] 5.2 Create k8s manifest with DinD sidecar pattern
- [ ] 5.3 Request `dind=true` NodePool from platform team (or reuse Sami's)
- [ ] 5.4 Test Docker builds work via DinD (`DOCKER_HOST=tcp://localhost:2375`)
- [ ] 5.5 Configure resource allocation for K8s
- [ ] 5.6 Document differences: socket mount (local) vs DinD (k8s)

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary AI tool | OpenCode (Claude Code backup) | Mobile access NOW via SSH; keep Claude Code while learning |
| Container strategy | Single mega-container | Simplifies tooling |
| Access method | Tailscale SSH (sidecar, userspace) | Works from phone; sidecar for Docker Desktop Mac |
| Sessions | tmux | Battle-tested, works over SSH |
| Secrets injection | `onepasswordRead` in chezmoi | Secrets injected once at `chezmoi apply`, not every startup |
| SSH keys | 1Password SSH Agent forwarding | Keys never touch container; forward agent socket |
| Tool installation | Pre-install in Dockerfile | All tools baked in image; <30s startup |
| Tool versions | mise.toml in chezmoi + mise.lock | Single source of truth for host + container |
| Docker access (local) | Socket mount (Docker Desktop) | Connects to VM, not macOS; enables `docker build` |
| Docker access (k8s) | Rootless DinD sidecar | `docker:24.0-dind-rootless` with `privileged: true` (see PR#8) |
| Config persistence | Only ~/code volume | Config dirs stay ephemeral; secrets not persisted |
| Image registry | ghcr.io | No secrets in image; free for private repos |
| MCP servers | 5 from start | GitHub, Linear, Sentry, Toggl, Notion (1Password MCP unnecessary) |
| Env files / TF outputs | Private repo via chezmoi externals | Cloned inside container, not host mount |
| Skill naming | `namespace:skill-name` | Follow compound-engineering convention |
| Tailscale auth | Interactive login (your identity) | One-time `tailscale up`, container is YOU on tailnet, no rotation |
| Container healthchecks | Docker Compose healthchecks | Nice-to-have for cleaner startup |
| `/where-am-i` scope | Environment + project + branch + task | More useful than just "container vs host" |
| Auto-allow permissions | WebFetch, WebSearch, Read, Glob, Grep | Read-only actions, no side effects |

---

## Critical Questions (RESOLVED)

| Question | Answer from Research |
|----------|---------------------|
| Tailscale in Docker on Mac | Works with userspace networking (default), no --privileged needed |
| 1Password Service Account creation | Create via CLI with vault scoping, 90-day expiration |
| GitHub MCP selection | Use `github/github-mcp-server` (official, Docker-based) |
| Toggl MCP | Use `@verygoodplugins/mcp-toggl` (community, well-maintained) |
| hawk authentication | Still needs investigation - not covered in research |
| OpenCode SSH issues | Known display problems - test early in Phase 1.6.4 |

---

## Security Considerations

> **From security-sentinel review + TODO decisions:**

### Security Decisions Made

| Issue | Decision | Rationale |
|-------|----------|-----------|
| Docker socket mount | **Accept for Docker Desktop** | Socket connects to VM, not macOS; risk is container-to-container only |
| SSH keys | **1Password Agent forwarding** | Keys never touch container disk |
| API tokens | **`onepasswordRead` in chezmoi** | Injected once at apply time; not every shell startup |
| Config persistence | **Don't persist config volumes** | Only ~/code persists; ~/.claude/ stays ephemeral |
| Tailscale auth | **Interactive login (your identity)** | Container is YOU on tailnet; no keys to rotate; inherits your permissions |

### Remaining Risks (Documented & Accepted)

| Risk | Severity | Mitigation |
|------|----------|------------|
| Socket mount container escape | MEDIUM | Docker Desktop VM provides isolation; can't access macOS |
| Container can access other containers | MEDIUM | Acceptable for personal dev; don't run untrusted images |
| Secrets in container filesystem | LOW | Container is ephemeral; config dirs not persisted |
| 1Password token in env var | LOW | Required for Service Account; container is personal |

### Security Checklist

- [ ] Never commit tokens to git
- [ ] Tailscale container uses YOUR identity (inherits your permissions)
- [ ] Set reminder for 1Password Service Account rotation (90 days)
- [ ] Enable MFA on Tailscale account
- [ ] Use Tailscale SSH (not OpenSSH) for audit logging
- [ ] Document in README: socket mount risk for Docker Desktop
- [ ] Don't run untrusted images in Docker Desktop (they can access socket too)

---

## Acceptance Criteria

### Functional Requirements

- [ ] Can SSH into mega-container from phone via Tailscale (`ssh mega-dev`)
- [ ] tmux session survives SSH disconnect and device switch
- [ ] OpenCode works as primary AI tool (test SSH display issues early)
- [ ] Claude Code works as fallback with same config (via oh-my-opencode)
- [ ] All 5 MCP servers connect and respond
- [ ] `docker build` works inside container (socket mount)
- [ ] SSH keys work via 1Password Agent forwarding (not on disk)
- [ ] All repos cloned in ~/code persist across container rebuilds
- [ ] `/mega:where-am-i` provides useful context on session start

### Non-Functional Requirements

- [ ] Container starts in **< 30 seconds** (tools pre-installed in image)
- [ ] Tool versions identical between host and container (mise.lock)
- [ ] Secrets never committed to git (always via 1Password)
- [ ] Clear error message when 1Password token missing (fail-fast bootstrap)
- [ ] Clear error message when Tailscale auth fails
- [ ] Config dirs (~/.claude/, ~/.config/) don't persist (ephemeral)

### Quality Gates

- [ ] Each phase tested before proceeding to next (see Phase Test Procedures)
- [ ] Milestones committed to chezmoi repo
- [ ] Image pushed to ghcr.io after each successful build
- [ ] Existing per-repo devcontainers preserved for other devs
- [ ] README documents: socket mount risk, key rotation, troubleshooting

---

## Files to Create/Modify

### New Files (in chezmoi repo)

| File | Purpose |
|------|---------|
| `mega-container/docker-compose.yml` | Container orchestration (Tailscale sidecar + main container + healthchecks) |
| `mega-container/Dockerfile` | System packages, 1Password CLI, chezmoi, mise + pre-installed tools |
| `mega-container/start.sh` | Host wrapper: fetches OP_SERVICE_ACCOUNT_TOKEN, starts containers, checks Tailscale status |
| `mega-container/entrypoint.sh` | Container bootstrap script (fail-fast, chezmoi apply) |
| `.chezmoiexternal.toml` | Chezmoi externals config (clones private-config repo) |
| `mega-container/.github/workflows/build-image.yml` | CI/CD for ghcr.io image |
| `dot_config/mise/config.toml` | Tool versions (single source of truth) |
| `skills/mega:where-am-i/SKILL.md` | Context switching skill |
| `skills/mega:mcp-check/SKILL.md` | Verify MCP server connections |
| `skills/mega:async-standup/SKILL.md` | Daily standup skill |
| `skills/mega:deploy-dev4/SKILL.md` | Automated deploy skill (router pattern) |
| `skills/mega:k8s-switch/SKILL.md` | Kubernetes context switching (minikube, EKS) + k9s launch |

### GitHub Actions Workflow (TODO-008)

```yaml
# mega-container/.github/workflows/build-image.yml
name: Build Mega Container

on:
  push:
    branches: [main]
    paths:
      - 'mega-container/Dockerfile'
      - 'mega-container/.config/mise/**'
      - '.github/workflows/build-image.yml'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU (multi-arch)
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to ghcr.io
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./mega-container
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/mega-dev:latest
            ghcr.io/${{ github.repository_owner }}/mega-dev:${{ github.sha }}
          platforms: linux/amd64,linux/arm64
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Files to Modify

| File | Changes |
|------|---------|
| `modify_dot_claude.json.tmpl` | Add all 5 MCPs with `onepasswordRead` for secrets |
| `dot_zshrc.tmpl` | Remove `op read` calls (secrets now in config files via chezmoi) |
| `commands/start-work.md.tmpl` | Update for mega-container workflow |
| `CLAUDE.md.tmpl` | Add mega-container guidance, context injection |
| `settings.json.tmpl` | Add Sentry reads to allow list, container permissions |

### Private Config Repo (TODO-003 + TODO-021 Decision)

Create a private repo for sensitive-but-not-secret configuration:

```
private-config-repo/
├── README.md
├── env/
│   ├── dev.env              # Non-secret env vars (AWS_REGION, etc.)
│   └── prod.env
├── terraform-outputs/
│   ├── dev4.json            # Account IDs, ARNs, endpoints
│   └── prod.json
├── docker-compose.override.yml  # Internal URLs, ports
└── .gitignore
```

**Cloned via chezmoi externals (TODO-021 decision):**

Add to `~/.local/share/chezmoi/.chezmoiexternal.toml`:
```toml
[".private-config"]
  type = "git-repo"
  url = "git@github.com:rafaelcarvalho/private-config.git"
  refreshPeriod = "168h"  # Re-pull weekly
  clone.args = ["--depth", "1"]  # Shallow clone
```

This clones the repo to `~/.private-config/` when `chezmoi apply` runs.
Benefits:
- Container is self-contained (no host mount dependency)
- Managed alongside other dotfiles
- SSH agent forwarding handles auth
- Auto-refreshes weekly

---

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Tailscale won't work in container | Low (resolved) | High | Use userspace networking (validated in research) |
| OpenCode SSH display issues | Medium | High | Test in Phase 1.6.4; fallback to Claude Code |
| 1Password token rotation breaks container | Low | High | Document rotation procedure; add health check |
| oh-my-opencode incompatibility | Low | Medium | Keep Claude Code as tested fallback |
| Named volume data loss | Low | High | Always push repos; treat local as ephemeral |
| MCP server startup failures | Medium | Medium | Design for graceful degradation |
| DevPod maintenance concerns | Medium | Medium | Have docker-compose fallback ready |

---

## References

### Internal

- Brainstorm: `docs/brainstorms/2026-02-21-claude-setup-improvements-brainstorm.md`
- Technical Review Todos: `todos/001-025-*.md`
- Current chezmoi source: `~/.local/share/chezmoi/private_dot_claude/`
- MCP template: `~/.local/share/chezmoi/modify_dot_claude.json.tmpl`
- Existing skills: `~/.local/share/chezmoi/private_dot_claude/commands/`

### External (from research)

**Tailscale:**
- [Tailscale Docker Guide](https://tailscale.com/kb/1282/docker) - userspace networking, auth keys
- [Tailscale Auth Keys](https://tailscale.com/kb/1085/auth-keys) - reusable, ephemeral options
- [Tailscale ACLs](https://tailscale.com/kb/1018/acls/) - access control for containers

**1Password:**
- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/) - container secrets
- [1Password CLI Secret References](https://developer.1password.com/docs/cli/secret-references/) - op:// syntax
- [chezmoi 1Password Integration](https://www.chezmoi.io/user-guide/password-managers/1password/) - onepasswordRead

**Docker & Security:**
- [Docker Socket Security](https://docs.docker.com/engine/security/) - socket mount implications
- [DevPod Docker Access Issue #695](https://github.com/loft-sh/devpod/issues/695) - DinD patterns

**Tools:**
- [mise Docker Cookbook](https://mise.jdx.dev/mise-cookbook/docker.html) - pre-install patterns
- [GitHub MCP Server](https://github.com/github/github-mcp-server) - official GitHub MCP
- [Toggl MCP](https://github.com/verygoodplugins/mcp-toggl) - community Toggl integration
- [OpenCode Documentation](https://opencode.ai/docs/) - installation, config
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) - Claude Code config import

**Inspiration:**
- [Sami's dotfiles](https://github.com/sjawhar/dotfiles) - devpod setup reference
- [METR/platform#8](https://github.com/METR/platform/pull/8) - Rootless DinD on k8s (Phase 5 approach)
- [DevPod](https://devpod.sh/) - container orchestration (future Phase 5)
