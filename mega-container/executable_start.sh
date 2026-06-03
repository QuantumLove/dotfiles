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

# 3. Wait for bootstrap to finish (entrypoint prints "=== Bootstrap Complete ===" when done)
echo "Waiting for container bootstrap..."
for _ in $(seq 1 60); do
  if docker compose logs mega 2>/dev/null | grep -q "=== Bootstrap Complete ==="; then
    break
  fi
  sleep 2
done

# 4. Check Tailscale status
if docker compose exec -T mega tailscale status &>/dev/null; then
  echo "✓ Tailscale connected"
else
  echo ""
  echo "⚠️  Tailscale not yet authenticated. Run one-time setup:"
  echo "   docker compose exec mega tailscale up --ssh --hostname=raf-dev --accept-routes"
  echo ""
  echo "   Then follow the login URL and authenticate."
  echo "   After that, Tailscale will persist across restarts (state saved in volume)."
fi

# 5. Show the tail of bootstrap logs — includes mega-doctor --quick output
#    (full mega-doctor runs in rebuild.sh, not on every start)
echo
echo "=== Bootstrap output ==="
docker compose logs --tail=40 mega 2>&1 | sed -n '/== Bootstrap Complete ==/,$p; /── Summary ──/q' | tail -40

echo
echo "=== Startup Complete ==="
echo "   Run 'mega-doctor' inside the container for full health probe."
