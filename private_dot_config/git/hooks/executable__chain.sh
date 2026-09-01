#!/usr/bin/env bash
# Run the repo's own hook of the same name, if it has one.
#
# A global core.hooksPath replaces a repo's .git/hooks entirely — every hook,
# not just the ones we ship. Without chaining, the first work repo using husky
# or the pre-commit framework loses its hooks silently, and the symptom shows up
# in CI rather than locally.
#
# Usage:  chain_repo_hook <hook-name> [args...]   (stdin is forwarded)
set -uo pipefail

chain_repo_hook() {
    local name="${1:?hook name required}"; shift
    local guard_dir repo_hook husky_hook common

    # --git-common-dir, NOT --git-path hooks: under a global core.hooksPath the
    # latter returns the guard directory itself, so the hook would exec itself
    # forever.
    common="$(git rev-parse --git-common-dir 2>/dev/null || echo "")"
    [ -n "$common" ] || return 0
    case "$common" in /*) ;; *) common="$PWD/$common" ;; esac

    guard_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

    for repo_hook in "$common/hooks/$name" "$PWD/.husky/$name"; do
        [ -x "$repo_hook" ] || continue
        # Never exec something inside our own directory — that is the recursion.
        case "$(cd "$(dirname "$repo_hook")" && pwd -P)" in
            "$guard_dir") continue ;;
        esac
        "$repo_hook" "$@"
        return $?
    done
    return 0
}
