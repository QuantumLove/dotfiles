#!/usr/bin/env bash
# @id         omo-config-present
# @desc       omo config exists and parses
# @severity   invariant
# @scope      both
# @tier       1
# @boot_gate  yes
# @input      file:{{HOME}}/.omo/omo.jsonc
# @input      cmd:jq
#
# Presence alone is not enough: an unparseable config is the state that let a
# jq failure read as "zero problems found". Absence is caught by the declared
# input; unparseable is caught here, and both report error rather than fail.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local f="$HOME/.omo/omo.jsonc"
    sed 's|^[[:space:]]*//.*$||' "$f" | jq -e . >/dev/null 2>&1 \
        || check_error "$f does not parse as JSON"
    check_pass "present and parses"
}
run
