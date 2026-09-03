#!/usr/bin/env bash
# @id         opencode-web-responding
# @desc       opencode web answers on :4096
# @severity   liveness
# @scope      container
# @tier       2
# @boot_gate  no
# @input      cmd:curl
#
# Liveness, not invariant: this asks whether a service is responding right now.
# It was previously `bad`, which after the boot gate lands would have stopped
# the container starting on a transient blip.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    curl -sf --max-time 5 http://127.0.0.1:4096/ >/dev/null 2>&1 && check_pass "responding on :4096"
    check_fail "no response on 127.0.0.1:4096"
}
run
