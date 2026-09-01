#!/usr/bin/env bash
# @id         tmux-save-recent
# @desc       A tmux save happened recently
# @severity   liveness
# @scope      container
# @tier       2
# @boot_gate  no
# @input      cmd:tmux
# @input      file:{{HOME}}/.local/share/tmux-snapshots/resurrect/last
#
# Uses the portable mtime helper. The replaced check called `stat -L -c`, which
# is GNU-only, so on the macOS host it always reported stale.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    # No tmux server means resurrect has nothing to save, so an old file is the
    # correct state rather than a stale one. Failing here would report a fresh
    # container as broken.
    tmux has-session 2>/dev/null || check_skip "no tmux server running — nothing to save"
    local age
    age="$(file_age_minutes "${HOME}/.local/share/tmux-snapshots/resurrect/last")" || check_error "cannot read mtime"
    [ "$age" -le 60 ] && check_pass "${age}m old"
    check_fail "${age}m old, older than the 60m floor"
}
run
