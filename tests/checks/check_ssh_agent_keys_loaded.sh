#!/usr/bin/env bash
# @id         ssh-agent-keys-loaded
# @desc       The ssh agent holds at least one identity
# @severity   liveness
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:ssh-add
#
# The check this replaces was `ssh-add -l | wc -l`, which reports 1 for an EMPTY
# agent: "The agent has no identities." goes to stdout, so the line count is 1
# either way. Verified. Use the exit status, which is 0 with keys, 1 when empty,
# 2 when the agent is unreachable — three states the count collapsed into one.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    [ -n "${SSH_AUTH_SOCK:-}" ] || check_skip "SSH_AUTH_SOCK is unset"
    local out rc
    out="$(ssh-add -l 2>&1)"; rc=$?
    case "$rc" in
        0) check_pass "$(printf '%s' "$out" | grep -c .) identities loaded" ;;
        1) check_fail "agent reachable but holds no identities" ;;
        *) check_error "agent unreachable: $out" ;;
    esac
}
run
