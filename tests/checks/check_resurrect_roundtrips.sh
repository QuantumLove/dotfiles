#!/usr/bin/env bash
# @id         resurrect-roundtrips
# @desc       tmux-resurrect saves and restores a session
# @severity   invariant
# @scope      container
# @tier       3
# @boot_gate  no
# @input      cmd:tmux
# @input      file:{{HOME}}/.tmux/plugins/tmux-resurrect/scripts/save.sh
# @input      file:{{HOME}}/.tmux/plugins/tmux-resurrect/scripts/restore.sh
#
# Tier 3 earns its cost here: every cheap proxy for this — plugin directory
# present, cron running, snapshot file fresh — passed while restore was
# actually broken. Runs on a throwaway socket so live sessions are untouched,
# and only under --deep.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local sock="mega-assert-$$" dir before after
    dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "tmux -L '$sock' kill-server 2>/dev/null; rm -rf '$dir'" EXIT

    tmux -L "$sock" new-session -d -s probe 2>/dev/null || check_error "could not start a throwaway tmux server"
    tmux -L "$sock" new-window -t probe 2>/dev/null
    tmux -L "$sock" set-option -g @resurrect-dir "$dir" 2>/dev/null

    before="$(tmux -L "$sock" list-windows -t probe 2>/dev/null | grep -c .)"
    "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" >/dev/null 2>&1 \
        || check_fail "save.sh exited non-zero"
    [ -n "$(find "$dir" -name 'tmux_resurrect_*.txt' 2>/dev/null | head -1)" ] \
        || check_fail "save.sh wrote no state file"

    tmux -L "$sock" kill-window -t probe 2>/dev/null
    "$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh" >/dev/null 2>&1 \
        || check_fail "restore.sh exited non-zero"

    # Default high so a failure to read the count fails closed rather than open.
    after="$(tmux -L "$sock" list-windows -t probe 2>/dev/null | grep -c . || echo 99)"
    [ "$after" -eq "$before" ] && check_pass "round-trip restored $before window(s)"
    check_fail "restored $after windows, expected $before"
}
run
