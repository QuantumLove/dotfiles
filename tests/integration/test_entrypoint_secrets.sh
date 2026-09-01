#!/usr/bin/env bash
# Tests for the entrypoint's secret classification.
# Hermetic: extracts the secret block from the entrypoint, runs it against a
# stubbed `op` in a fake HOME. Never contacts 1Password and never touches the
# real container.
#
# Run:  bash tests/integration/test_entrypoint_secrets.sh

set -uo pipefail

# Never print a secret value. These tests assert on classification and control
# flow, never on content — a variable that is already set in the ambient
# environment short-circuits the stub and would echo the real thing.
unset LINEAR_API_KEY SENTRY_ACCESS_TOKEN GITHUB_PERSONAL_ACCESS_TOKEN \
      TOGGL_API_KEY SLACK_MCP_XOXP_TOKEN SLACK_MCP_XOXB_TOKEN \
      DD_API_KEY DD_APP_KEY ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY \
      GH_TOKEN 2>/dev/null || true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENTRY="$REPO_ROOT/mega-container/entrypoint.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0
say() { if [ "$1" = ok ]; then printf '  ok    %-52s\n' "$2"; pass=$((pass+1));
        else printf '  FAIL  %-52s %s\n' "$2" "${3:-}"; fail=$((fail+1)); fi; }

# Everything between the Secrets banner and the Docker login step.
awk '/^# Secrets$/,/^# 8\. Login to Docker Hub/' "$ENTRY" | sed '$d' > "$TMP/secrets.sh"
grep -q 'fetch_secret ANTHROPIC_API_KEY' "$TMP/secrets.sh" \
    || { echo "could not extract the secret block"; exit 1; }

# run_with <op-behaviour-script> -> prints "EXIT:<code>" plus output
run_with() {
    local home="$TMP/home"; rm -rf "$home"; mkdir -p "$home/bin"
    cp "$1" "$home/bin/op"; chmod +x "$home/bin/op"
    # bash explicitly: the fragment comes from a #!/bin/bash script and uses
    # printf -v. Sourcing it into whatever shell runs the tests gave misleading
    # failures under zsh.
    env HOME="$home" PATH="$home/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        OP_SERVICE_ACCOUNT_TOKEN=tok \
        bash -c 'set -euo pipefail; . "$1"' _ "$TMP/secrets.sh" 2>&1
    printf 'EXIT:%s' "$?"
}

# --- all secrets available ---------------------------------------------------
cat > "$TMP/op-ok" <<'STUB'
#!/usr/bin/env bash
[ "$1" = read ] && { echo "value-for-$2"; exit 0; }
exit 0
STUB
out="$(run_with "$TMP/op-ok")"
case "$out" in *EXIT:0*) say ok "all secrets present: boot proceeds" ;;
               *) say FAIL "all secrets present: boot proceeds" "$out" ;; esac

perms="$(stat -f %Lp "$TMP/home/.secrets_env" 2>/dev/null || stat -c %a "$TMP/home/.secrets_env" 2>/dev/null)"
[ "$perms" = 600 ] && say ok "secrets file is 0600 from creation" \
                   || say FAIL "secrets file is 0600 from creation" "got $perms"

# --- an optional secret missing ----------------------------------------------
cat > "$TMP/op-no-gws" <<'STUB'
#!/usr/bin/env bash
case "$2" in *GWS*) echo "no item matching \"GWS Credentials JSON\"" >&2; exit 1 ;; esac
[ "$1" = read ] && { echo "value-for-$2"; exit 0; }
STUB
out="$(run_with "$TMP/op-no-gws")"
case "$out" in *EXIT:0*) say ok "missing optional secret: boot still proceeds" ;;
               *) say FAIL "missing optional secret: boot still proceeds" "$out" ;; esac
case "$out" in *"morning-triage"*) say ok "and names the feature it disables" ;;
               *) say FAIL "and names the feature it disables" ;; esac
case "$out" in *"no item matching"*) say ok "and keeps op's reason" ;;
               *) say FAIL "and keeps op's reason" "$out" ;; esac

# --- a required secret missing -----------------------------------------------
cat > "$TMP/op-no-anthropic" <<'STUB'
#!/usr/bin/env bash
case "$2" in *Anthropic*) echo "authentication required" >&2; exit 1 ;; esac
[ "$1" = read ] && { echo "value-for-$2"; exit 0; }
STUB
out="$(run_with "$TMP/op-no-anthropic")"
case "$out" in *EXIT:0*) say FAIL "missing required secret: boot aborts" "$out" ;;
               *) say ok "missing required secret: boot aborts" ;; esac
case "$out" in *"authentication required"*) say ok "and distinguishes auth failure from a missing item" ;;
               *) say FAIL "and distinguishes auth failure from a missing item" "$out" ;; esac

# --- an empty value is a failure, not a silent success -----------------------
cat > "$TMP/op-empty" <<'STUB'
#!/usr/bin/env bash
case "$2" in *GitHub*) exit 0 ;; esac
[ "$1" = read ] && { echo "value-for-$2"; exit 0; }
STUB
out="$(run_with "$TMP/op-empty")"
case "$out" in *EXIT:0*) say FAIL "an empty required value aborts" "$out" ;;
               *) say ok "an empty required value aborts" ;; esac

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
