#!/usr/bin/env bash
# Unit tests for the ws/wsl tmux session helpers (dot_sh_functions.tmpl).
# Stubs `tmux` to record argv — verifies socket targeting + nesting logic
# without a real tmux. Real-tmux behavior is covered by the U1 harness.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMUX_STUB_LOG="$TMP/tmux.log"; : > "$TMUX_STUB_LOG"

cat > "$TMP/tmux" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$TMUX_STUB_LOG"
for a in "$@"; do [ "$a" = "has-session" ] && exit 1; done
exit 0
STUB
chmod +x "$TMP/tmux"

chezmoi execute-template < "$REPO_ROOT/dot_sh_functions.tmpl" > "$TMP/funcs.sh"
export PATH="$TMP:$PATH"
# shellcheck disable=SC1090
. "$TMP/funcs.sh"

pass=0 fail=0
log() { cat "$TMUX_STUB_LOG"; }
reset() { : > "$TMUX_STUB_LOG"; }
check() { # name, grep-pattern
    if log | grep -qE -- "$2"; then printf '  ok    %s\n' "$1"; pass=$((pass+1))
    else printf '  FAIL  %s (no match: %s)\n' "$1" "$2"; fail=$((fail+1)); fi
}
refute() { # name, grep-pattern that must NOT appear
    if log | grep -qE -- "$2"; then printf '  FAIL  %s (unexpected: %s)\n' "$1" "$2"; fail=$((fail+1))
    else printf '  ok    %s\n' "$1"; pass=$((pass+1)); fi
}

echo "ws creates-then-attaches on default socket 'work':"
reset; ( unset TMUX; ws proj ) >/dev/null 2>&1
check "targets -L work"        '-L work .*-s proj|-L work has-session'
check "creates when absent"    'new-session -d -s proj'
check "attaches (not nested)"  'attach -t proj'

echo "ws is nesting-safe (TMUX set -> switch-client):"
reset; ( TMUX=fake ws bar ) >/dev/null 2>&1
check "switch-client used"     'switch-client -t bar'
refute "no bare attach first"  '^-L work attach -t bar$'

echo "WARP_TMUX_SOCKET overrides the socket:"
reset; ( unset TMUX; WARP_TMUX_SOCKET=custom ws x ) >/dev/null 2>&1
check "targets -L custom"      '-L custom'
refute "not the default work"  '-L work'

echo "wsl lists on the work socket:"
reset; ( wsl ) >/dev/null 2>&1
check "list-sessions on work"  '-L work list-sessions'

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
