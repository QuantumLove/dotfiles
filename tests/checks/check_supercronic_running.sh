#!/usr/bin/env bash
# @id         supercronic-running
# @desc       Exactly one supercronic process is running
# @severity   liveness
# @scope      container
# @tier       1
# @boot_gate  no
# @input      cmd:pgrep
#
# Folds in the separate single-instance check. `pgrep -x` matches the process
# name exactly; the replaced check used `-f`, which matches any command line
# containing the string — including the grep for it.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local n
    n="$(pgrep -x supercronic 2>/dev/null | grep -c .)"
    case "$n" in
        0) check_fail "not running" ;;
        1) check_pass "running" ;;
        *) check_fail "$n instances running — duplicate schedulers double every job" ;;
    esac
}
run
