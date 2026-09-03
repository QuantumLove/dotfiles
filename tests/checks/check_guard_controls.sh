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

    # --- edit mode -------------------------------------------------------
    # Commit mode passing says nothing about edit mode: they share a policy file
    # but not a code path, and the agent adapters only ever call edit.
    local repo="$tmp/plain"
    git -C "$repo" checkout -q main
    printf 'x\n' > "$repo/tracked.txt"
    printf 'ignored/\n' > "$repo/.gitignore"
    mkdir -p "$repo/ignored"
    git -C "$repo" add tracked.txt .gitignore
    git -C "$repo" -c user.email=a@b -c user.name=t -c commit.gpgsign=false \
        commit -q -m tracked

    "$GUARD" edit --path "$repo/tracked.txt" >/dev/null 2>&1 \
        && check_fail "edit positive control: a tracked file in the primary checkout was allowed"

    # Untracked and ignored paths must stay writable. Blocking them buys nothing
    # — they cannot reach a commit unless someone adds them, which the commit
    # hook covers — and it makes the guard something to route around.
    "$GUARD" edit --path "$repo/untracked.txt" >/dev/null 2>&1 \
        || check_fail "edit negative control: an untracked scratch file was denied"
    "$GUARD" edit --path "$repo/ignored/x.txt" >/dev/null 2>&1 \
        || check_fail "edit negative control: a gitignored path was denied"

    # Agents address their own tools with pseudo-paths (omp uses xd://<tool>).
    # Those are not files, and treating them as repo writes breaks tool calls.
    ( cd "$repo" && "$GUARD" edit --path "xd://cd" >/dev/null 2>&1 ) \
        || check_fail "edit negative control: a non-filesystem tool pseudo-path was denied"

    # A relative path must resolve against the caller's directory, not the repo
    # root, or the guard inspects the wrong file from any subdirectory.
    mkdir -p "$repo/sub"
    ( cd "$repo/sub" && "$GUARD" edit --path "../tracked.txt" >/dev/null 2>&1 ) \
        && check_fail "edit control: a relative path to a tracked file was allowed"

    check_scanned 8
    check_pass "deny, allow and except all behave, in commit and edit mode"
}
run
