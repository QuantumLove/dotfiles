#!/usr/bin/env bash
# Verification harness for the Warp-extension + plain-tmux durability stack.
# Runs against the real container over SSH on a THROWAWAY socket, so your real
# 'work' sessions are never touched. Automates AE1, AE3, AE5, AE8.
# AE2/AE4 (opencode), AE6 (bell), AE7 (reconnect) are in MANUAL-CHECKLIST.md.
#
# Usage: bash tests/integration/test_tmux_durability.sh [ssh-host]   (default: raf-dev)
set -uo pipefail
HOST="${1:-raf-dev}"

out="$(ssh -o ConnectTimeout=15 "$HOST" 'bash -s' <<'REMOTE'
set +e
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
[ -f "$HOME/.sh_functions" ] && . "$HOME/.sh_functions"
S="harness-$$"; export WARP_TMUX_SOCKET="$S"
D="/tmp/harness-$$"; rm -rf "$D"; mkdir -p "$D"
TM="tmux -L $S"
pass(){ echo "PASS: $1"; }; fail(){ echo "FAIL: $1"; }

# AE1 — ws creates/attaches a session on the work socket, idempotently
$TM kill-server 2>/dev/null
ws a </dev/null >/dev/null 2>&1
$TM has-session -t a 2>/dev/null && pass "AE1 ws creates session" || fail "AE1 ws creates session"
ws a </dev/null >/dev/null 2>&1
[ "$($TM list-sessions 2>/dev/null | grep -c '^a:')" = "1" ] && pass "AE1 ws idempotent (no sprawl)" || fail "AE1 ws idempotent (no sprawl)"

# AE3 — tmux-snapshot targets the work socket and writes a snapshot
$TM new-window -t a >/dev/null 2>&1
tmux-snapshot >/dev/null 2>&1 && pass "AE3 tmux-snapshot runs on work socket" || fail "AE3 tmux-snapshot runs on work socket"

# AE5 — resurrect save -> kill -> restore brings the session back (tmux >= 3.5)
$TM set-option -g @continuum-restore off 2>/dev/null
$TM set-option -g @resurrect-dir "$D" 2>/dev/null
$TM set-option -g @resurrect-capture-pane-contents on 2>/dev/null
$TM new-window -t a -n w2 >/dev/null 2>&1
$TM run-shell "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" 2>/dev/null
[ -f "$D/last" ] && pass "AE5 resurrect save produced a file" || fail "AE5 resurrect save produced a file"
$TM kill-server 2>/dev/null
$TM new-session -d -s tmp 2>/dev/null
$TM set-option -g @continuum-restore off 2>/dev/null
$TM set-option -g @resurrect-dir "$D" 2>/dev/null
$TM run-shell "$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh" 2>/dev/null
$TM has-session -t a 2>/dev/null && pass "AE5 resurrect restore (no crash, session back)" || fail "AE5 resurrect restore (no crash, session back)"
$TM kill-server 2>/dev/null

# AE8 — supercronic scheduler running + crontab present
pgrep -f supercronic >/dev/null && pass "AE8 supercronic running" || fail "AE8 supercronic running"
[ -f "$HOME/.config/supercronic/crontab" ] && pass "AE8 crontab present" || fail "AE8 crontab present"

# tmux version sanity (resurrect restore needs >= 3.5)
v="$(tmux -V)"; case "$v" in *3.[5-9]*|*[4-9].*) pass "tmux $v (>= 3.5)";; *) fail "tmux $v (< 3.5 — restore may crash)";; esac

rm -rf "$D"
REMOTE
)"

echo "$out"
n_pass=$(grep -c '^PASS:' <<<"$out"); n_fail=$(grep -c '^FAIL:' <<<"$out")
echo
echo "Result: ${n_pass} passed, ${n_fail} failed"
[ "$n_fail" -eq 0 ] && [ "$n_pass" -gt 0 ]
