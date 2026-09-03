#!/usr/bin/env bash
# @id         omp-agent-models
# @desc       Every omp agent and role resolves to a declared model
# @severity   invariant
# @scope      container
# @tier       2
# @boot_gate  no
# @input      file:{{HOME}}/.omp/agent/config.yml
# @input      cmd:yq
# @input      cmd:chezmoi
# @min_corpus 15
#
# Same shape as the omo check and for the same reason: expected values come from
# the chezmoi source, actual from the applied file. Reading both sides from the
# applied file would compare each value against itself and pass while every one
# was wrong.
#
# Additionally asserts EXHAUSTIVENESS over the agents omp ships with. An agent
# absent from agentModelOverrides and without a frontmatter model silently
# inherits the parent's active model — which is not a declaration, and is
# precisely how the omo drift stayed invisible: the agents nobody thought to
# check were the ones that were wrong.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

APPLIED="$HOME/.omp/agent/config.yml"

# The agents omp ships with. Each must resolve to something declared.
BUNDLED=(scout designer reviewer security-reviewer librarian task sonic)

pairs() { yq -r '
    (.modelRoles // {} | to_entries | map("role." + .key + "\t" + .value)) +
    (.task.agentModelOverrides // {} | to_entries | map("agent." + .key + "\t" + .value))
    | .[]' 2>/dev/null | sort; }

run() {
    local src_yaml expected actual
    src_yaml="$(chezmoi cat "$APPLIED" 2>/dev/null)" || check_error "chezmoi cat failed for $APPLIED"
    [ -n "$src_yaml" ] || check_error "chezmoi source for $APPLIED is empty"

    expected="$(printf '%s' "$src_yaml" | pairs)"
    [ -n "$expected" ] || check_error "no model declarations found in the source"
    actual="$(pairs < "$APPLIED")"
    [ -n "$actual" ] || check_error "no model declarations found in $APPLIED"

    check_scanned "$(printf '%s\n' "$expected" | grep -c .)"

    # Exhaustiveness first: a missing declaration is worse than a wrong one,
    # because nothing reports it at runtime.
    local undeclared=()
    for a in "${BUNDLED[@]}"; do
        printf '%s\n' "$expected" | grep -q "^agent\.$a	" || undeclared+=("$a")
    done
    [ ${#undeclared[@]} -eq 0 ] || check_fail "bundled agents with no declared model: ${undeclared[*]}"

    # `tiny` drives titles and memory on every turn and falls through to @smol
    # when unset — cheap to forget, and it spends money quietly.
    printf '%s\n' "$expected" | grep -q '^role\.tiny	' || check_fail "the tiny role is not declared"

    [ "$expected" = "$actual" ] \
        && check_pass "$(printf '%s\n' "$expected" | grep -c .) declarations match the source"

    local d; d="$(diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | grep -E '^[<>]' | head -4 | tr '\n' ' ')"
    check_fail "applied config differs from source: $d"
}
run
