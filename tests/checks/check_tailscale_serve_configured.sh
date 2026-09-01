#!/usr/bin/env bash
# @id         tailscale-serve-configured
# @desc       tailscale serve fronts opencode web
# @severity   liveness
# @scope      container
# @tier       2
# @boot_gate  no
# @input      cmd:tailscale
# @input      cmd:jq
#
# The replaced check let an unhandled jq failure yield TS_URL="https://", so the
# *next* check reported an unreachable URL when the real fault was a parse
# error. Failing to read the config is an error here, distinct from a config
# that reads fine and is wrong.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    local status host
    status="$(tailscale serve status 2>/dev/null)" || check_error "tailscale serve status failed"
    host="$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' 2>/dev/null)"
    [ -n "$host" ] || check_error "could not resolve the tailnet DNS name"
    printf '%s' "$status" | grep -q '127.0.0.1:4096' \
        && check_pass "serving opencode web at https://${host%.}"
    check_fail "no serve mapping for 127.0.0.1:4096"
}
run
