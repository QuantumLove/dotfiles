#!/usr/bin/env bash
# @id         tmux-save-recent
# @desc       The saved tmux layout still reflects the live one
# @severity   liveness
# @scope      container
# @tier       2
# @boot_gate  no
# @input      cmd:tmux
# @input      file:{{HOME}}/.local/share/tmux-snapshots/resurrect/last
#
# Freshness alone is the wrong question. tmux-resurrect deduplicates: it writes
# the new snapshot, compares it to `last`, and DELETES it when the two are
# identical. So a layout that has not changed since the last save can never
# refresh the mtime, and an unchanged-but-perfectly-current snapshot reads as
# stale forever. What matters for recovery is not when the file was written but
# whether it still describes the running server — so fall back to comparing them.
#
# Targets the `work` server explicitly, because that is the one tmux-save saves.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local sock="${WARP_TMUX_SOCKET:-work}"
    export TMUX_TMPDIR="${TMUX_TMPDIR:-$HOME/.tmux/sockets}"
    local last="${HOME}/.local/share/tmux-snapshots/resurrect/last"

    # No server means resurrect has nothing to save, so an old file is the
    # correct state rather than a stale one. Failing here would report a fresh
    # container as broken.
    tmux -L "$sock" list-sessions >/dev/null 2>&1 \
        || check_skip "no '$sock' tmux server running — nothing to save"

    local age
    age="$(file_age_minutes "$last")" || check_error "cannot read mtime"
    [ "$age" -le 60 ] && check_pass "${age}m old"

    local saved live
    saved="$(awk -F'\t' '/^(pane|window)/ {print $2}' "$last" 2>/dev/null | sort -u)"
    live="$(tmux -L "$sock" list-sessions -F '#{session_name}' 2>/dev/null | sort -u)"

    [ -z "$live" ] && check_error "could not read live sessions from the '$sock' server"
    check_scanned 1

    if [ "$saved" = "$live" ]; then
        check_pass "${age}m old, but still matches the live sessions ($(echo "$live" | tr '\n' ' ' | sed 's/ $//'))"
    fi
    check_fail "${age}m old and the layout has drifted — saved: $(echo "$saved" | tr '\n' ' '); live: $(echo "$live" | tr '\n' ' ')"
}
run
