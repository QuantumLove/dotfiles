#!/bin/sh
# Install tmux-snapshot cron job (idempotent).
set -eu

CRON_ENTRY="*/15 * * * * \$HOME/.local/bin/tmux-snapshot 2>/dev/null"
MARKER="tmux-snapshot"

if crontab -l 2>/dev/null | grep -q "$MARKER"; then
    echo "✓ tmux-snapshot cron job already installed"
else
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo "✓ Added tmux-snapshot cron job (every 15 minutes)"
fi
