#!/bin/bash
# fill-toggl cron wrapper
# Runs hourly via cron to auto-create Toggl entries with safeguards
# Logs to ~/.local/state/fill-toggl/cron-runs/

set -euo pipefail

# Cron has a minimal PATH — add mise shims and ~/.local/bin so tt, python3,
# and opencode are all findable
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

LOG_DIR="$HOME/.local/state/fill-toggl/cron-runs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y-%m-%d-%H)
LOG_FILE="$LOG_DIR/$TIMESTAMP.log"

echo "=== fill-toggl cron run: $(date -Iseconds) ===" >> "$LOG_FILE"

if ! command -v fill-toggl-collect.py &>/dev/null; then
    echo "ERROR: fill-toggl-collect.py not found in PATH" >> "$LOG_FILE"
    exit 1
fi

if ! command -v opencode &>/dev/null; then
    echo "ERROR: opencode CLI not found in PATH" >> "$LOG_FILE"
    exit 1
fi

# Run preprocessing: collect sessions, activity blocks, and Toggl entries.
# JSON → stdout; progress/warnings → stderr (appended to log).
echo "--- preprocessing: fill-toggl-collect.py --date today ---" >> "$LOG_FILE"
COLLECT_OUTPUT=$(fill-toggl-collect.py --date today 2>>"$LOG_FILE") || {
    echo "ERROR: fill-toggl-collect.py failed" >> "$LOG_FILE"
    exit 1
}

GAP_COUNT=$(echo "$COLLECT_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('gaps',[])))" 2>>"$LOG_FILE") || {
    echo "ERROR: failed to parse JSON from fill-toggl-collect.py" >> "$LOG_FILE"
    exit 1
}

echo "Gaps detected: $GAP_COUNT" >> "$LOG_FILE"

if [ "$GAP_COUNT" -eq 0 ]; then
    echo "No gaps detected, skipping LLM invocation" >> "$LOG_FILE"
    echo "=== fill-toggl cron complete (no-op): $(date -Iseconds) ===" >> "$LOG_FILE"
    # Rotate old logs (keep last 7 days)
    find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    exit 0
fi

echo "--- invoking OpenCode: /fill-toggl today --auto ---" >> "$LOG_FILE"
opencode run "/fill-toggl today --auto" >> "$LOG_FILE" 2>&1 || {
    echo "ERROR: opencode invocation failed with exit code $?" >> "$LOG_FILE"
}

echo "=== fill-toggl cron complete: $(date -Iseconds) ===" >> "$LOG_FILE"

# Rotate old logs (keep last 7 days)
find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
