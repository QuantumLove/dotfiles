#!/usr/bin/env bash
# @id         mise-shims-resolve
# @desc       Every load-bearing mise shim resolves to an installed binary
# @severity   invariant
# @scope      container
# @tier       1
# @boot_gate  yes
# @input      cmd:mise
# @min_corpus 7
#
# bin-core-present and bin-container-tools-present both ask `command -v`, which
# answers yes for a mise shim whose config no longer pins a version: the shim
# file is still there and still executable, it just errors when run. That is how
# a container whose entire toolchain had been replaced still passed its boot
# gate — every symptom (opencode, omp, tt) was downstream of shims that existed
# but could not resolve.
#
# mise-tools-match-pins does not cover this either: it asks what is missing
# relative to the config, so emptying the config makes it pass. This asks the
# opposite question — are the tools we actually depend on reachable — and so
# holds whatever the cause: clobbered config, failed install, or mise upgrade.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The shims whose failure takes down a surface: the agents, the tmux focus hook,
# and the two runtimes the npm-global agents are shimmed onto.
SHIMS=(node python opencode omp omo tt uv)

run() {
    local broken=()
    for s in "${SHIMS[@]}"; do
        mise which "$s" >/dev/null 2>&1 || broken+=("$s")
    done
    check_scanned "${#SHIMS[@]}"
    [ ${#broken[@]} -eq 0 ] && check_pass "${#SHIMS[@]} shims resolve"
    check_fail "shim present but unresolvable: ${broken[*]}"
}
run
