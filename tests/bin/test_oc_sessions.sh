#!/usr/bin/env bash
# Tests for the oc session listing.
# Hermetic: renders dot_bash_functions from source, points it at a synthetic
# opencode database, and stubs the real binary. Never touches the live DB.
#
# Run:  bash tests/bin/test_oc_sessions.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
export HOME="$TMP/home"; mkdir -p "$HOME"

pass=0 fail=0
say() { if [ "$1" = ok ]; then printf '  ok    %-50s\n' "$2"; pass=$((pass+1));
        else printf '  FAIL  %-50s %s\n' "$2" "${3:-}"; fail=$((fail+1)); fi; }

# A stub so a fall-through to the real binary is visible rather than silent.
mkdir -p "$TMP/bin"; export PATH="$TMP/bin:$PATH"
printf '#!/usr/bin/env bash\necho "FELL THROUGH TO opencode: $*"\nexit 42\n' > "$TMP/bin/opencode"
chmod +x "$TMP/bin/opencode"

export OPENCODE_DB="$TMP/opencode.db"
now_ms=$(( $(date -u +%s) * 1000 ))
sqlite3 "$OPENCODE_DB" <<SQL
CREATE TABLE session (id TEXT, parent_id TEXT, directory TEXT, title TEXT,
                      time_created INTEGER, time_updated INTEGER);
CREATE TABLE message (id TEXT, session_id TEXT);
INSERT INTO session VALUES ('s1', NULL, '$HOME/code/alpha', 'alpha one',   $now_ms, $now_ms);
INSERT INTO session VALUES ('s2', NULL, '$HOME/code/beta',  'beta one',    $now_ms, $now_ms);
INSERT INTO session VALUES ('s3', NULL, '$HOME/code/alpha', 'alpha two',   $now_ms, $now_ms);
INSERT INTO session VALUES ('s4', 's1', '$HOME/code/alpha', 'a subagent',  $now_ms, $now_ms);
SQL

FUNCS="$TMP/funcs.sh"
chezmoi execute-template < "$REPO_ROOT/dot_sh_functions.tmpl" > "$FUNCS" 2>/dev/null || true
cp "$REPO_ROOT/dot_bash_functions" "$TMP/bash_functions.sh"
# shellcheck disable=SC1090
. "$TMP/bash_functions.sh"

echo "oc session listing"

out="$(oc sessions list 2>&1)"; rc=$?
case "$out" in
    *"FELL THROUGH"*) say FAIL "oc sessions list does not reach the real binary" "$out" ;;
    *) say ok "oc sessions list does not reach the real binary" ;;
esac

out="$(oc sessions list 2>&1)"
printf '%s' "$out" | grep -q 'alpha one' && printf '%s' "$out" | grep -q 'beta one' \
    && say ok "sessions from every project are listed" \
    || say FAIL "sessions from every project are listed" "$out"

printf '%s' "$out" | grep -q 'a subagent' \
    && say FAIL "subagent sessions are excluded" \
    || say ok "subagent sessions are excluded"

# Grouping: each project heading appears once, with its sessions beneath.
alpha_hits="$(printf '%s\n' "$out" | grep -c 'code/alpha')"
[ "$alpha_hits" -eq 1 ] \
    && say ok "each project appears as a single heading" \
    || say FAIL "each project appears as a single heading" "alpha appeared $alpha_hits times"

# Both spellings, plus the bare form, reach the same view.
for form in "sessions list" "session list" "sessions" "history"; do
    o="$(oc $form 2>&1)"
    case "$o" in
        *"FELL THROUGH"*) say FAIL "oc $form reaches the local view" ;;
        *) say ok "oc $form reaches the local view" ;;
    esac
done

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
