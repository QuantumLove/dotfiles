# mega-assert checks

Each check is one file in this directory: a metadata header, then a `run`
function, then a call to `run`.

```bash
#!/usr/bin/env bash
# @id         omo-agent-models
# @desc       Every omo agent resolves to its declared model
# @severity   invariant        # invariant | liveness
# @scope      both             # host | container | both
# @tier       2                # 1 presence · 2 content · 3 behaviour
# @boot_gate  no               # yes only for checks that should stop a boot
# @input      file:{{HOME}}/.omo/omo.jsonc
# @input      cmd:jq
# @min_corpus 10               # optional; for checks that scan a set

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run() {
    ...
    check_pass "12 agents on declared models"
}
run
```

## Why the header

**Declared inputs are the integrity mechanism.** The runner resolves every
`@input` before invoking `run`, and reports `error` when one is missing. This is
what catches a check pointing at a file that was renamed or deleted — the defect
that let a dead assertion report success for an unknown period.

**`@min_corpus` catches the other shape.** A grep across zero files and a grep
across thirty-seven both exit clean. A check that scans a set calls
`check_scanned N`; the runner fails it when `N` is below the declared minimum.

**Severity decides what blocks.** `invariant` means "config declares X and X is
true" — always blocks. `liveness` means "a service responds right now" — warns
and is counted separately, so a transient network blip never stops a boot.

**`@boot_gate yes` is a much smaller set than `invariant`.** It is only for
checks where continuing to boot is worse than failing to boot. Default no.

## Registry

`manifest.tsv` lists every check id. The runner cross-checks it against the
files in both directions: a manifest entry with no implementation fails, and an
implementation with no manifest entry fails. Neither a deleted check nor an
unregistered one can pass silently.
