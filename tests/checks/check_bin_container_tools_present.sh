#!/usr/bin/env bash
# @id         bin-container-tools-present
# @desc       Container-only tooling is on PATH
# @severity   invariant
# @scope      container
# @tier       1
# @boot_gate  no
# @input      cmd:command
# @min_corpus 14
#
# Not boot-gated: a missing tflint should not stop the container starting.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TOOLS=(opencode tmux helm gh pulumi docker aws kubectl tflint gitleaks age sops bun tailscale)

run() {
    local missing=()
    for b in "${TOOLS[@]}"; do
        command -v "$b" >/dev/null 2>&1 || missing+=("$b")
    done
    check_scanned "${#TOOLS[@]}"
    [ ${#missing[@]} -eq 0 ] && check_pass "${#TOOLS[@]} container tools present"
    check_fail "missing: ${missing[*]}"
}
run
