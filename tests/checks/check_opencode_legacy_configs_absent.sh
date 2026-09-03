#!/usr/bin/env bash
# @id         opencode-legacy-configs-absent
# @desc       Deprecated opencode config filenames are gone
# @severity   invariant
# @scope      container
# @tier       1
# Container scope: the migration re-trigger happens where omo runs.
# @boot_gate  no
#
# Their presence re-triggers omo's migration on every boot. Absence is the
# declared state, so this fails rather than warns.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LEGACY=(oh-my-opencode.json oh-my-openagent.json)

run() {
    local found=()
    for n in "${LEGACY[@]}"; do
        [ -e "$HOME/.config/opencode/$n" ] && found+=("$n")
    done
    [ ${#found[@]} -eq 0 ] && check_pass "no legacy config files"
    check_fail "present, re-triggers migration: ${found[*]}"
}
run
