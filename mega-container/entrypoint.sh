#!/bin/bash
# Strict mode: exit on error, undefined vars, pipe failures
set -euo pipefail

echo "=== Mega Container Bootstrap ==="

# 1. Start Tailscale daemon
echo "Starting Tailscale..."
sudo tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
TAILSCALED_PID=$!

# Wait for tailscaled to be ready
sleep 2
for i in {1..10}; do
  if tailscale status &>/dev/null; then
    break
  fi
  echo "  Waiting for tailscaled... (attempt $i/10)"
  sleep 1
done

# Check if already authenticated or needs login
if tailscale status &>/dev/null; then
  TS_STATUS=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "Unknown"')
  if [ "$TS_STATUS" = "Running" ]; then
    echo "✓ Tailscale connected"
    tailscale status | head -5
  else
    echo "⚠️  Tailscale not authenticated. Run one-time setup:"
    echo "   docker exec -it mega-container-mega-1 tailscale up --ssh --hostname=raf-dev --accept-routes"
    echo ""
    echo "   Then follow the login URL and authenticate."
    echo "   After that, Tailscale will persist across restarts."
  fi
else
  echo "⚠️  Tailscale daemon not responding. Check logs with: docker logs mega-container-mega-1"
fi

# 2. Fix ~/code directory permissions (volume may be created as root)
if [ -d "$HOME/code" ] && [ "$(stat -c '%U' "$HOME/code" 2>/dev/null)" = "root" ]; then
  echo "Fixing ~/code directory permissions..."
  sudo chown -R "$USER:$USER" "$HOME/code"
  echo "✓ ~/code permissions fixed"
fi

# 2b. Create ~/code/worktrees directory for /start-work skill
mkdir -p "$HOME/code/worktrees" || { echo "ERROR: Failed to create ~/code/worktrees"; exit 1; }
echo "✓ ~/code/worktrees directory ready"

# 3. Fix Docker socket permissions (Docker Desktop mounts as root:root)
if [ -S /var/run/docker.sock ]; then
  echo "Fixing Docker socket permissions..."
  sudo chmod 666 /var/run/docker.sock
  echo "✓ Docker socket accessible"
fi

# 3b. Verify Docker CLI plugins (fail fast if missing)
if [ -S /var/run/docker.sock ]; then
  echo "Verifying Docker CLI plugins..."
  if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: docker compose plugin not working"
    exit 1
  fi
  if ! docker buildx version >/dev/null 2>&1; then
    echo "ERROR: docker buildx plugin not working"
    exit 1
  fi
  echo "✓ Docker compose + buildx ready"
fi

# 3c. Setup QEMU binfmt for cross-platform Docker builds (aarch64 -> amd64)
if [ -S /var/run/docker.sock ]; then
  echo "Setting up QEMU binfmt for cross-platform builds..."
  if ! docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null 2>&1; then
    echo "ERROR: Failed to setup QEMU binfmt for cross-platform builds"
    exit 1
  fi
  echo "✓ QEMU binfmt ready"
fi

# 4. FAIL FAST: Verify 1Password token exists
if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
  echo "ERROR: OP_SERVICE_ACCOUNT_TOKEN not set"
  echo "Pass via: docker compose run -e OP_SERVICE_ACCOUNT_TOKEN mega"
  exit 1
fi

# 5. FAIL FAST: Verify 1Password connectivity
echo "Checking 1Password connection..."
if ! op account get &>/dev/null; then
  echo "ERROR: 1Password authentication failed"
  echo "Check your OP_SERVICE_ACCOUNT_TOKEN is valid"
  exit 1
fi
echo "✓ 1Password connected"

# 6. FAIL FAST: Fetch Anthropic API key from 1Password
echo "Fetching Anthropic API key from 1Password..."
ANTHROPIC_API_KEY=$(op read "op://Development/Anthropic API Key/credential" 2>/dev/null)
if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "ERROR: Failed to fetch Anthropic API Key from 1Password"
  echo "Ensure 'Anthropic API Key' exists in the Development vault with a 'credential' field"
  exit 1
fi
# Export for current process and persist for SSH login shells
export ANTHROPIC_API_KEY
echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> ~/.secrets_env
echo "✓ Anthropic API key ready"

# 7. FAIL FAST: Fetch GitHub token from 1Password
echo "Fetching GitHub token from 1Password..."
GH_TOKEN=$(op read "op://Development/GitHub Classic PAT/credential" 2>/dev/null)
if [ -z "$GH_TOKEN" ]; then
  echo "ERROR: Failed to fetch GitHub Classic PAT from 1Password"
  echo "Ensure 'GitHub Classic PAT' exists in the Development vault with a 'credential' field"
  exit 1
fi
export GH_TOKEN
echo "export GH_TOKEN='$GH_TOKEN'" >> ~/.secrets_env
echo "✓ GitHub token ready"

# 7b. FAIL FAST: Fetch Datadog keys from 1Password (for MCP server and agents)
echo "Fetching Datadog keys from 1Password..."
DD_API_KEY=$(op read "op://Development/Datadog API Key/credential" 2>/dev/null)
if [ -z "$DD_API_KEY" ]; then
  echo "ERROR: Failed to fetch Datadog API Key from 1Password"
  echo "Ensure 'Datadog API Key' exists in the Development vault with a 'credential' field"
  exit 1
fi
DD_APP_KEY=$(op read "op://Development/Datadog App Key/credential" 2>/dev/null)
if [ -z "$DD_APP_KEY" ]; then
  echo "ERROR: Failed to fetch Datadog App Key from 1Password"
  echo "Ensure 'Datadog App Key' exists in the Development vault with a 'credential' field"
  exit 1
fi
export DD_API_KEY DD_APP_KEY
echo "export DD_API_KEY='$DD_API_KEY'" >> ~/.secrets_env
echo "export DD_APP_KEY='$DD_APP_KEY'" >> ~/.secrets_env
chmod 600 ~/.secrets_env
echo "✓ Datadog keys ready"

# 8. Login to Docker Hub and dhi.io (METR registry, same creds)
echo "Logging into Docker registries..."
DOCKER_USER=$(op read "op://Development/Docker Hub/username" 2>/dev/null)
DOCKER_PAT=$(op read "op://Development/Docker Hub/PAT Read" 2>/dev/null)
if [ -z "$DOCKER_USER" ] || [ -z "$DOCKER_PAT" ]; then
  echo "ERROR: Docker Hub credentials not found in 1Password"
  echo "Ensure 'Docker Hub' exists in Development vault with 'username' and 'PAT Read' fields"
  exit 1
fi
if ! echo "$DOCKER_PAT" | docker login -u "$DOCKER_USER" --password-stdin 2>/dev/null; then
  echo "ERROR: Failed to login to Docker Hub"
  exit 1
fi
if ! echo "$DOCKER_PAT" | docker login dhi.io -u "$DOCKER_USER" --password-stdin 2>/dev/null; then
  echo "ERROR: Failed to login to dhi.io"
  exit 1
fi
echo "✓ Docker Hub + dhi.io authenticated"

# 9. Verify SSH agent and setup known_hosts
echo "Checking SSH agent..."
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Retry loop for SSH agent (may take a moment to be available)
SSH_AGENT_RETRIES=5
SSH_AGENT_READY=false
for i in $(seq 1 $SSH_AGENT_RETRIES); do
  if ssh-add -l &>/dev/null; then
    SSH_AGENT_READY=true
    break
  fi
  echo "  Waiting for SSH agent... (attempt $i/$SSH_AGENT_RETRIES)"
  sleep 2
done

if [ "$SSH_AGENT_READY" = "false" ]; then
  echo "ERROR: SSH agent not available after $SSH_AGENT_RETRIES attempts"
  echo "Ensure 1Password SSH Agent is running on host"
  echo "Check: Docker Desktop magic path /run/host-services/ssh-auth.sock"
  exit 1
fi
echo "✓ SSH agent connected"
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

# Add agent keys to authorized_keys for SSH login (with validation)
ssh-add -L > ~/.ssh/authorized_keys 2>/dev/null
chmod 600 ~/.ssh/authorized_keys

# Verify authorized_keys was populated
KEY_COUNT=$(wc -l < ~/.ssh/authorized_keys 2>/dev/null | tr -d ' ')
if [ "$KEY_COUNT" -gt 0 ]; then
  echo "✓ SSH authorized_keys configured ($KEY_COUNT keys)"
else
  echo "ERROR: authorized_keys is empty - SSH login will not work"
  echo "SSH agent connected but returned no keys"
  exit 1
fi

# 10. Start OpenSSH server (fallback, Tailscale SSH is primary)
echo "Starting OpenSSH server (fallback)..."
sudo /usr/sbin/sshd
echo "✓ OpenSSH server running"

# 11. Apply chezmoi (secrets injected via onepasswordRead templates)
echo "Applying chezmoi configuration..."
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
  chezmoi init --ssh QuantumLove
  if [ $? -ne 0 ]; then
    echo "ERROR: chezmoi init failed"
    exit 1
  fi
fi
chezmoi apply
if [ $? -ne 0 ]; then
  echo "ERROR: chezmoi apply failed"
  exit 1
fi
# Ensure secrets env file is sourced by login shells (after chezmoi may have overwritten .bash_profile)
if [ -f "$HOME/.secrets_env" ] && ! grep -q "secrets_env" "$HOME/.bash_profile" 2>/dev/null; then
  echo '[ -f "$HOME/.secrets_env" ] && . "$HOME/.secrets_env"' >> "$HOME/.bash_profile"
fi

# Inject API key into Claude Code config to skip login prompt
if [ -f "$HOME/.claude.json" ] && [ -n "$ANTHROPIC_API_KEY" ]; then
  tmp=$(mktemp)
  jq --arg key "$ANTHROPIC_API_KEY" '. + {primaryApiKey: $key, hasCompletedOnboarding: true}' "$HOME/.claude.json" > "$tmp" && mv "$tmp" "$HOME/.claude.json"
  echo "✓ Claude Code configured with API key"
fi
echo "✓ chezmoi applied"

# 12. Install Claude Code plugins (if not already installed via chezmoi run_onchange)
echo "Installing Claude Code plugins..."
PLUGIN_LIST="$HOME/.local/share/chezmoi/private_dot_claude/plugin-list.txt"
if [ -f "$PLUGIN_LIST" ] && command -v claude &> /dev/null; then
  while IFS= read -r plugin || [ -n "$plugin" ]; do
    [[ -z "$plugin" || "$plugin" =~ ^# ]] && continue
    echo "  Installing: $plugin"
    claude plugin install "$plugin" 2>/dev/null || true
  done < "$PLUGIN_LIST"
  echo "✓ Claude Code plugins installed"
else
  echo "  (skipping - plugin list or claude not available)"
fi

# 13. Verify mise tools (already pre-installed in image)
# Note: mise activation is handled by chezmoi-managed .bash_profile
echo "Verifying mise tools..."
if ! mise doctor; then
  echo "ERROR: mise doctor failed - tools may not work correctly"
  exit 1
fi
echo "✓ mise tools ready"

echo "=== Bootstrap Complete ==="

# Execute the main command
exec "$@"
