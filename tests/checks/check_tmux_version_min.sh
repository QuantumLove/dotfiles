#!/usr/bin/env bash
# @id         tmux-version-min
# @desc       tmux is at or above the required version
# @severity   invariant
# @scope      container
# @tier       2
# @boot_gate  no
# @input      cmd:tmux
#
# Invariant, not liveness: the version is pinned in the image, so a mismatch is
# a declaration being false rather than a service being down.
#
# The replaced check used `case $v in 3.[5-9]*|[4-9].*)`, which rejects 3.10 —
# the glob has no notion of numeric ordering. Verified.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MIN="3.5"

run() {
    local v
    v="$(tmux -V 2>/dev/null | awk '{print $2}' | tr -d 'a-z')"
    [ -n "$v" ] || check_error "could not parse tmux -V"
    version_ge "$v" "$MIN" && check_pass "tmux $v (>= $MIN)"
    check_fail "tmux $v is below the required $MIN"
}
run
