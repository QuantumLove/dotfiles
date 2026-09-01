#!/usr/bin/env bash
# @id         pins-documented
# @desc       Installed agent versions match their documented pins
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:grep
# @min_corpus 2
#
# This is what makes the fork deferral revisitable without anyone remembering
# it. The decision not to fork rests on running unmodified upstream releases; a
# patch applied ad hoc via /hot-patch would quietly falsify that while the
# vendored doc still said "local changes: none".
#
# Compares three places that must agree: the version in the vendored doc, the
# pin in the delivery mechanism, and — where the binary is present — what is
# actually installed. Two of the three agreeing is the interesting failure.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local src; src="$(chezmoi source-path 2>/dev/null)" || check_error "cannot resolve chezmoi source"
    local n=0 bad=()

    # --- omp: doc vs mise pin vs installed --------------------------------
    local doc_omp mise_omp
    doc_omp="$(grep -oE 'Version: \*\*[0-9][^*]*\*\*' "$src/docs/vendored/oh-my-pi.md" 2>/dev/null \
               | head -1 | sed -E 's/.*\*\*(.*)\*\*/\1/')"
    mise_omp="$(grep -oE '"github:can1357/oh-my-pi" = \{ version = "[^"]+"' \
               "$src/mega-container/dot_config/mise/config.toml" 2>/dev/null \
               | sed -E 's/.*version = "([^"]+)"/\1/')"
    n=$((n + 1))
    [ -n "$doc_omp" ] || bad+=("oh-my-pi:no-version-in-doc")
    [ -n "$mise_omp" ] || bad+=("oh-my-pi:no-mise-pin")
    [ -n "$doc_omp" ] && [ -n "$mise_omp" ] && [ "$doc_omp" != "$mise_omp" ] \
        && bad+=("oh-my-pi:doc=$doc_omp mise=$mise_omp")
    if command -v omp >/dev/null 2>&1; then
        local got; got="$(omp --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
        [ -n "$got" ] && [ "$got" != "$mise_omp" ] && bad+=("oh-my-pi:installed=$got pinned=$mise_omp")
    fi

    # --- omo: doc vs Dockerfile pin ---------------------------------------
    local doc_omo dockerfile_omo
    doc_omo="$(grep -oE 'Version: \*\*[0-9][^*]*\*\*' "$src/docs/vendored/oh-my-openagent.md" 2>/dev/null \
               | head -1 | sed -E 's/.*\*\*(.*)\*\*/\1/')"
    dockerfile_omo="$(grep -oE 'oh-my-openagent@[0-9][^ ]*' "$src/mega-container/Dockerfile" 2>/dev/null \
               | head -1 | cut -d@ -f2)"
    n=$((n + 1))
    [ -n "$doc_omo" ] || bad+=("oh-my-openagent:no-version-in-doc")
    [ -n "$dockerfile_omo" ] || bad+=("oh-my-openagent:not-pinned-in-Dockerfile")
    [ -n "$doc_omo" ] && [ -n "$dockerfile_omo" ] && [ "$doc_omo" != "$dockerfile_omo" ] \
        && bad+=("oh-my-openagent:doc=$doc_omo dockerfile=$dockerfile_omo")

    check_scanned "$n"
    [ ${#bad[@]} -eq 0 ] && check_pass "$n agent pins agree across doc and delivery"
    check_fail "${bad[*]}"
}
run
