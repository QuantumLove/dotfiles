#!/bin/bash
# mega-container/start.sh - Single entry point for starting the mega-container
set -e

echo "=== Mega Container Startup ==="

# 0. Always run from chezmoi target (where dot_config becomes .config)
MEGA_DIR="$HOME/mega-container"
if [ ! -d "$MEGA_DIR" ]; then
  echo "ERROR: $MEGA_DIR not found. Run 'chezmoi apply' first."
  exit 1
fi
cd "$MEGA_DIR"
echo "✓ Working from $MEGA_DIR"

# 1. Fetch secrets from macOS Keychain
echo "Fetching secrets from keychain..."

export OP_SERVICE_ACCOUNT_TOKEN=$(security find-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w 2>/dev/null)
if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
  echo "ERROR: OP_SERVICE_ACCOUNT_TOKEN not in keychain"
  echo "Add it with: security add-generic-password -a $USER -s OP_SERVICE_ACCOUNT_TOKEN -w 'your-token'"
  exit 1
fi
echo "✓ 1Password token ready"


# 2. Start container
echo "Starting container..."
docker compose up -d

# 3. Check Tailscale status
echo "Checking Tailscale..."

# Wait for container to be ready
sleep 3

if docker compose exec -T mega tailscale status &>/dev/null; then
  echo "✓ Tailscale already connected"
  docker compose exec -T mega tailscale status | head -5
else
  echo ""
  echo "⚠️  Tailscale not yet authenticated. Run one-time setup:"
  echo "   docker compose exec mega tailscale up --ssh --hostname=raf-dev --accept-routes"
  echo ""
  echo "   Then follow the login URL and authenticate."
  echo "   After that, Tailscale will persist across restarts (state saved in volume)."
fi

echo "=== Startup Complete ==="
