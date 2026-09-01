#!/usr/bin/env bash
# @id         sshd-running
# @desc       sshd is accepting connections
# @severity   liveness
# @scope      container
# @tier       1
# @boot_gate  no
# @input      cmd:pgrep
#
# Deliberately NOT boot-gated even though it matters: sshd is the recovery path,
# and the gate runs before the entrypoint execs it. Gating on sshd would mean a
# container that cannot start because it has not started yet.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    pgrep -x sshd >/dev/null 2>&1 && check_pass "running"
    check_fail "not running — the box is unreachable over ssh"
}
run
