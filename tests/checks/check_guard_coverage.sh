#!/usr/bin/env bash
# @id         guard-coverage
# @desc       No repo is silently unguarded
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:git
# @input      cmd:jq
# @min_corpus 2
#
# Fail-open is defensible only while it is monitored. A repo whose slug will not
# parse, or whose default branch cannot be derived, is allowed forever and the
# only trace is a log line — the same "unverified quietly becomes verified"
# shape the whole suite exists to prevent, reproduced in the guard itself.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local pol="${GIT_GUARD_POLICY:-$HOME/.config/git-guard/policy.json}"
    local exempt; exempt="$(jq -r '.exempt_remotes[]?' "$pol" 2>/dev/null | tr 'A-Z' 'a-z')"
    local n=0 uncovered=()
    while IFS= read -r r; do
        [ -n "$r" ] || continue
        n=$((n + 1))
        local url slug skip=0
        url="$(git -C "$r" remote get-url origin 2>/dev/null || echo "")"
        [ -n "$url" ] || continue                     # no remote: nothing to protect
        slug="$(printf '%s' "${url%.git}" | tr 'A-Z' 'a-z')"
        while IFS= read -r e; do
            [ -n "$e" ] || continue
            case "$slug" in *"$e") skip=1 ;; esac
        done <<< "$exempt"
        # An exempt repo is allowed regardless of its default branch, so an
        # underivable one there is not an unguarded repo.
        [ "$skip" -eq 1 ] && continue
        git -C "$r" symbolic-ref -q refs/remotes/origin/HEAD >/dev/null 2>&1 \
            || uncovered+=("$(basename "$r"):no-origin-HEAD")
    done < <(repo_corpus)

    check_scanned "$n"
    [ ${#uncovered[@]} -eq 0 ] && check_pass "$n repos identifiable"
    check_fail "would fail open — run 'git remote set-head origin -a' in: ${uncovered[*]}"
}
run
