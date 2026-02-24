#!/bin/bash
# mega-container/start.sh - Single entry point for starting the mega-container
set -e

echo "=== Mega Container Startup ==="

# 1. Fetch secrets from macOS Keychain
echo "Fetching secrets from keychain..."

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

# 3. Check Tailscale status (healthcheck ensures it's ready)
echo "Checking Tailscale..."

if docker compose exec -T tailscale tailscale status &>/dev/null; then
  echo "✓ Tailscale already connected"
  docker compose exec -T tailscale tailscale status
else
  echo ""
  echo "⚠️  Tailscale not yet authenticated. Run one-time setup:"
  echo "   docker compose exec tailscale tailscale up --accept-routes --ssh --hostname=mega-dev"
  echo ""
  echo "   Then follow the login URL and authenticate with your METR gmail."
  echo "   After that, Tailscale will persist across restarts."
fi

echo "=== Startup Complete ==="
