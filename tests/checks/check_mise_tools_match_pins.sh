#!/usr/bin/env bash
# @id         mise-tools-match-pins
# @desc       Every mise-managed tool is installed at its pinned version
# @severity   invariant
# @scope      container
# @tier       2
# @boot_gate  no
# @input      cmd:mise
#
# Replaces two checks that were unconditional `ok` lines — they printed a
# version and asserted nothing about it. mise already knows the pin and what is
# installed; ask it rather than reimplementing the comparison.
#
# Container scope: the pins live in the container's mise config. On the host the
# same tools are Homebrew-managed and deliberately unpinned.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local missing out
    out="$(mise ls --missing 2>/dev/null)" || check_error "mise ls --missing failed"
    missing="$(printf '%s' "$out" | grep -vE '^[[:space:]]*$' | awk '{print $1}' | tr '\n' ' ')"
    [ -n "${missing// /}" ] && check_fail "pinned but not installed: $missing"
    check_pass "all pinned tools installed"
}
run
