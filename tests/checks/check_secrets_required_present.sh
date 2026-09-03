#!/usr/bin/env bash
# @id         secrets-required-present
# @desc       Every required secret is in the environment
# @severity   invariant
# @scope      container
# @tier       1
# @boot_gate  yes
# @min_corpus 7
#
# The required/optional split is U10's to define at the fetch sites; this check
# consumes it rather than restating it. Boot-gated: a container without its
# credentials is worse than a container that fails to start.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REQUIRED=(OP_SERVICE_ACCOUNT_TOKEN ANTHROPIC_API_KEY OPENAI_API_KEY
          GEMINI_API_KEY GH_TOKEN DD_API_KEY DD_APP_KEY)

run() {
    local missing=()
    for v in "${REQUIRED[@]}"; do
        [ -n "${!v:-}" ] || missing+=("$v")
    done
    check_scanned "${#REQUIRED[@]}"
    [ ${#missing[@]} -eq 0 ] && check_pass "${#REQUIRED[@]} required secrets present"
    check_fail "missing: ${missing[*]}"
}
run
