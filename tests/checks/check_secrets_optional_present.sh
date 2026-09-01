#!/usr/bin/env bash
# @id         secrets-optional-present
# @desc       Optional secrets, reported when absent
# @severity   liveness
# @scope      container
# @tier       1
# @boot_gate  no
#
# Absence is reported, never a failure — that is R19's whole point, and the
# reason the severity split exists. A skip with a named reason beats a warning
# that looks like a problem.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OPTIONAL=(GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE SLACK_MCP_XOXP_TOKEN)

run() {
    local absent=()
    for v in "${OPTIONAL[@]}"; do
        [ -n "${!v:-}" ] || absent+=("$v")
    done
    [ ${#absent[@]} -eq 0 ] && check_pass "all optional secrets present"
    check_skip "absent (optional, features disabled): ${absent[*]}"
}
run
