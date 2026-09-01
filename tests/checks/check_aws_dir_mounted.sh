#!/usr/bin/env bash
# @id         aws-dir-mounted
# @desc       ~/.aws is mounted
# @severity   invariant
# @scope      both
# @tier       1
# @boot_gate  no
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    [ -d "$HOME/.aws" ] && check_pass "$HOME/.aws"
    check_fail "$HOME/.aws is missing"
}
run
