#!/usr/bin/env bash
# Helpers sourced by every mega-assert check.
#
# A check is a bash file with a metadata header and a `run` function. It ends by
# calling exactly one of the four outcome helpers below. The four outcomes exist
# because two are not enough: a check that cannot evaluate its input must be
# distinguishable from one that evaluated and found nothing wrong, or absence of
# an answer silently becomes a pass.

# pass  — ran, invariant holds
# fail  — ran, invariant violated
# error — could not evaluate (missing input, parse failure, exception)
# skip  — not applicable here; a reason is mandatory, an unexplained skip is an error

check_pass()  { printf 'pass\t%s\n'  "${1:-}"; exit 0; }
check_fail()  { printf 'fail\t%s\n'  "${1:-}"; exit 1; }
check_error() { printf 'error\t%s\n' "${1:-}"; exit 2; }
check_skip() {
    if [ -z "${1:-}" ]; then
        printf 'error\tskip with no reason\n'; exit 2
    fi
    printf 'skip\t%s\n' "$1"; exit 3
}

# Report how many items a corpus-scanning check actually examined. The runner
# compares this against the header's @min_corpus, so a glob that matches nothing
# fails instead of passing clean.
check_scanned() { printf 'scanned\t%s\n' "${1:-0}"; }

# --- portability helpers -----------------------------------------------------
# These run on a macOS host and a Debian container. `stat -L -c` is GNU-only and
# silently produced a false "stale" on the host; `case $v in 3.[5-9]*)` rejects
# 3.10. Both were live defects in the checks these replace.

# file_age_minutes <path> — prints whole minutes since mtime, or nothing if the
# file is absent or mtime cannot be read.
file_age_minutes() {
    local f="$1" mtime now
    [ -e "$f" ] || return 1
    mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)" || return 1
    [ -n "$mtime" ] || return 1
    now="$(date +%s)"
    printf '%s' $(( (now - mtime) / 60 ))
}

# version_ge <have> <want> — true when have >= want, comparing numerically per
# component so 3.10 > 3.9.
version_ge() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]
}
