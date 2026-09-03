#!/usr/bin/env bash
# @id         adapters-live
# @desc       Each harness's guard adapter is installed and parses
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:git
# @min_corpus 1
#
# Rule 1 has no git hook, so it needs one adapter per agent surface. An adapter
# that stops loading after a harness upgrade is assertion decay on the
# enforcement side — the guard reports nothing and blocks nothing.
#
# Tier 2 on purpose: presence, registration and parse only. Actually driving a
# block verdict needs a model turn, which is tier 3 and belongs on demand, not
# on a schedule that would start three agent runtimes on a loop. The omp adapter
# is U26 and is expected absent until then.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    guard_enforcement_active \
        || check_skip "enforcement_active is false — adapters not applied yet"

    local pol="${GIT_GUARD_POLICY:-$HOME/.config/git-guard/policy.json}"
    local n=0 broken=() surface path
    while IFS= read -r surface; do
        [ -n "$surface" ] || continue
        n=$((n + 1))
        case "$surface" in
            claude)   path="$HOME/.claude/hooks/guard-no-main-edits.sh" ;;
            opencode) path="$HOME/.config/opencode/plugins/guard-main/index.ts" ;;
            omp)      path="$HOME/.omp/agent/extensions/guard-main.ts" ;;
            *)        broken+=("$surface:unknown-surface"); continue ;;
        esac
        [ -f "$path" ] || { broken+=("$surface:absent"); continue; }
        case "$path" in
            *.sh) bash -n "$path" 2>/dev/null || broken+=("$surface:parse-error") ;;
        esac
    done < <(jq -r '.enforced_surfaces[]?' "$pol" 2>/dev/null)
    [ "$n" -gt 0 ] || check_error "policy declares no enforced surfaces"

    check_scanned "$n"
    [ ${#broken[@]} -eq 0 ] && check_pass "$n adapters present and parsing"
    check_fail "${broken[*]}"
}
run
