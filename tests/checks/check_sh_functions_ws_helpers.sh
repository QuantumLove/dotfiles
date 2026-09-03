#!/usr/bin/env bash
# @id         sh-functions-ws-helpers
# @desc       Worktree shell helpers are defined
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      file:{{HOME}}/.sh_functions
#
# The replaced check reported the same warning whether the file was missing or
# present-but-incomplete. The declared input now separates those: absent is an
# error, present-without-the-function is a failure.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local f="$HOME/.sh_functions"
    grep -qE '^[[:space:]]*ws[[:space:]]*\(\)' "$f" && check_pass "ws() defined"
    check_fail "$f exists but defines no ws() helper"
}
run
