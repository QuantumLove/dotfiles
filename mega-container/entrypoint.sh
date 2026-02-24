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

# 3. FAIL FAST: Fetch Anthropic API key from 1Password
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

# 4. FAIL FAST: Fetch GitHub token from 1Password
echo "Fetching GitHub token from 1Password..."
GH_TOKEN=$(op read "op://Development/GitHub Personal Access Token/credential" 2>/dev/null)
if [ -z "$GH_TOKEN" ]; then
  echo "ERROR: Failed to fetch GitHub Personal Access Token from 1Password"
  echo "Ensure 'GitHub Personal Access Token' exists in the Development vault with a 'credential' field"
  exit 1
fi
export GH_TOKEN
echo "export GH_TOKEN='$GH_TOKEN'" >> ~/.secrets_env
chmod 600 ~/.secrets_env
echo "✓ GitHub token ready"

# 5. Verify SSH agent, setup known_hosts, and configure SSH server
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

# 6. Start SSH server
echo "Starting SSH server..."
sudo /usr/sbin/sshd
echo "✓ SSH server running"

# 7. Apply chezmoi (secrets injected via onepasswordRead templates)
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

# 8. Verify mise tools (already pre-installed in image)
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
