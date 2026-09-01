#!/usr/bin/env bash
# @id         branch-divergence
# @desc       No protected branch has drifted from its remote
# @severity   liveness
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:git
# @min_corpus 2
#
# The backstop for everything the hooks cannot see. Ahead catches merge, rebase,
# cherry-pick and --no-verify, none of which fire pre-commit. Behind catches a
# remote-side write: a gh api or MCP commit adds to the remote, so the local
# branch loses ground rather than gaining it — an ahead-only check reports zero
# for exactly the hole that is knowingly accepted.
#
# Exempt repos are excluded: rule 4 exempts them, and the chezmoi
# commit-then-push cycle would otherwise fire this every day.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local pol="${GIT_GUARD_POLICY:-$HOME/.config/git-guard/policy.json}"
    local exempt; exempt="$(jq -r '.exempt_remotes[]?' "$pol" 2>/dev/null | tr 'A-Z' 'a-z')"
    local n=0 drift=() stale=()

    while IFS= read -r r; do
        [ -n "$r" ] || continue
        local url slug; url="$(git -C "$r" remote get-url origin 2>/dev/null || echo "")"
        [ -n "$url" ] || continue
        slug="$(printf '%s' "${url%.git}" | tr 'A-Z' 'a-z')"
        printf '%s\n' "$exempt" | while read -r e; do [ -n "$e" ] && case "$slug" in *"$e") exit 9;; esac; done
        [ $? -eq 9 ] && continue

        local def; def="$(git -C "$r" symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null || echo "")"
        [ -n "$def" ] || continue
        def="${def#origin/}"
        git -C "$r" rev-parse --verify -q "refs/heads/$def" >/dev/null 2>&1 || continue
        n=$((n + 1))

        local counts ahead behind
        counts="$(git -C "$r" rev-list --left-right --count "refs/heads/$def...refs/remotes/origin/$def" 2>/dev/null)" || continue
        ahead="$(printf '%s' "$counts" | awk '{print $1}')"
        behind="$(printf '%s' "$counts" | awk '{print $2}')"
        [ "${ahead:-0}" -gt 0 ] && drift+=("$(basename "$r"):+$ahead")
        [ "${behind:-0}" -gt 0 ] && stale+=("$(basename "$r"):-$behind")
    done < <(repo_corpus)

    check_scanned "$n"
    [ ${#drift[@]} -eq 0 ] \
        && check_pass "$n protected branches, none ahead${stale:+ (behind, not pulled: ${stale[*]})}"
    check_fail "local commits not on the remote: ${drift[*]}"
}
run
