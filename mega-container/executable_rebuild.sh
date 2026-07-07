#!/bin/bash
# mega-container/rebuild.sh — rebuild the container image and bring up a fresh
# instance, preserving named volumes (code, tailscale-state, opencode-*).
#
# When to use:
#   - After upgrading tools/versions in the Dockerfile or mise config
#   - After pulling new dotfiles (`chezmoi update && chezmoi apply`)
#   - When the container is in a bad state and a fresh start is wanted
#
# Differs from start.sh: builds the image with --pull (refreshes base layer),
# recreates the container, and runs the full mega-doctor (AWS, MCP, etc.)
# instead of relying on the entrypoint's lightweight --quick probe.
set -e

echo "=== Mega Container Rebuild ==="

MEGA_DIR="$HOME/mega-container"
if [ ! -d "$MEGA_DIR" ]; then
  echo "ERROR: $MEGA_DIR not found. Run 'chezmoi apply' first."
  exit 1
fi
cd "$MEGA_DIR"

# 1. Fetch 1Password token from keychain (same as start.sh)
export OP_SERVICE_ACCOUNT_TOKEN=$(security find-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w 2>/dev/null)
if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
  echo "ERROR: OP_SERVICE_ACCOUNT_TOKEN not in keychain"
  exit 1
fi
echo "✓ 1Password token ready"

# 2. Build image with --pull (refreshes the base Debian layer + invalidates
#    cached layers when versions change)
echo
echo "Building image (this can take 5-10 minutes)..."
docker compose build --pull

# 3. Recreate container — preserves named volumes, only nukes the container.
#    Without --force-recreate, compose would skip if the image hash matched.
echo
echo "Recreating container..."
docker compose up -d --force-recreate

# 4. Wait for bootstrap (entrypoint prints "=== Bootstrap Complete ===").
# On first boot the entrypoint blocks on an interactive Tailscale login — surface that
# URL prominently and keep waiting (up to 10 min) so mega-doctor doesn't run prematurely.
echo
echo "Waiting for container bootstrap..."
auth_shown=false
for _ in $(seq 1 300); do
  logs=$(docker compose logs mega 2>/dev/null)
  if echo "$logs" | grep -q "=== Bootstrap Complete ==="; then
    break
  fi
  if [ "$auth_shown" = false ]; then
    url=$(echo "$logs" | grep -oE 'https://login\.tailscale\.com/[A-Za-z0-9/]+' | tail -1)
    if [ -n "$url" ]; then
      echo ""
      echo "🔑 First-boot Tailscale login required — open this URL to authenticate:"
      echo "   $url"
      echo "   Bootstrap continues automatically once you're connected."
      echo ""
      auth_shown=true
    fi
  fi
  sleep 2
done

# 5. Full mega-doctor probe — slow but comprehensive (AWS, MCP, ssh-agent)
echo
echo "=== Full Health Check ==="
docker compose exec -T mega bash -lc 'mega-doctor' || {
  echo
  echo "⚠️  mega-doctor reported failures. Inspect with:"
  echo "   docker compose logs mega"
  echo "   docker compose exec mega mega-doctor"
  exit 1
}

echo
echo "=== Rebuild Complete ==="
