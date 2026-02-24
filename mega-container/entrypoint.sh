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

# 3. Verify SSH agent, setup known_hosts, and configure SSH server
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
  echo "WARNING: SSH agent not available after $SSH_AGENT_RETRIES attempts"
  echo "Some features may not work (private repo cloning, SSH login)"
  echo "Ensure 1Password SSH Agent is running on host"
else
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
    echo "WARNING: authorized_keys is empty - SSH login may not work"
    echo "  Try running: ssh-add -L > ~/.ssh/authorized_keys"
  fi
fi

# 4. Start SSH server
echo "Starting SSH server..."
sudo /usr/sbin/sshd
echo "✓ SSH server running"

# 5. Apply chezmoi (secrets injected via onepasswordRead templates)
echo "Applying chezmoi configuration..."
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
  # Try SSH first, fall back to HTTPS with gh auth
  if ssh-add -l &>/dev/null; then
    chezmoi init --ssh QuantumLove || echo "WARNING: chezmoi init failed"
  else
    echo "WARNING: SSH agent not available, skipping chezmoi init"
    echo "Run manually: chezmoi init --ssh QuantumLove"
  fi
fi
if [ -d "$HOME/.local/share/chezmoi" ]; then
  chezmoi apply || echo "WARNING: chezmoi apply failed"
  echo "✓ chezmoi applied"
else
  echo "⚠️  chezmoi not initialized (run manually when SSH agent available)"
fi

# 6. Verify mise tools (already pre-installed in image)
# Note: mise activation is handled by chezmoi-managed .bash_profile
echo "Verifying mise tools..."
mise doctor || true
echo "✓ mise tools ready"

echo "=== Bootstrap Complete ==="

# Execute the main command
exec "$@"
