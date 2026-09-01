#!/usr/bin/env bash
# @id         bin-core-present
# @desc       Core CLI tooling is on PATH
# @severity   invariant
# @scope      both
# @tier       1
# @boot_gate  yes
# @input      cmd:command
# @min_corpus 6
#
# One enumerating check rather than eight one-liners: separate ok/bad lines
# cannot tell you whether all of them ran, and the loop that emitted them had no
# identity to register.
#
# opencode and tmux moved to the container list — neither is installed on the
# macOS host, so asserting them at `both` scope fails for the wrong reason.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CORE=(claude chezmoi mise git jq op)

run() {
    local missing=()
    for b in "${CORE[@]}"; do
        command -v "$b" >/dev/null 2>&1 || missing+=("$b")
    done
    check_scanned "${#CORE[@]}"
    [ ${#missing[@]} -eq 0 ] && check_pass "${#CORE[@]} core binaries present"
    check_fail "missing: ${missing[*]}"
}
run
