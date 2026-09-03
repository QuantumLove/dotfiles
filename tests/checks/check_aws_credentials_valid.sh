#!/usr/bin/env bash
# @id         aws-credentials-valid
# @desc       AWS credentials are usable
# @severity   liveness
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:aws
#
# Liveness, not invariant: this asks whether a service is responding right now.
# It was previously `bad`, which after the boot gate lands would have stopped
# the container starting on a transient blip.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    aws sts get-caller-identity >/dev/null 2>&1 && check_pass "credentials valid"
    check_skip "not logged in — run aws-sso-login"
}
run
