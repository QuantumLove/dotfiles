#!/usr/bin/env bash
# Tests for the omo agent-model check.
# Hermetic: fake $HOME, and a `chezmoi` stub on PATH standing in for the source
# side, so nothing reads the real config or the real chezmoi state.
#
# Run:  bash tests/checks/test_check_agent_models_omo.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$REPO_ROOT/tests/checks/check_agent_models_omo.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME/.omo"
mkdir -p "$TMP/bin"; export PATH="$TMP/bin:$PATH"

pass=0 fail=0

# The stub returns whatever $TMP/source.jsonc holds — the "chezmoi source" side.
cat > "$TMP/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = "cat" ] && { cat "${SOURCE_FIXTURE:?}"; exit 0; }
exit 1
STUB
chmod +x "$TMP/bin/chezmoi"
export SOURCE_FIXTURE="$TMP/source.jsonc"

# Two agents and one category is enough to exercise every path shape.
cat > "$TMP/source.jsonc" <<'JSON'
{
  "$schema": "x",
  "[opencode]": {
    "agents": {
      "sisyphus": { "model": "anthropic/claude-opus-5-fast" },
      "oracle":   { "model": "anthropic/claude-opus-5-fast" }
    },
    "categories": { "quick": { "model": "anthropic/claude-haiku-4-5" } }
  },
  "_migrations": ["a"]
}
JSON

# expect <name> <expected-outcome> — outcome is the first field the check prints
expect() {
    local name="$1" want="$2" out got
    out="$(bash "$CHECK" 2>&1)"
    got="$(printf '%s' "$out" | awk -F'\t' '$1=="pass"||$1=="fail"||$1=="error"||$1=="skip"{print $1}' | tail -1)"
    if [ "$got" = "$want" ]; then
        printf '  ok    %-52s (%s)\n' "$name" "$got"; pass=$((pass+1))
    else
        printf '  FAIL  %-52s wanted %s got %s\n' "$name" "$want" "${got:-<none>}"
        printf '%s\n' "$out" | sed 's/^/          /'; fail=$((fail+1))
    fi
}

echo "omo agent-model check"

cp "$TMP/source.jsonc" "$HOME/.omo/omo.jsonc"
expect "applied matching source passes" pass

# The circular case: omo regenerates the file with its own defaults. Every agent
# still carries a model, and reading both sides from this file would compare
# each value against itself and pass.
cat > "$HOME/.omo/omo.jsonc" <<'JSON'
{
  "$schema": "x",
  "[opencode]": {
    "agents": {
      "sisyphus": { "model": "google/gemini-2.0-flash" },
      "oracle":   { "model": "anthropic/claude-sonnet-4" }
    },
    "categories": { "quick": { "model": "google/gemini-2.0-flash" } }
  },
  "_migrations": ["a"]
}
JSON
expect "a self-consistent regenerated file still fails" fail

cp "$TMP/source.jsonc" "$HOME/.omo/omo.jsonc"
sed -i.bak 's|"oracle":   { "model": "anthropic/claude-opus-5-fast" }|"oracle":   { "model": "anthropic/claude-opus-5" }|' "$HOME/.omo/omo.jsonc"
expect "one agent drifted off the declared model fails" fail

cp "$TMP/source.jsonc" "$HOME/.omo/omo.jsonc"
sed -i.bak 's|"anthropic/claude-opus-5-fast"|"anthropic/claude-opus-5-fast-nano"|' "$HOME/.omo/omo.jsonc"
expect "a superstring of the expected model fails" fail

# An agent present in source but gone from the applied file.
cat > "$HOME/.omo/omo.jsonc" <<'JSON'
{ "[opencode]": { "agents": { "sisyphus": { "model": "anthropic/claude-opus-5-fast" } },
  "categories": { "quick": { "model": "anthropic/claude-haiku-4-5" } } } }
JSON
expect "an agent missing from applied fails" fail

printf '{ this is not json' > "$HOME/.omo/omo.jsonc"
expect "an unparseable applied file errors, not passes" error

cp "$TMP/source.jsonc" "$HOME/.omo/omo.jsonc"
printf '{ "no": "models here" }' > "$TMP/source.jsonc"
expect "a source with no model entries errors" error

# _migrations is omo's to write; it must not be mistaken for drift.
cat > "$TMP/source.jsonc" <<'JSON'
{ "[opencode]": { "agents": { "sisyphus": { "model": "m1" } } }, "_migrations": [] }
JSON
cat > "$HOME/.omo/omo.jsonc" <<'JSON'
{ "[opencode]": { "agents": { "sisyphus": { "model": "m1" } } }, "_migrations": ["v1","v2"] }
JSON
expect "runtime-written _migrations is not drift" pass

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
