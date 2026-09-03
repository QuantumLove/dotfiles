#!/usr/bin/env bash
# @id         opencode-snapshot-recent
# @desc       An opencode snapshot happened recently
# @severity   liveness
# @scope      container
# @tier       2
# @boot_gate  no
# @input      file:{{HOME}}/.local/share/tmux-snapshots/snapshot.json
#
# Uses the portable mtime helper. The replaced check called `stat -L -c`, which
# is GNU-only, so on the macOS host it always reported stale.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    local age
    age="$(file_age_minutes "${HOME}/.local/share/tmux-snapshots/snapshot.json")" || check_error "cannot read mtime"
    [ "$age" -le 60 ] && check_pass "${age}m old"
    check_fail "${age}m old, older than the 60m floor"
}
run
