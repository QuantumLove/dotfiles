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

    # Run the scripts INSIDE the throwaway server. Invoked bare they attach to
    # whatever server the environment points at — the real one — so they read
    # its @resurrect-dir, save the live layout instead of the probe, and write
    # nothing here. The artifacts below are the verdict; run-shell reports its
    # own exit status, not the script's, so a status check would prove nothing.
    tmux -L "$sock" run-shell "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" >/dev/null 2>&1
    [ -n "$(find "$dir" -name 'tmux_resurrect_*.txt' 2>/dev/null | head -1)" ] \
        || check_fail "save.sh wrote no state file"

    tmux -L "$sock" kill-window -t probe 2>/dev/null
    tmux -L "$sock" run-shell "$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh" >/dev/null 2>&1

    # restore.sh recreates windows asynchronously; poll rather than assume.
    for _ in $(seq 1 20); do
        [ "$(tmux -L "$sock" list-windows -t probe 2>/dev/null | grep -c .)" -ge "$before" ] && break
        sleep 0.25
    done

    # Default high so a failure to read the count fails closed rather than open.
    after="$(tmux -L "$sock" list-windows -t probe 2>/dev/null | grep -c . || echo 99)"
    [ "$after" -eq "$before" ] && check_pass "round-trip restored $before window(s)"
    check_fail "restored $after windows, expected $before"
}
run
