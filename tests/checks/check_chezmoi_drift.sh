#!/usr/bin/env bash
# @id         chezmoi-drift
# @desc       Applied config matches its chezmoi source
# @severity   liveness
# @scope      both
# @tier       2
# @boot_gate  no
# @input      cmd:chezmoi
# @min_corpus 1
#
# Liveness, and never boot-gated. Runtime-owned files legitimately diverge:
# omp and omo rewrite their own config, and failing on that would go red every
# time a model is switched. Alarm fatigue is how the previous assertion layer
# died.
#
# Built on `chezmoi verify`, not a hand-rolled walk — chezmoi already knows
# which files are ignored on this machine and how each template renders, so a
# hand-rolled comparison would report phantom drift in the container.
#
# 1Password is required to render some templates. A locked vault is not drift,
# so it skips with a reason: the one sanctioned skip-not-error case, because
# treating it as an error would make an unrelated outage look like a config
# problem.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Files a tool owns at runtime. Whole-file equality is the wrong question for
# these — each is rewritten by the thing that uses it, by design:
#
#   .omo/omo.jsonc          omo regenerates its own defaults
#   .omp/agent/config.yml   omp writes on `omp config set`, /settings, /model
#   .claude.json            Claude Code rewrites it continuously
#   .claude/settings.json   a modify_ target for exactly this reason
#   .aws/config             aws-sso-login adds the -device profile variants
#   .bash_profile           the entrypoint re-patches the secrets sourcing line
#
# The invariants that matter inside them are asserted separately and by key —
# omo-agent-models is the model-value case. Listing a file here says "do not ask
# whether it is byte-identical", not "do not check it".
RUNTIME_OWNED=(".omo/omo.jsonc" ".omp/agent/config.yml" ".claude.json"
               ".claude/settings.json" ".aws/config" ".bash_profile")

run() {
    command -v op >/dev/null 2>&1 && ! op account get >/dev/null 2>&1 \
        && check_skip "1Password unavailable — templates cannot render"

    # `chezmoi status`, not `chezmoi verify`: verify exits non-zero and prints
    # NOTHING, so parsing its output yields an empty list and a false pass —
    # the precise shape this suite exists to catch. Caught by not believing a
    # pass that arrived too easily.
    local out; out="$(chezmoi status 2>/dev/null)" \
        || check_error "chezmoi status failed"

    # Column 1 is the drift signal: the applied file changed since chezmoi last
    # wrote it. Column 2 only means an apply is pending, which is ordinary while
    # source edits are in flight and says nothing about anything having drifted.
    local drift=() pending=0 line external f owned r
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        external="${line:0:1}"
        f="${line:3}"
        case "$external" in
            M|D) ;;
            *) pending=$((pending + 1)); continue ;;
        esac
        owned=0
        for r in "${RUNTIME_OWNED[@]}"; do [ "$f" = "$r" ] && owned=1; done
        [ "$owned" -eq 1 ] || drift+=("$f")
    done <<< "$out"

    check_scanned "$(printf '%s\n' "$out" | grep -c .)"
    [ ${#drift[@]} -eq 0 ] \
        && check_pass "no unexplained drift${pending:+ ($pending source edit(s) not yet applied)}"
    check_fail "applied files changed outside chezmoi: ${drift[*]}"
}
run
