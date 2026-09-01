#!/usr/bin/env bash
# @id         claude-plugins-match-declaration
# @desc       Every declared Claude plugin is installed
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      file:{{HOME}}/.claude/plugin-list.txt
# @input      cmd:claude
# @min_corpus 5
#
# The old check counted installed plugins and warned when the count was zero —
# so a declaration of eight with one installed passed. Enumerate instead.
#
# A declared plugin that is missing fails: something we asked for is absent.
# An installed plugin that is not declared is reported but does not fail — that
# is a deliberate ad-hoc install, not a broken environment.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local decl_file="$HOME/.claude/plugin-list.txt" declared installed missing extra
    declared="$(grep -vE '^[[:space:]]*(#|$)' "$decl_file" | sort -u)"
    [ -n "$declared" ] && check_scanned "$(printf '%s\n' "$declared" | grep -c .)" \
        || check_error "no plugins declared in $decl_file"

    installed="$(claude plugin list 2>/dev/null | sed -n -E 's/^[[:space:]]*❯[[:space:]]+//p' | sort -u)"
    [ -n "$installed" ] || check_error "claude plugin list returned nothing"

    missing="$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$installed") | tr '\n' ' ')"
    extra="$(comm -13 <(printf '%s\n' "$declared") <(printf '%s\n' "$installed") | tr '\n' ' ')"

    [ -n "${missing// /}" ] && check_fail "declared but not installed: $missing"
    check_pass "all declared plugins installed${extra:+ (also installed, undeclared: $extra)}"
}
run
