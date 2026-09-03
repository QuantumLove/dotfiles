#!/usr/bin/env bash
# Unit tests for the mega-assert runner.
# Hermetic: each case builds a throwaway checks directory and points the runner
# at it with MEGA_ASSERT_CHECKS_DIR, so nothing here reads or writes the real
# registry or $HOME.
#
# Run:  bash tests/checks/test_runner.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$REPO_ROOT/private_dot_local/bin/executable_mega-assert"
LIB="$REPO_ROOT/tests/checks/lib.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

# new_dir <name> — fresh checks dir with lib.sh and an empty manifest
new_dir() {
    local d="$TMP/$1"; mkdir -p "$d"; cp "$LIB" "$d/lib.sh"
    printf '# @min_checks 0\n' > "$d/manifest.tsv"
    printf '%s' "$d"
}

# add_check <dir> <id> <body> [extra_header_lines]
add_check() {
    local d="$1" id="$2" body="$3" extra="${4:-}"
    { printf '#!/usr/bin/env bash\n'
      printf '# @id         %s\n' "$id"
      printf '# @severity   invariant\n# @scope      both\n# @tier       1\n# @boot_gate  no\n'
      [ -n "$extra" ] && printf '%s\n' "$extra"
      printf 'set -uo pipefail\n. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"\nrun() { %s; }\nrun\n' "$body"
    } > "$d/check_${id//-/_}.sh"
    printf '%s\n' "$id" >> "$d/manifest.tsv"
}

# assert <name> <expected_exit> <dir> [args...]
assert() {
    local name="$1" expected="$2" dir="$3"; shift 3
    local out rc
    out="$(MEGA_ASSERT_CHECKS_DIR="$dir" HOME="$TMP/home" bash "$RUNNER" "$@" 2>&1)"; rc=$?
    if [ "$rc" = "$expected" ]; then
        printf '  ok    %-46s (exit %s)\n' "$name" "$rc"; pass=$((pass+1))
    else
        printf '  FAIL  %-46s expected %s got %s\n' "$name" "$expected" "$rc"
        printf '%s\n' "$out" | sed 's/^/          /'; fail=$((fail+1))
    fi
}

# assert_out <name> <dir> <grep-pattern> [args...]
assert_out() {
    local name="$1" dir="$2" pat="$3"; shift 3
    local out
    out="$(MEGA_ASSERT_CHECKS_DIR="$dir" HOME="$TMP/home" bash "$RUNNER" "$@" 2>&1)"
    if printf '%s' "$out" | grep -qE "$pat"; then
        printf '  ok    %-46s\n' "$name"; pass=$((pass+1))
    else
        printf '  FAIL  %-46s no match for /%s/\n' "$name" "$pat"
        printf '%s\n' "$out" | sed 's/^/          /'; fail=$((fail+1))
    fi
}

mkdir -p "$TMP/home"
echo "mega-assert runner"

# --- outcomes ---------------------------------------------------------------
d="$(new_dir happy)";  add_check "$d" ok-check 'check_pass "fine"'
assert "a passing check exits 0" 0 "$d"

d="$(new_dir failing)"; add_check "$d" bad-check 'check_fail "nope"'
assert "a failing invariant exits nonzero" 1 "$d"

d="$(new_dir erroring)"; add_check "$d" err-check 'check_error "cannot evaluate"'
assert "an erroring invariant exits nonzero" 1 "$d"
assert_out "error is reported as error, not fail" "$d" 'error: cannot evaluate'

d="$(new_dir skipping)"; add_check "$d" skip-check 'check_skip "not applicable here"'
assert "a skip with a reason exits 0" 0 "$d"

d="$(new_dir skipnoreason)"; add_check "$d" mute-skip 'check_skip ""'
assert "a skip with no reason is an error" 1 "$d"

# --- declared inputs (the integrity mechanism) ------------------------------
d="$(new_dir inputs)"
add_check "$d" needs-file 'check_pass "unreachable"' '# @input      file:/nonexistent/path/xyz'
assert "missing declared input errors before run" 1 "$d"
assert_out "and names the missing input" "$d" 'missing file: /nonexistent/path/xyz'

d="$(new_dir inputcmd)"
add_check "$d" needs-cmd 'check_pass "unreachable"' '# @input      cmd:definitely-not-a-real-binary'
assert "missing declared command errors" 1 "$d"

d="$(new_dir inputok)"
add_check "$d" has-input 'check_pass "input present"' '# @input      cmd:bash'
assert "present declared input runs normally" 0 "$d"

# --- corpus minimums --------------------------------------------------------
d="$(new_dir corpus_low)"
add_check "$d" thin-scan 'check_scanned 2; check_pass "scanned"' '# @min_corpus 10'
assert "scanning below the declared minimum fails" 1 "$d"
assert_out "and reports the counts" "$d" 'scanned 2, below declared minimum 10'

d="$(new_dir corpus_silent)"
add_check "$d" silent-scan 'check_pass "no count"' '# @min_corpus 10'
assert "declaring min_corpus without counting errors" 1 "$d"

d="$(new_dir corpus_ok)"
add_check "$d" good-scan 'check_scanned 37; check_pass "scanned 37"' '# @min_corpus 30'
assert "scanning above the minimum passes" 0 "$d"

# --- registry cross-check ---------------------------------------------------
d="$(new_dir orphan_manifest)"; printf 'ghost-check\n' >> "$d/manifest.tsv"
assert "manifest id with no implementation fails" 1 "$d"
assert_out "and names the id" "$d" "manifest id 'ghost-check' has no implementation"

d="$(new_dir orphan_file)"; add_check "$d" registered 'check_pass "ok"'
add_check "$d" unregistered 'check_pass "ok"'
sed -i.bak '/^unregistered$/d' "$d/manifest.tsv"; rm -f "$d/manifest.tsv.bak"
assert "implementation with no manifest entry fails" 1 "$d"

# --- severity: liveness must not gate ---------------------------------------
d="$(new_dir liveness)"
{ printf '#!/usr/bin/env bash\n# @id         flaky-probe\n# @severity   liveness\n'
  printf '# @scope      both\n# @tier       1\n# @boot_gate  no\n'
  printf 'set -uo pipefail\n. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"\nrun() { check_fail "service down"; }\nrun\n'
} > "$d/check_flaky_probe.sh"
printf 'flaky-probe\n' >> "$d/manifest.tsv"
assert "a failing liveness check does not change exit" 0 "$d"
assert_out "but is still reported" "$d" 'flaky-probe'

# --- scope: skips are visible, not silent -----------------------------------
d="$(new_dir scoped)"
{ printf '#!/usr/bin/env bash\n# @id         container-only\n# @severity   invariant\n'
  printf '# @scope      container\n# @tier       1\n# @boot_gate  no\n'
  printf 'set -uo pipefail\n. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"\nrun() { check_fail "should not run"; }\nrun\n'
} > "$d/check_container_only.sh"
printf 'container-only\n' >> "$d/manifest.tsv"
assert "container-only check does not run on host" 0 "$d" --scope host
assert_out "and is reported as skipped with a reason" "$d" '1 skipped' --scope host

# --- registered-count floor -------------------------------------------------
d="$(new_dir floor)"; printf '# @min_checks 2\n' > "$d/manifest.tsv"
add_check "$d" lonely 'check_pass "ok"'
assert "registering fewer than the floor errors" 2 "$d"
assert_out "and says so" "$d" 'only 1 checks registered'

# --- missing corpus ---------------------------------------------------------
assert "an unreadable checks dir errors, not passes" 2 "$TMP/does-not-exist"

# --- boot gate subset -------------------------------------------------------
d="$(new_dir bootgate)"
add_check "$d" not-gated 'check_fail "would fail"'
{ printf '#!/usr/bin/env bash\n# @id         gated\n# @severity   invariant\n'
  printf '# @scope      both\n# @tier       1\n# @boot_gate  yes\n'
  printf 'set -uo pipefail\n. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"\nrun() { check_pass "gated ok"; }\nrun\n'
} > "$d/check_gated.sh"
printf 'gated\n' >> "$d/manifest.tsv"
assert "--boot-gate runs only the gated subset" 0 "$d" --boot-gate
assert "without --boot-gate the failure surfaces" 1 "$d"

# --- listing ----------------------------------------------------------------
d="$(new_dir listing)"; add_check "$d" listed 'check_pass "ok"'
assert_out "--list shows the registry" "$d" 'listed .*invariant' --list

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
