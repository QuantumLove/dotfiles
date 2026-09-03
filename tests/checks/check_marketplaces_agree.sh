#!/usr/bin/env bash
# @id         marketplaces-agree
# @desc       settings.json's marketplaces match the declared list
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:jq
# @min_corpus 3
#
# The list was declared in two places — the installer and
# settings.json's extraKnownMarketplaces. Both are now derived from
# marketplace-list.txt, and this asserts the settings half has not drifted:
# adding a marketplace to one file and not the other is exactly the silent
# divergence single-sourcing is meant to remove.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local src; src="$(chezmoi source-path 2>/dev/null)" || check_error "cannot resolve chezmoi source"
    local list="$src/private_dot_claude/marketplace-list.txt"
    local settings="$src/private_dot_claude/modify_settings.json"
    [ -r "$list" ] || check_error "missing $list"
    [ -r "$settings" ] || check_error "missing $settings"

    local declared configured
    declared="$(grep -vE '^[[:space:]]*(#|$)' "$list" | sort -u)"
    [ -n "$declared" ] || check_error "marketplace list is empty"
    check_scanned "$(printf '%s\n' "$declared" | grep -c .)"

    # The settings file is a bash script wrapping one JSON heredoc.
    configured="$(sed -n '/<</,/^JSON$/p' "$settings" \
        | sed '1d;$d' \
        | jq -r '.extraKnownMarketplaces // {} | to_entries[] | .value.source.repo' 2>/dev/null | sort -u)"
    [ -n "$configured" ] || check_error "could not read extraKnownMarketplaces"

    local only_declared only_configured
    only_declared="$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$configured") | tr '\n' ' ')"
    only_configured="$(comm -13 <(printf '%s\n' "$declared") <(printf '%s\n' "$configured") | tr '\n' ' ')"

    [ -z "${only_declared// /}" ] && [ -z "${only_configured// /}" ] \
        && check_pass "$(printf '%s\n' "$declared" | grep -c .) marketplaces agree"
    check_fail "list only: ${only_declared:-none} | settings only: ${only_configured:-none}"
}
run
