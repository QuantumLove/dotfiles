#!/usr/bin/env bash
# @id         guard-controls
# @desc       The guard denies, allows, and excepts correctly
# @severity   invariant
# @scope      both
# @tier       2
# @boot_gate  no
# @input      file:{{HOME}}/.local/bin/git-main-guard
# @input      cmd:git
#
# A positive control alone proves nothing: a hook that errors and blocks
# everything passes it. All three run, in throwaway repos with synthetic
# remotes, so the verdict measures policy rather than the state of any real repo.
#
# Tier 2 rather than 3: it does exercise the engine end to end, but hermetically
# — no network, no model, no live state, well under a second. Tier 3 gating
# exists to keep expensive checks off the schedule, and this is the check most
# worth running often.
#
# Signing is forced off. This repo signs every commit through the 1Password
# agent, and a signing failure would otherwise be indistinguishable from a
# guard verdict.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GUARD="$HOME/.local/bin/git-main-guard"

mkrepo() { # <dir> <remote-url>
    local d="$1" url="$2"
    mkdir -p "$d"
    git -C "$d" init -q -b main
    git -C "$d" -c user.email=a@b -c user.name=t -c commit.gpgsign=false \
        commit -q --allow-empty -m init
    git -C "$d" remote add origin "$url"
    git -C "$d" update-ref refs/remotes/origin/main HEAD
    git -C "$d" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
}

run() {
    guard_enforcement_active \
        || check_skip "enforcement_active is false — engine not applied yet"

    local tmp; tmp="$(mktemp -d)" || check_error "could not create a scratch dir"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" EXIT

    mkrepo "$tmp/plain"  "git@github.com:example/not-exempt.git" 2>/dev/null \
        || check_error "could not build a scratch repo"
    mkrepo "$tmp/exempt" "git@github.com:QuantumLove/dotfiles.git" 2>/dev/null

    # positive: default branch in a non-exempt repo must be denied
    "$GUARD" commit --cwd "$tmp/plain" >/dev/null 2>&1 \
        && check_fail "positive control: a commit on the default branch was allowed"

    # negative: a feature branch must be allowed. Catches a guard that denies
    # unconditionally, which a positive control alone would score as healthy.
    git -C "$tmp/plain" checkout -q -b feature
    "$GUARD" commit --cwd "$tmp/plain" >/dev/null 2>&1 \
        || check_fail "negative control: a commit on a feature branch was denied"

    # exception: an exempt slug must be allowed, at any path
    "$GUARD" commit --cwd "$tmp/exempt" >/dev/null 2>&1 \
        || check_fail "exception control: an exempt repo was denied"

    check_scanned 3
    check_pass "deny, allow and except all behave"
}
run
