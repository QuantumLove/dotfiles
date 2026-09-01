#!/usr/bin/env bash
# @id         hooks-reachable
# @desc       Every repo resolves core.hooksPath to the guard directory
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:git
# @input      cmd:jq
# @min_corpus 2
#
# "We shipped the hook" is not "the guard is live". A repo-local core.hooksPath
# silently wins over the global one — husky sets exactly that — and a
# non-executable hook is skipped with no error. Both are invisible without a walk.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    guard_enforcement_active \
        || check_skip "enforcement_active is false — hooks installed but core.hooksPath is not set yet"

    local want="$HOME/.config/git/hooks" n=0 bad=()
    while IFS= read -r r; do
        [ -n "$r" ] || continue
        n=$((n + 1))
        local eff; eff="$(git -C "$r" config --get core.hooksPath 2>/dev/null || echo "")"
        case "$eff" in
            "$want") ;;
            "")      bad+=("$(basename "$r"):unset") ;;
            *)       bad+=("$(basename "$r"):$eff") ;;
        esac
    done < <(repo_corpus)

    check_scanned "$n"
    [ ${#bad[@]} -eq 0 ] && check_pass "$n repos resolve to the guard hooks"
    check_fail "not covered: ${bad[*]}"
}
run
