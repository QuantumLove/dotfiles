#!/usr/bin/env bash
# @id         no-silenced-supervision
# @desc       No supervised process discards its failure output
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:grep
# @min_corpus 8
#
# Regression prevention, not remediation: the two exemplars — a LaunchAgent that
# crash-looped roughly ten thousand times against a zero-byte log, and a
# once-a-minute watchdog that sent its start attempt to /dev/null — were both
# fixed on 2026-08-29. This exists so the next one is loud.
#
# A supervised process is one something restarts: a LaunchAgent, a crontab
# entry, or a background loop in the entrypoint. When those fail silently, a
# permanent fault is indistinguishable from a healthy service.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local src; src="$(chezmoi source-path 2>/dev/null)" || check_error "cannot resolve chezmoi source"
    local n=0 offenders=()

    # 1. LaunchAgents must name a StandardErrorPath.
    while IFS= read -r plist; do
        n=$((n + 1))
        grep -q 'StandardErrorPath' "$plist" 2>/dev/null \
            || offenders+=("$(basename "$plist"):no-StandardErrorPath")
    done < <(find "$src/private_Library/LaunchAgents" -name '*.plist*' 2>/dev/null)

    # 2. Scheduled jobs must not send their output to /dev/null.
    local crontab="$src/private_dot_config/supercronic/crontab"
    if [ -f "$crontab" ]; then
        while IFS= read -r line; do
            n=$((n + 1))
            case "$line" in
                *'/dev/null'*) offenders+=("crontab:${line:0:32}...") ;;
            esac
        done < <(grep -vE '^[[:space:]]*(#|$)' "$crontab" 2>/dev/null)
    fi

    # 3. Restart loops in the entrypoint must capture stderr. `cmd >>log 2>&1`
    #    is the compliant shape; `cmd >/dev/null 2>&1` inside a while-true is not.
    local entry="$src/mega-container/entrypoint.sh"
    if [ -f "$entry" ]; then
        n=$((n + 1))
        awk '/while true/,/done \)/' "$entry" 2>/dev/null | grep -q '/dev/null' \
            && offenders+=("entrypoint:restart-loop-discards-output")
    fi

    check_scanned "$n"
    [ ${#offenders[@]} -eq 0 ] && check_pass "$n supervised entry points all keep their output"
    check_fail "discarding failure output: ${offenders[*]}"
}
run
