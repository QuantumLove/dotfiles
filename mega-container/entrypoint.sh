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

# Authenticate if needed. Interactive login persists in the tailscale-state volume,
# so this only runs on first boot (fresh volume). We log in and BLOCK here rather
# than continue unauthenticated — the container must come up fully healthy, never
# in a degraded state. `tailscale up` prints an auth URL to the logs and waits until
# the login completes, after which bootstrap continues on its own.
if [ "$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "Unknown"')" = "Running" ]; then
  echo "✓ Tailscale connected"
  tailscale status | head -5
else
  echo "──────────────────────────────────────────────────────────────────────"
  echo "  Tailscale needs a one-time login. Open the URL printed below and"
  echo "  authenticate — bootstrap continues automatically once connected."
  echo "  (Identity persists in the tailscale-state volume; first boot only.)"
  echo "──────────────────────────────────────────────────────────────────────"
  sudo tailscale up --ssh --hostname=raf-dev --accept-routes
  echo "✓ Tailscale connected"
fi

# 2. Fix user-owned volume permissions (Docker creates named volumes as root)
USER_VOLUMES=(
  "$HOME/code"
  "$HOME/.local/share/opencode"
  "$HOME/.local/share/tmux-snapshots"
)
for vol_dir in "${USER_VOLUMES[@]}"; do
  if [ -d "$vol_dir" ] && [ "$(stat -c '%U' "$vol_dir" 2>/dev/null)" = "root" ]; then
    echo "Fixing $vol_dir permissions..."
    sudo chown -R "$(id -un):$(id -gn)" "$vol_dir"
  fi
done
echo "✓ Volume permissions ready"

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

# 3c. Connect to minikube network (allows kubectl to reach host's minikube)
if [ -S /var/run/docker.sock ]; then
  if docker network ls --format '{{.Name}}' | grep -q '^minikube$'; then
    echo "Connecting to minikube network..."
    # Get our container ID (hostname in Docker containers)
    CONTAINER_ID=$(hostname)
    if [ -n "$CONTAINER_ID" ]; then
      # Connect if not already connected
      if ! docker network inspect minikube --format '{{range .Containers}}{{.Name}}{{end}}' 2>/dev/null | grep -q "$CONTAINER_ID"; then
        docker network connect minikube "$CONTAINER_ID" 2>/dev/null || true
      fi
      echo "✓ Connected to minikube network"
    fi
  else
    echo "  (minikube not running, skipping network connection)"
  fi
fi

# 3d. Setup QEMU binfmt for cross-platform Docker builds (aarch64 -> amd64)
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

# ---------------------------------------------------------------------------
# Secrets
#
# Every secret is declared with a class. `required` aborts the boot; `optional`
# warns and continues with the feature it gates disabled. Previously the class
# was implicit in whether a given block happened to call exit 1, and the
# troubleshooting doc disagreed with the code about which secrets were which.
#
# op's stderr is kept rather than sent to /dev/null. Without it every failure
# reads "Failed to fetch X" whether the cause was an expired token, no network,
# a renamed vault item, or a missing field — and those need different fixes.
# ---------------------------------------------------------------------------

# Create with restrictive permissions BEFORE the first secret lands in it. The
# previous ordering chmod'ed only after five secrets had already been written
# under the default umask.
install -m 600 /dev/null ~/.secrets_env

secret_env() { printf "export %s='%s'\n" "$1" "$2" >> ~/.secrets_env; }

# fetch_secret <env-var> <op-path> <required|optional> <what-it-gates>
fetch_secret() {
  local var="$1" path="$2" class="$3" gates="$4"
  local value err rc=0
  err="$(mktemp)"
  # `if !` rather than a bare assignment: the entrypoint runs under `set -e`, so
  # a failing command substitution aborts the script immediately and every line
  # of error handling below becomes unreachable. The diagnostic has to survive
  # the failure it is describing.
  if ! value="$(op read "$path" 2>"$err")"; then rc=1; fi

  if [ $rc -ne 0 ] || [ -z "$value" ]; then
    local reason; reason="$(tr -d '\n' < "$err" | head -c 200)"
    rm -f "$err"
    if [ "$class" = required ]; then
      echo "ERROR: required secret $var could not be read from $path" >&2
      echo "       reason: ${reason:-op produced no output}" >&2
      exit 1
    fi
    echo "⚠️  optional secret $var unavailable — $gates disabled"
    echo "    reason: ${reason:-op produced no output}"
    return 1
  fi
  rm -f "$err"

  printf -v "$var" '%s' "$value"
  export "${var?}"
  secret_env "$var" "$value"
  echo "✓ $var"
  return 0
}

secret_env OP_SERVICE_ACCOUNT_TOKEN "$OP_SERVICE_ACCOUNT_TOKEN"

fetch_secret ANTHROPIC_API_KEY "op://Development/Anthropic API Key/credential"     required "Claude Code"
fetch_secret OPENAI_API_KEY    "op://Development/OpenAI API Key/credential"        required "OpenAI models"
fetch_secret GEMINI_API_KEY    "op://Development/Google Gemini API Key/credential" required "Gemini models"
fetch_secret GH_TOKEN          "op://Development/GitHub Classic PAT/credential"    required "GitHub access"
fetch_secret DD_API_KEY        "op://Development/Datadog API Key/credential"       required "Datadog"
fetch_secret DD_APP_KEY        "op://Development/Datadog App Key/credential"       required "Datadog"

# Pulumi's Datadog provider expects DATADOG_* naming.
export DATADOG_API_KEY="$DD_API_KEY" DATADOG_APP_KEY="$DD_APP_KEY" \
       DATADOG_API_URL="https://api.us3.datadoghq.com"
secret_env DD_SITE          "us3.datadoghq.com"
secret_env DD_HOST          "https://api.us3.datadoghq.com"
secret_env DATADOG_API_KEY  "$DATADOG_API_KEY"
secret_env DATADOG_APP_KEY  "$DATADOG_APP_KEY"
secret_env DATADOG_API_URL  "$DATADOG_API_URL"

# Optional: a missing one disables a feature, it does not stop the boot.
if fetch_secret GWS_CREDENTIALS_JSON "op://Development/GWS Credentials JSON/notesPlain" \
     optional "morning-triage and Gmail access"; then
  mkdir -p ~/.config/gws
  install -m 600 /dev/null ~/.config/gws/credentials.json
  printf '%s' "$GWS_CREDENTIALS_JSON" > ~/.config/gws/credentials.json
  secret_env GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE "$HOME/.config/gws/credentials.json"
fi


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

# 10c. Resolve Tailscale hostname up-front so opencode can include it in CORS allowlist.
# Without --cors, browsers hitting https://$TS_HOST proxied to http://127.0.0.1:4096
# get cross-origin-blocked SSE — symptom: session list intermittently empty / stale.
TS_HOST=$(tailscale status --json | jq -r '.Self.DNSName // .Self.HostName' | sed 's/\.$//')

# 10d. Apply chezmoi (secrets injected via onepasswordRead templates).
# Must run BEFORE opencode web: opencode and omo read their config
# (~/.config/opencode/opencode.json, ~/.omo/omo.jsonc) once at process start, and on a
# fresh rebuild neither file exists until chezmoi writes it. Starting the server first
# pins it to built-in default models for the container's lifetime.
echo "Applying chezmoi configuration..."
# Source may be bind-mounted (local, no-push dev loop) or absent (fresh clone).
# Ensure the chezmoi config exists either way before applying.
if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
  if [ -f "$HOME/.local/share/chezmoi/.chezmoi.toml.tmpl" ]; then
    chezmoi init
  else
    chezmoi init --ssh QuantumLove
  fi
fi
# `if [ $? -ne 0 ]` after a command is unreachable under `set -e`: a non-zero
# exit aborts the script before the test runs, so the diagnostic never printed
# and the boot died with a bare exit code. Trap the failure instead.
chezmoi apply --force || {
  echo "ERROR: chezmoi apply failed — dotfiles were not applied" >&2
  exit 1
}
# Inject API key into Claude Code config to skip login prompt
if [ -f "$HOME/.claude.json" ] && [ -n "$ANTHROPIC_API_KEY" ]; then
  tmp=$(mktemp)
  jq --arg key "$ANTHROPIC_API_KEY" '. + {primaryApiKey: $key, hasCompletedOnboarding: true}' "$HOME/.claude.json" > "$tmp" && mv "$tmp" "$HOME/.claude.json"
  echo "✓ Claude Code configured with API key"
fi
echo "✓ chezmoi applied"

# 10e. Start OpenCode web (UI + API on one port, behind tailscale serve)
# ---------------------------------------------------------------------------
# Correctness gate
#
# Runs before the agent surfaces, and never stops the boot. A container that
# refuses to start is a container you cannot ssh into to fix, and the recovery
# would need a terminal on the Mac — which defeats reaching this box from
# anywhere. So the box always comes up and always stays reachable.
#
# What it does instead is refuse to be silently wrong: the verdict is written to
# a status file, the healthcheck reads it, the login banner shows it, and the
# agent surfaces below stay down while an invariant is failing. Reachable and
# obviously degraded beats unreachable.
# ---------------------------------------------------------------------------
BOOT_GATE_OK=1
if "$HOME/.local/bin/mega-assert" --boot-gate --report; then
  echo "✓ boot invariants hold"
else
  BOOT_GATE_OK=0
  echo ""
  echo "########################################################################"
  echo "#  BOOT INVARIANTS FAILING — agent surfaces held back                  #"
  echo "#  Details:  cat ~/.local/state/mega-assert/last-run.txt               #"
  echo "#  Re-run:   mega-assert --boot-gate                                   #"
  echo "#  Override: MEGA_ASSERT_FORCE_SURFACES=1 in the environment           #"
  echo "########################################################################"
  echo ""
fi

if [ "$BOOT_GATE_OK" -eq 0 ] && [ "${MEGA_ASSERT_FORCE_SURFACES:-0}" != "1" ]; then
  echo "Skipping opencode web — boot invariants are failing."
else
echo "Starting opencode web..."
mkdir -p "$HOME/.local/state"
nohup opencode web --hostname 127.0.0.1 --port 4096 --log-level INFO \
  --cors "https://$TS_HOST" \
  > "$HOME/.local/state/opencode-web.log" 2>&1 &
for _ in $(seq 1 30); do
  if curl -sf http://127.0.0.1:4096/ >/dev/null 2>&1; then break; fi
  sleep 1
done
if ! curl -sf http://127.0.0.1:4096/ >/dev/null 2>&1; then
  echo "ERROR: opencode web failed to start (see ~/.local/state/opencode-web.log)"
  exit 1
fi
echo "✓ opencode web on :4096 (CORS allows https://$TS_HOST)"

# 10f. Expose opencode web via Tailscale HTTPS (idempotent — persisted in tailscale-state volume)
if ! sudo tailscale serve --bg http://127.0.0.1:4096; then
  echo "ERROR: tailscale serve failed"
  exit 1
fi
echo "✓ opencode web reachable at https://$TS_HOST"
fi

# 11b. Start supercronic for durability saves (supervised — tini reaps but won't restart)
mkdir -p "$HOME/.local/state"
if command -v supercronic >/dev/null 2>&1 && [ -f "$HOME/.config/supercronic/crontab" ]; then
  echo "Starting supercronic..."
  ( while true; do
      supercronic "$HOME/.config/supercronic/crontab" >> "$HOME/.local/state/supercronic.log" 2>&1
      echo "[entrypoint] supercronic exited, restarting in 5s" >> "$HOME/.local/state/supercronic.log"
      sleep 5
    done ) &
  echo "✓ supercronic running"
else
  echo "⚠️  supercronic/crontab missing — durability saves not scheduled"
fi

# 11c. Restore the work tmux session set from the last save (layout + opencode).
# Nothing else starts the work server on boot, so without this a rebuild leaves
# you with no sessions until you manually start tmux. No-op if nothing was saved.
if [ -x "$HOME/.local/bin/tmux-boot-restore" ]; then
  echo "Restoring work tmux sessions..."
  "$HOME/.local/bin/tmux-boot-restore" && echo "✓ work tmux sessions restored (if any were saved)"
fi

# 12. Verify mise tools (already pre-installed in image)
# Note: mise activation is handled by chezmoi-managed .bash_profile
# Regenerate shims before doctor: a missing shim (e.g. jp.py) makes doctor
# fail. reshim runs under `set -e`, so a genuine reshim failure still aborts.
echo "Verifying mise tools..."
mise reshim
if ! mise doctor; then
  echo "ERROR: mise doctor failed - tools may not work correctly"
  exit 1
fi
echo "✓ mise tools ready"

# 13. Initialize time-tracker (tt) machine identity (idempotent)
echo "Initializing time-tracker..."
if ! command -v tt &>/dev/null; then
  echo "ERROR: tt (time-tracker) not found in PATH"
  exit 1
fi
tt init --label "$(hostname)"
echo "✓ time-tracker ready"

# 14. Verify sqlite3 and column are available (required for oc history)
echo "Verifying sqlite3 and column..."
if ! command -v sqlite3 &>/dev/null; then
  echo "ERROR: sqlite3 not found (required for oc history)"
  exit 1
fi
if ! command -v column &>/dev/null; then
  echo "ERROR: column not found (required for oc history formatting)"
  exit 1
fi
echo "✓ sqlite3 + column ready"

echo "=== Bootstrap Complete ==="

# 15. Full report for the log. The gate above already decided; this is detail.
"$HOME/.local/bin/mega-doctor" || echo "⚠️  see ~/.local/state/mega-assert/last-run.txt"

# Execute the main command
exec "$@"
