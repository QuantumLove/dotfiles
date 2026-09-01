#!/usr/bin/env bash
# @id         kube-dir-mounted
# @desc       ~/.kube is mounted
# @severity   invariant
# @scope      both
# @tier       1
# @boot_gate  no
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    [ -d "$HOME/.kube" ] && check_pass "$HOME/.kube"
    check_fail "$HOME/.kube is missing"
}
run
