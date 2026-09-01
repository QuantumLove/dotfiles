#!/usr/bin/env bash
# Unit tests for the git-main-guard policy engine.
# Hermetic: builds throwaway repos in $TMPDIR with synthetic remotes and a
# temp policy file. Never reads the real policy, never touches a real repo,
# and never changes the host's git config.
#
# Run:  bash tests/bin/test_git_main_guard.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$REPO_ROOT/private_dot_local/bin/executable_git-main-guard"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME"

# Safety net: `git -C ""` is a no-op, so an empty path variable would run git
# against the caller's working directory — i.e. this repo. Work from $TMP so a
# stray invocation lands somewhere disposable, and validate paths besides.
cd "$TMP" || exit 1

POLICY="$TMP/policy.json"
cat > "$POLICY" <<'JSON'
{ "exempt_remotes": ["QuantumLove/dotfiles", "QuantumLove/glove80"] }
JSON

pass=0 fail=0

# repo <path> — refuse to hand git an empty or missing path
repo() {
    [ -n "${1:-}" ] && [ -d "$1" ] || { echo "FATAL: bad repo path '${1:-}'" >&2; exit 1; }
    printf '%s' "$1"
}

# mkrepo <name> <remote-url> [default-branch]
mkrepo() {
    # Separate statements on purpose: `local a=$1 b="$x/$a"` declares every name
    # before assigning, so `$a` is an unset local when `$b` is computed and
    # `set -u` kills the subshell.
    local name="${1:?mkrepo needs a name}"
    local url="${2:-}"
    local def="${3:-main}"
    local d="$TMP/$name"
    mkdir -p "$d"; git -C "$d" init -q -b "$def" 2>/dev/null
    git -C "$d" -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
        commit -q --allow-empty -m init 2>/dev/null
    if [ -n "$url" ]; then
        git -C "$d" remote add origin "$url"
        # Synthesize the remote-tracking ref the guard derives the default from.
        git -C "$d" update-ref "refs/remotes/origin/$def" HEAD
        git -C "$d" symbolic-ref "refs/remotes/origin/HEAD" "refs/remotes/origin/$def"
    fi
    [ -d "$d" ] || { echo "FATAL: mkrepo failed for $name" >&2; exit 1; }
    printf '%s' "$d"
}

# assert <name> <expected_exit> <mode> <args...>
assert() {
    local name="$1" expected="$2"; shift 2
    local out rc
    out="$(GIT_GUARD_POLICY="$POLICY" bash "$GUARD" "$@" 2>&1)"; rc=$?
    if [ "$rc" = "$expected" ]; then
        printf '  ok    %-52s (exit %s)\n' "$name" "$rc"; pass=$((pass+1))
    else
        printf '  FAIL  %-52s expected %s got %s\n' "$name" "$expected" "$rc"
        printf '%s\n' "$out" | sed 's/^/          /'; fail=$((fail+1))
    fi
}

echo "git-main-guard policy engine"

# --- identity is a remote slug, not a path (R9 / AE6) -----------------------
r="$(mkrepo relocated-chezmoi git@github.com:QuantumLove/dotfiles.git)"
assert "exempt repo at a non-canonical path is allowed" 0 \
    checkout --command "git checkout -b feature" --cwd "$r"

r="$(mkrepo work-repo git@github.com:metr/some-service.git)"
assert "non-exempt repo blocks a branch switch off default" 2 \
    checkout --command "git checkout -b feature" --cwd "$r"

r="$(mkrepo https-form https://github.com/QuantumLove/glove80)"
assert "exempt match works for the https remote form" 0 \
    checkout --command "git switch -c feature" --cwd "$r"

# --- default branch is derived, not hardcoded (R15 / AE9) -------------------
r="$(mkrepo trunk-repo git@github.com:metr/trunk-svc.git trunk)"
assert "a repo whose default is 'trunk' is guarded on trunk" 2 \
    checkout --command "git checkout -b feature" --cwd "$r"

r="$(mkrepo already-off git@github.com:metr/off-svc.git)"
git -C "$(repo "$r")" checkout -q -b existing-feature
assert "already off the default branch allows recovery" 0 \
    checkout --command "git checkout -b another" --cwd "$r"

# --- detached HEAD must not disarm the guard (R14 / AE8) --------------------
r="$(mkrepo detached git@github.com:metr/det-svc.git)"
git -C "$(repo "$r")" checkout -q --detach HEAD
assert "detached HEAD is still evaluated, not waved through" 2 \
    checkout --command "git checkout -b feature" --cwd "$r"

# --- fail open where identity is unknowable (R33) ---------------------------
r="$(mkrepo no-remote "")"
assert "a repo with no remote is unguarded" 0 \
    checkout --command "git checkout -b feature" --cwd "$r"

r="$(mkrepo no-head git@github.com:metr/nohead.git)"
git -C "$(repo "$r")" symbolic-ref -d refs/remotes/origin/HEAD 2>/dev/null
assert "underivable default branch allows and logs" 0 \
    checkout --command "git checkout -b feature" --cwd "$r"

# --- policy file is load-bearing --------------------------------------------
r="$(mkrepo policyless git@github.com:metr/svc.git)"
out="$(GIT_GUARD_POLICY="$TMP/nope.json" bash "$GUARD" \
        checkout --command "git checkout -b f" --cwd "$r" 2>&1)"; rc=$?
if [ "$rc" = 3 ]; then
    printf '  ok    %-52s (exit 3)\n' "missing policy is distinct from allow"; pass=$((pass+1))
else
    printf '  FAIL  %-52s expected 3 got %s\n' "missing policy is distinct from allow" "$rc"; fail=$((fail+1))
fi

# --- retired bypass ----------------------------------------------------------
r="$(mkrepo bypass-attempt git@github.com:metr/svc2.git)"
out="$(GIT_GUARD_POLICY="$POLICY" ALLOW_MAIN_EDITS=1 bash "$GUARD" \
        checkout --command "git checkout -b f" --cwd "$r" 2>&1)"; rc=$?
if [ "$rc" = 2 ]; then
    printf '  ok    %-52s (exit 2)\n' "ALLOW_MAIN_EDITS no longer bypasses"; pass=$((pass+1))
else
    printf '  FAIL  %-52s expected 2 got %s\n' "ALLOW_MAIN_EDITS no longer bypasses" "$rc"; fail=$((fail+1))
fi

# --- edit mode: tracked vs gitignored in the primary worktree ---------------
r="$(mkrepo edit-repo git@github.com:metr/svc3.git)"
printf 'tracked\n' > "$r/tracked.txt"
printf '.omo/\nscratch.log\n' > "$r/.gitignore"
git -C "$(repo "$r")" add tracked.txt .gitignore
git -C "$(repo "$r")" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m add
assert "editing a tracked file in the primary worktree blocks" 2 \
    edit --path "$r/tracked.txt"
assert "a gitignored scratch file stays writable" 0 \
    edit --path "$r/scratch.log"

r="$(mkrepo edit-exempt git@github.com:QuantumLove/dotfiles.git)"
printf 'x\n' > "$r/f.txt"
git -C "$(repo "$r")" add f.txt
git -C "$(repo "$r")" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m add
assert "editing a tracked file in an exempt repo is allowed" 0 \
    edit --path "$r/f.txt"

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
