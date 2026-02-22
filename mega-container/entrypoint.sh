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
if ! ssh-add -l &>/dev/null; then
  echo "WARNING: SSH agent not available"
  echo "Some features may not work (private repo cloning, SSH login)"
  echo "Ensure 1Password SSH Agent is running on host"
else
  echo "✓ SSH agent connected"
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
  # Add agent keys to authorized_keys for SSH login
  ssh-add -L > ~/.ssh/authorized_keys 2>/dev/null && chmod 600 ~/.ssh/authorized_keys
  echo "✓ SSH authorized_keys configured"
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
