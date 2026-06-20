#!/usr/bin/env bash
# Unit tests for the no-diff-narration-comments PostToolUse hook.
# Hermetic: builds a temp HOME with the worktree's hook-lib + hook, so it tests
# the source under version control rather than whatever is currently applied.
#
# Run:  bash tests/hooks/test_no-diff-narration-comments.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="$REPO_ROOT/private_dot_claude/hooks"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/.claude/hooks"
cp "$SRC_DIR/executable_hook-lib.sh.tmpl" "$TMP_HOME/.claude/hooks/hook-lib.sh"
HOOK="$TMP_HOME/.claude/hooks/no-diff-narration-comments.sh"
cp "$SRC_DIR/executable_no-diff-narration-comments.sh.tmpl" "$HOOK"
chmod +x "$HOOK"

pass=0 fail=0

# run_case <name> <expected_exit> <payload-json> [env_assignment]
run_case() {
    local name="$1" expected="$2" payload="$3" env_kv="${4:-}"
    local actual
    if [ -n "$env_kv" ]; then
        actual="$(printf '%s' "$payload" | env HOME="$TMP_HOME" "$env_kv" bash "$HOOK" 2>/dev/null; echo "EC:$?")"
    else
        actual="$(printf '%s' "$payload" | env HOME="$TMP_HOME" bash "$HOOK" 2>/dev/null; echo "EC:$?")"
    fi
    actual="${actual##*EC:}"
    if [ "$actual" = "$expected" ]; then
        printf '  ok    %-32s (exit %s)\n' "$name" "$actual"; pass=$((pass+1))
    else
        printf '  FAIL  %-32s expected %s got %s\n' "$name" "$expected" "$actual"; fail=$((fail+1))
    fi
}

# Payload builders (jq -n escapes newlines/quotes correctly)
edit()      { jq -n --arg s "$1" '{tool_name:"Edit",      tool_input:{new_string:$s}}'; }
write()     { jq -n --arg s "$1" '{tool_name:"Write",     tool_input:{content:$s}}'; }
multiedit() { jq -n --arg s "$1" '{tool_name:"MultiEdit", tool_input:{edits:[{new_string:$s}]}}'; }

echo "Diff-narration hook — flagged cases (expect exit 2):"
run_case "previously"        2 "$(edit '# previously hit the v1 endpoint')"
run_case "changed-from"      2 "$(edit '# changed from synchronous to async')"
run_case "per-review"        2 "$(edit 'x = 1  # tweaked per review')"
run_case "as-requested"      2 "$(edit '# field added as requested by client')"
run_case "new-label-write"   2 "$(write '// NEW: added for METR-123 export')"
run_case "todo-remove-multi" 2 "$(multiedit 'y = 2  # TODO: remove after the v2 migration lands')"
run_case "for-now"           2 "$(edit '# hardcode for now')"
run_case "temporary"         2 "$(edit '# temporary workaround until upstream fix')"
run_case "multiline-one-bad" 2 "$(edit "$(printf 'x = compute()\n# formerly returned null on miss')")"

echo "Clean cases (expect exit 0):"
run_case "why-comment"       0 "$(edit '# Stripe truncates sub-cent amounts so totals reconcile')"
run_case "no-comment"        0 "$(edit 'amount = round_down(raw)')"
run_case "fallback-why"      0 "$(edit '# fall back to cache when the API is unavailable')"
run_case "url-with-slashes"  0 "$(edit 'base = "http://example.com/api"')"
run_case "narration-in-code" 0 "$(edit 'flag = "previously_set"')"
run_case "multiline-clean"   0 "$(edit "$(printf '# use a set for O(1) membership\nseen = set()')")"
run_case "empty-added"       0 "$(edit '')"

echo "Control cases:"
run_case "bash-ignored"      0 '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
run_case "bypass-env"        0 "$(edit '# previously hit the v1 endpoint')" "CLAUDE_ALLOW_NARRATION_COMMENTS=1"
run_case "malformed-payload" 0 'not json at all'

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
