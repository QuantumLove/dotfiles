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

    local raw
    raw="$(tmux list-keys -T prefix 2>/dev/null)" || check_error "tmux list-keys failed"
    [ -n "$raw" ] || check_error "tmux reported no prefix bindings"

    # Two things make the key column awkward to read:
    #   -r (repeat) bindings insert a field, shifting the key one to the right
    #   tmux escapes \\ and prefixes " # $ % ' ; { } ~ with a backslash
    # Strip the command prefix by pattern rather than counting fields, then
    # unescape, so a bound key is never reported missing.
    local registered=""
    while IFS= read -r line; do
        local rest key
        rest="${line#bind-key}"
        rest="${rest#"${rest%%[![:space:]]*}"}"          # ltrim
        rest="${rest#-r}"; rest="${rest#"${rest%%[![:space:]]*}"}"
        rest="${rest#-T}"; rest="${rest#"${rest%%[![:space:]]*}"}"
        rest="${rest#prefix}"; rest="${rest#"${rest%%[![:space:]]*}"}"
        key="${rest%%[[:space:]]*}"
        case "$key" in
            '\\\\') key='\' ;;                           # escaped backslash
            '\'?)   key="${key#\\}" ;;                   # \" \# \$ \% \' \; \{ \} \~
        esac
        [ -n "$key" ] && registered+="$key"$'\n'
    done <<< "$raw"
    registered="$(printf '%s' "$registered" | sort -u)"

    local declared
    declared="$(grep -E '^bind(-key)?[[:space:]]' "$conf" \
             | sed -E 's/^bind(-key)?[[:space:]]+//; s/^-r[[:space:]]+//; s/^-T[[:space:]]+prefix[[:space:]]+//' \
             | awk '{print $1}' | sed "s/^'\(.*\)'$/\1/" | tr -d '"' | sort -u)"
    [ -n "$declared" ] || check_error "no bind lines found in $conf"

    local n; n="$(printf '%s\n' "$declared" | grep -c .)"
    check_scanned "$n"

    local missing; missing="$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$registered") | tr '\n' ' ')"
    [ -z "${missing// /}" ] && check_pass "$n bindings registered"
    check_fail "declared but not registered: $missing"
}
run
