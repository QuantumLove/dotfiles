#!/usr/bin/env bash
# @id         mcp-servers-connected
# @desc       Declared MCP servers connect
# @severity   liveness
# @scope      both
# @tier       3
# @boot_gate  no
# @input      cmd:claude
#
# Tier 3: it starts a client and waits on network round-trips. Behind --deep so
# a scheduled run does not pay for it.
#
# The replaced check incremented the warning counter without emitting a warning
# line, so the summary and the output disagreed about how many problems existed.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    local out failed total
    out="$(claude mcp list 2>&1)" || check_error "claude mcp list failed"
    total="$(printf '%s\n' "$out" | grep -cE '✓|✗|Connected|Failed')"
    [ "$total" -gt 0 ] || check_error "could not parse any server status"
    check_scanned "$total"
    failed="$(printf '%s\n' "$out" | grep -cE '✗|Failed')"
    [ "$failed" -eq 0 ] && check_pass "$total servers connected"
    check_fail "$failed of $total servers failed to connect"
}
run
