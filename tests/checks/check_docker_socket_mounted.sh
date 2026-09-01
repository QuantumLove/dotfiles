#!/usr/bin/env bash
# @id         docker-socket-mounted
# @desc       Docker socket is mounted
# @severity   invariant
# @scope      both
# @tier       1
# @boot_gate  no
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    [ -S "/var/run/docker.sock" ] && check_pass "/var/run/docker.sock"
    check_fail "/var/run/docker.sock is missing"
}
run
