#!/usr/bin/env bash
# @id         docker-daemon-responds
# @desc       The docker daemon answers
# @severity   liveness
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:docker
#
# Liveness, not invariant: this asks whether a service is responding right now.
# It was previously `bad`, which after the boot gate lands would have stopped
# the container starting on a transient blip.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    docker ps >/dev/null 2>&1 && check_pass "daemon responding"
    check_fail "socket is mounted but the daemon did not answer"
}
run
