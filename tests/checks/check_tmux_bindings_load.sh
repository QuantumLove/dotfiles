#!/usr/bin/env bash
# @id         tmux-bindings-load
# @desc       Every key the config binds is actually registered
# @severity   invariant
# @scope      container
# @tier       2
# @boot_gate  no
# @input      cmd:tmux
# @min_corpus 10
#
# Asserts the binding LOADED, not that the config file contains a line. Two
# earlier fixes to this file both produced silently non-functional bindings: a
# message starting with `-` was parsed as a command flag so the bind never
# registered, and set-buffer stored a format string literally instead of
# expanding it. In both cases the config looked right and the key did nothing.
#
# This is also what catches a Glove80 layer key emitting a symbol nothing binds:
# the layer and the config have to change together, and a symbol with no binding
# fails silently at the tmux layer rather than erroring anywhere.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local src; src="$(chezmoi source-path 2>/dev/null)" || check_error "cannot resolve chezmoi source"
    local conf="$src/dot_tmux.conf"
    [ -r "$conf" ] || check_error "missing $conf"

    local registered; registered="$(tmux list-keys 2>/dev/null)" \
        || check_error "tmux list-keys failed — no server to ask"

    local declared=() key missing=()
    # Keys bound in the prefix table, however the bind line is spelled.
    while IFS= read -r key; do
        [ -n "$key" ] && declared+=("$key")
    done < <(grep -E '^bind(-key)?[[:space:]]' "$conf" \
             | sed -E 's/^bind(-key)?[[:space:]]+//; s/^-r[[:space:]]+//; s/^-T[[:space:]]+prefix[[:space:]]+//' \
             | awk '{print $1}' | tr -d "'\"" | sort -u)

    [ ${#declared[@]} -gt 0 ] || check_error "no bind lines found in $conf"
    check_scanned "${#declared[@]}"

    for key in "${declared[@]}"; do
        printf '%s\n' "$registered" | grep -qE "bind-key[^\n]*[[:space:]]${key//\\/\\\\}([[:space:]]|$)" \
            || missing+=("$key")
    done

    [ ${#missing[@]} -eq 0 ] && check_pass "${#declared[@]} bindings registered"
    check_fail "declared but not registered: ${missing[*]}"
}
run
