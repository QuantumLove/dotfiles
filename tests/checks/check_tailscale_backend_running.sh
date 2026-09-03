#!/usr/bin/env bash
# @id         tailscale-backend-running
# @desc       Tailscale backend is up
# @severity   liveness
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:tailscale
# @input      cmd:jq
#
# Liveness, not invariant: this asks whether a service is responding right now.
# It was previously `bad`, which after the boot gate lands would have stopped
# the container starting on a transient blip.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    local state
    state="$(tailscale status --json 2>/dev/null | jq -r ".BackendState // empty" 2>/dev/null)"
    [ -n "$state" ] || check_error "tailscale status --json produced no BackendState"
    [ "$state" = "Running" ] && check_pass "backend Running"
    check_fail "backend state is $state"
}
run
