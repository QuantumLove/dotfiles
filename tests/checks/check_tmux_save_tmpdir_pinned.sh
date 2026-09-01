#!/usr/bin/env bash
# @id         tmux-save-tmpdir-pinned
# @desc       tmux-save pins TMUX_TMPDIR
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      file:{{HOME}}/.local/bin/tmux-save
#
# A missing file is an error via the declared input, not a warning that reads
# the same as "present but wrong" — the shape the replaced check had.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    grep -q -- 'TMUX_TMPDIR' "${HOME}/.local/bin/tmux-save" && check_pass "tmux-save pins TMUX_TMPDIR"
    check_fail "tmux-save pins TMUX_TMPDIR — not found"
}
run
