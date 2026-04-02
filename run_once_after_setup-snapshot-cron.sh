#!/bin/sh
# Install tmux-snapshot cron job (idempotent)

# Ensure cron daemon is running
service cron start 2>/dev/null || true

# Check if cron entry already exists
CRON_ENTRY="*/15 * * * * \$HOME/.local/bin/tmux-snapshot 2>/dev/null"
MARKER="tmux-snapshot"

if ! crontab -l 2>/dev/null | grep -q "$MARKER"; then
    # Add the cron entry
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo "✓ Added tmux-snapshot cron job (every 15 minutes)"
else
    echo "✓ tmux-snapshot cron job already installed"
fi
