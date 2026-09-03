#!/usr/bin/env bash
# @id         code-volume-mounted
# @desc       ~/code is a mounted volume, not a fresh empty dir
# @severity   invariant
# @scope      container
# @tier       1
# @boot_gate  yes
# @min_corpus 1
#
# Boot-gated deliberately: working in a non-persistent ~/code is worse than
# failing to start. The old check printed an entry count but never asserted on
# it, so a recreated empty volume passed exactly like a populated one.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    local d="$HOME/code" n
    [ -d "$d" ] || check_fail "$d is missing"
    n="$(find "$d" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
    check_scanned "$n"
    [ "$n" -gt 0 ] && check_pass "$n entries"
    check_fail "$d exists but is empty — volume may have been recreated"
}
run
