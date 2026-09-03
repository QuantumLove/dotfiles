#!/usr/bin/env bash
# @id         supercronic-crontab-declares-jobs
# @desc       The crontab declares its expected jobs
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      file:{{HOME}}/.config/supercronic/crontab
# @min_corpus 5
#
# Presence was not enough: an empty crontab is a file that exists. Enumerate the
# jobs that must be scheduled.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

EXPECTED=(tmux-save tmux-snapshot fill-toggl-cron opencode-prune rotate-logs)

run() {
    local f="$HOME/.config/supercronic/crontab" missing=()
    for j in "${EXPECTED[@]}"; do
        grep -q -- "$j" "$f" || missing+=("$j")
    done
    check_scanned "${#EXPECTED[@]}"
    [ ${#missing[@]} -eq 0 ] && check_pass "${#EXPECTED[@]} jobs declared"
    check_fail "not scheduled: ${missing[*]}"
}
run
