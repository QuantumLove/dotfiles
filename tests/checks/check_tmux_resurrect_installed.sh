#!/usr/bin/env bash
# @id         tmux-resurrect-installed
# @desc       tmux-resurrect plugin present
# @severity   invariant
# @scope      container
# @tier       1
# Container scope: tpm installs resurrect inside the container; the host has tpm only.
# @boot_gate  no
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() {
    [ -d "$HOME/.tmux/plugins/tmux-resurrect" ] && check_pass "$HOME/.tmux/plugins/tmux-resurrect"
    check_fail "$HOME/.tmux/plugins/tmux-resurrect is missing"
}
run
