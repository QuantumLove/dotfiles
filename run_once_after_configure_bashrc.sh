#!/bin/sh
# Append custom functions to .bashrc if not already present

BASHRC="$HOME/.bashrc"
MARKER="# Load custom shell functions"

# Check if marker already exists
if ! grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "$MARKER" >> "$BASHRC"
    echo '[ -f "$HOME/.sh_functions" ] && . "$HOME/.sh_functions"' >> "$BASHRC"
    echo "✓ Added custom functions to .bashrc"
else
    echo "✓ Custom functions already configured in .bashrc"
fi

# Also source secrets_env in containers for non-login shells
SECRETS_MARKER="# Load container secrets"
if [ -f /.dockerenv ] && ! grep -q "$SECRETS_MARKER" "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "$SECRETS_MARKER" >> "$BASHRC"
    echo '[ -f "$HOME/.secrets_env" ] && . "$HOME/.secrets_env"' >> "$BASHRC"
    echo "✓ Added secrets_env sourcing to .bashrc"
fi
