#!/usr/bin/env bash
# @id         omo-agent-models
# @desc       Every omo agent and category resolves to its declared model
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  yes
# @input      file:{{HOME}}/.omo/omo.jsonc
# @input      cmd:jq
# @input      cmd:chezmoi
# @min_corpus 15

# Expected values come from the chezmoi SOURCE; actual from the APPLIED file.
# Reading both sides from the applied file would be circular: omo regenerates
# its own defaults there, and a check comparing each agent's model against
# itself passes while every value is wrong — which is how the original
# misconfiguration survived three rounds of fixes.
#
# Enumerates rather than spot-checking named keys. Spot-checking is why the
# earlier fixes each closed one gap and missed the next: sisyphus was checked,
# oracle and metis were not.
#
# Only `.model` leaves are compared, so `_migrations` — which omo writes itself
# — is naturally out of scope rather than needing an exception.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

APPLIED="$HOME/.omo/omo.jsonc"

strip_comments() { sed 's|^[[:space:]]*//.*$||'; }

# path<TAB>model, one per line, sorted — for both sides.
model_pairs() { # reads jsonc on stdin
    strip_comments | jq -r '
        paths(scalars) as $p
        | select($p[-1] == "model")
        | [($p | map(tostring) | join(".")), getpath($p)]
        | @tsv
    ' 2>/dev/null | sort
}

run() {
    local src_json expected actual
    src_json="$(chezmoi cat "$APPLIED" 2>/dev/null)" \
        || check_error "chezmoi cat failed for $APPLIED"
    [ -n "$src_json" ] || check_error "chezmoi source for $APPLIED is empty"

    expected="$(printf '%s' "$src_json" | model_pairs)"
    [ -n "$expected" ] || check_error "no model entries found in the chezmoi source"

    actual="$(model_pairs < "$APPLIED")"
    [ -n "$actual" ] || check_error "no model entries found in $APPLIED (unparseable?)"

    check_scanned "$(printf '%s\n' "$expected" | grep -c .)"

    if [ "$expected" = "$actual" ]; then
        check_pass "$(printf '%s\n' "$expected" | grep -c .) models match the source"
    fi

    # Report the first few differences rather than a bare "differs".
    local diff_out
    diff_out="$(diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") \
                | grep -E '^[<>]' | head -4 | tr '\n' ' ')"
    check_fail "applied models differ from source: ${diff_out}"
}
run
