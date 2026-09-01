#!/usr/bin/env bash
# Tests for the pre-commit / pre-push guard hooks.
# Hermetic: assembles a hook directory from source into $TMPDIR and points each
# scratch repo at it with a REPO-LOCAL core.hooksPath. The host's global git
# config is never read or written.
#
# Run:  bash tests/hooks/test_git_hooks.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/private_dot_config/git/hooks"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
export HOME="$TMP/home"; mkdir -p "$HOME/.local/bin"

# The hooks call $HOME/.local/bin/git-main-guard by absolute path.
cp "$REPO_ROOT/private_dot_local/bin/executable_git-main-guard" "$HOME/.local/bin/git-main-guard"
chmod +x "$HOME/.local/bin/git-main-guard"

HOOKS="$TMP/hooks"; mkdir -p "$HOOKS"
cp "$SRC/executable__chain.sh"   "$HOOKS/_chain.sh"
cp "$SRC/executable_pre-commit"  "$HOOKS/pre-commit"
cp "$SRC/executable_pre-push"    "$HOOKS/pre-push"
chmod +x "$HOOKS"/*

export GIT_GUARD_POLICY="$TMP/policy.json"
cat > "$GIT_GUARD_POLICY" <<'JSON'
{ "exempt_remotes": ["QuantumLove/dotfiles"] }
JSON

pass=0 fail=0
say() { # <ok|FAIL> <name> <detail>
    if [ "$1" = ok ]; then printf '  ok    %-50s %s\n' "$2" "${3:-}"; pass=$((pass+1))
    else printf '  FAIL  %-50s %s\n' "$2" "${3:-}"; fail=$((fail+1)); fi
}

# mkrepo <name> <remote-url> [default-branch]
mkrepo() {
    local name="${1:?}"
    local url="${2:-}"
    local def="${3:-main}"
    local d="$TMP/$name"
    mkdir -p "$d"
    git -C "$d" init -q -b "$def"
    git -C "$d" config core.hooksPath "$HOOKS"        # repo-local: never global
    git -C "$d" config user.email t@t
    git -C "$d" config user.name t
    git -C "$d" config commit.gpgsign false
    git -C "$d" commit -q --allow-empty -m init
    if [ -n "$url" ]; then
        git -C "$d" remote add origin "$url"
        git -C "$d" update-ref "refs/remotes/origin/$def" HEAD
        git -C "$d" symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$def"
    fi
    [ -d "$d" ] || { echo "FATAL mkrepo $name" >&2; exit 1; }
    printf '%s' "$d"
}

echo "guard hooks"

# --- pre-commit --------------------------------------------------------------
r="$(mkrepo work git@github.com:metr/svc.git)"
printf 'a\n' > "$r/f.txt"; git -C "$r" add f.txt
if git -C "$r" commit -q -m "should block" 2>/dev/null; then
    say FAIL "commit on the default branch is blocked"
else
    say ok "commit on the default branch is blocked"
fi

git -C "$r" checkout -q -b feature
if git -C "$r" commit -q -m "on a branch" 2>/dev/null; then
    say ok "commit on a feature branch succeeds"
else
    say FAIL "commit on a feature branch succeeds"
fi

r="$(mkrepo dotfiles git@github.com:QuantumLove/dotfiles.git)"
printf 'a\n' > "$r/f.txt"; git -C "$r" add f.txt
if git -C "$r" commit -q -m "exempt" 2>/dev/null; then
    say ok "commit on an exempt repo's default branch succeeds"
else
    say FAIL "commit on an exempt repo's default branch succeeds"
fi

r="$(mkrepo noremote "")"
printf 'a\n' > "$r/f.txt"; git -C "$r" add f.txt
if git -C "$r" commit -q -m "no remote" 2>/dev/null; then
    say ok "commit in a repo with no remote succeeds"
else
    say FAIL "commit in a repo with no remote succeeds"
fi

r="$(mkrepo bypass git@github.com:metr/svc4.git)"
printf 'a\n' > "$r/f.txt"; git -C "$r" add f.txt
if git -C "$r" commit -q --no-verify -m "escape hatch" 2>/dev/null; then
    say ok "--no-verify is the escape hatch"
else
    say FAIL "--no-verify is the escape hatch"
fi

# --- pre-push: remote_ref is authoritative -----------------------------------
# Drive the hook directly with the stdin contract git uses, so no network or
# real remote is involved.
push_verdict() { # <repo> <remote> <remote_ref>
    printf 'refs/heads/src %s %s %s\n' "$(git -C "$1" rev-parse HEAD)" "$3" "0000000000000000000000000000000000000000" \
        | ( cd "$1" && "$HOOKS/pre-push" "$2" >/dev/null 2>&1 ); echo $?
}

r="$(mkrepo pushrepo git@github.com:metr/svc5.git)"
[ "$(push_verdict "$r" origin refs/heads/main)" != 0 ] \
    && say ok "push to the default branch is blocked" \
    || say FAIL "push to the default branch is blocked"

[ "$(push_verdict "$r" origin refs/heads/feature)" = 0 ] \
    && say ok "push to a feature branch is allowed" \
    || say FAIL "push to a feature branch is allowed"

# `git push origin feat:main` — the local ref is a feature branch but the
# remote ref is the default branch. Only the remote ref can catch this.
[ "$(push_verdict "$r" origin refs/heads/main)" != 0 ] \
    && say ok "a refspec-renamed push to main is blocked" \
    || say FAIL "a refspec-renamed push to main is blocked"

r="$(mkrepo pushexempt git@github.com:QuantumLove/dotfiles.git)"
[ "$(push_verdict "$r" origin refs/heads/main)" = 0 ] \
    && say ok "push to an exempt repo's default branch is allowed" \
    || say FAIL "push to an exempt repo's default branch is allowed"

# --- chaining ----------------------------------------------------------------
r="$(mkrepo chained git@github.com:metr/svc6.git)"
git -C "$r" checkout -q -b feature
mkdir -p "$r/.git/hooks"
printf '#!/usr/bin/env bash\ntouch "%s/chain-ran"\n' "$TMP" > "$r/.git/hooks/pre-commit"
chmod +x "$r/.git/hooks/pre-commit"
rm -f "$TMP/chain-ran"
printf 'a\n' > "$r/f.txt"; git -C "$r" add f.txt
git -C "$r" commit -q -m "chain" 2>/dev/null
[ -f "$TMP/chain-ran" ] \
    && say ok "the repo's own pre-commit still runs" \
    || say FAIL "the repo's own pre-commit still runs"

# A hook inside the guard dir must never be chained — that is the recursion.
rm -f "$TMP/chain-ran"
r="$(mkrepo selfchain git@github.com:metr/svc7.git)"
git -C "$r" checkout -q -b feature
printf 'b\n' > "$r/f.txt"; git -C "$r" add f.txt
if git -C "$r" commit -q -m "no recursion" 2>/dev/null; then
    say ok "chaining does not recurse into the guard dir"
else
    say FAIL "chaining does not recurse into the guard dir" "(hung or failed)"
fi

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
