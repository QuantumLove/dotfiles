#!/usr/bin/env bash
# @id         tmux-restore-in-place
# @desc       tmux-restore runs in place
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      file:{{HOME}}/.local/bin/tmux-restore
#
# A missing file is an error via the declared input, not a warning that reads
# the same as "present but wrong" — the shape the replaced check had.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    grep -q -- '--in-place' "${HOME}/.local/bin/tmux-restore" && check_pass "tmux-restore uses --in-place"
    check_fail "tmux-restore uses --in-place — not found"
}
run
