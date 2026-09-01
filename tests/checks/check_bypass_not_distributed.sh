#!/usr/bin/env bash
# @id         bypass-not-distributed
# @desc       No config, skill, command or memory hands out a guard bypass
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:grep
# @min_corpus 40
#
# Both sanctioned escape hatches are here, not just --no-verify:
# MEGA_ASSERT_BYPASS is an environment variable, and the places it would become
# permanent — a compose file, an entrypoint, a shell rc — are exactly the ones
# nobody rereads.
#
# Matches command-shaped usage, not mentions. `--no-verify is the escape hatch`
# in a rules document is documentation; `git commit --no-verify` in a skill is
# distribution. Requiring `git` on the same line separates them without needing
# an allow-list to maintain.
#
# Agent memory under ~/.claude/projects/*/memory/ is scanned too. It is
# runtime-generated and outside the chezmoi source tree — the one deliberate
# exception to resolving the corpus from source — because a learned "just use
# -n here" is precisely what this is looking for.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    local src hits=() n=0
    src="$(chezmoi source-path 2>/dev/null)" || src=""
    [ -n "$src" ] || check_error "cannot resolve the chezmoi source path"

    local -a roots=(
        "$src/private_dot_claude"
        "$src/private_dot_config"
        "$src/mega-container"
        "$HOME/.claude/projects"
    )

    for root in "${roots[@]}"; do
        [ -d "$root" ] || continue
        while IFS= read -r f; do
            n=$((n + 1))
            # git-command-shaped bypass, or an env assignment that makes it stick
            grep -nE '(git[^|;&]*--no-verify)|(git (commit|push)[^|;&]*[[:space:]]-n[[:space:]])|(MEGA_ASSERT_BYPASS=)' "$f" 2>/dev/null \
                | grep -vE '^\s*[0-9]+:\s*#' \
                | while IFS= read -r hit; do printf '%s:%s\n' "${f#"$src"/}" "${hit%%:*}"; done
        done < <(find "$root" -type f \( -name '*.md' -o -name '*.tmpl' -o -name '*.json' -o -name '*.sh' -o -name '*.yaml' -o -name '*.yml' \) 2>/dev/null)
    done > /tmp/.bypass-scan-$$ 2>/dev/null

    mapfile -t hits < /tmp/.bypass-scan-$$ 2>/dev/null || hits=()
    rm -f /tmp/.bypass-scan-$$
    check_scanned "$n"

    [ ${#hits[@]} -eq 0 ] && check_pass "scanned $n files, no bypass distributed"
    check_fail "bypass handed out in: ${hits[*]}"
}
run
