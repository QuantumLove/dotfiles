#!/usr/bin/env bash
# Tests for the omp agent-model check.
# Hermetic: fake $HOME plus a `chezmoi` stub standing in for the source side.
#
# Run:  bash tests/checks/test_check_agent_models_omp.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$REPO_ROOT/tests/checks/check_agent_models_omp.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME/.omp/agent" "$TMP/bin"
export PATH="$TMP/bin:$PATH"
printf '#!/usr/bin/env bash\n[ "$1" = cat ] && { cat "${SOURCE_FIXTURE:?}"; exit 0; }\nexit 1\n' > "$TMP/bin/chezmoi"
chmod +x "$TMP/bin/chezmoi"
export SOURCE_FIXTURE="$TMP/src.yml"

pass=0 fail=0
expect() {
    local name="$1" want="$2" out got
    out="$(bash "$CHECK" 2>&1)"
    got="$(printf '%s' "$out" | awk -F'\t' '$1~/^(pass|fail|error|skip)$/{print $1}' | tail -1)"
    if [ "$got" = "$want" ]; then printf '  ok    %-50s (%s)\n' "$name" "$got"; pass=$((pass+1))
    else printf '  FAIL  %-50s wanted %s got %s\n' "$name" "$want" "${got:-none}"
         printf '%s\n' "$out" | sed 's/^/          /'; fail=$((fail+1)); fi
}

full() {  # a complete, valid declaration
cat <<'YML'
modelRoles:
  default: anthropic/claude-opus-5-fast
  smol: anthropic/claude-haiku-4-5
  task: anthropic/claude-opus-5-fast
  designer: anthropic/claude-opus-5-fast
  tiny: anthropic/claude-haiku-4-5
task:
  agentModelOverrides:
    scout: "@smol"
    designer: "@designer"
    reviewer: "@default"
    security-reviewer: "@default"
    librarian: "@smol"
    task: "@task"
    sonic: "@smol"
YML
}

echo "omp agent-model check"
full > "$TMP/src.yml"; full > "$HOME/.omp/agent/config.yml"
expect "a complete matching declaration passes" pass

# One bundled agent dropped — the failure mode that has no runtime signal.
full | grep -v '    sonic:' > "$HOME/.omp/agent/config.yml"
full | grep -v '    sonic:' > "$TMP/src.yml"
expect "a bundled agent with no declared model fails" fail

# tiny omitted — silently falls back to @smol and spends on every turn.
full | grep -v '  tiny:' > "$TMP/src.yml"; cp "$TMP/src.yml" "$HOME/.omp/agent/config.yml"
expect "an undeclared tiny role fails" fail

# Applied drifted from source, both still internally consistent.
full > "$TMP/src.yml"
full | sed 's|scout: "@smol"|scout: "@default"|' > "$HOME/.omp/agent/config.yml"
expect "applied drifting from source fails" fail

full > "$TMP/src.yml"; printf 'not: [valid\n' > "$HOME/.omp/agent/config.yml"
expect "an unparseable applied file errors" error

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
