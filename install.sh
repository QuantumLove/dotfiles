#!/bin/sh
# VS Code dotfiles install script
# This runs automatically when VS Code clones dotfiles to a devcontainer

set -e

echo "Installing dotfiles..."

# Install chezmoi if not already installed
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "→ Installing chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)"
fi

# Apply dotfiles using this directory as source
echo "→ Applying dotfiles..."
if [ -x "$HOME/bin/chezmoi" ]; then
    "$HOME/bin/chezmoi" init --apply --source="$PWD"
elif command -v chezmoi >/dev/null 2>&1; then
    chezmoi init --apply --source="$PWD"
else
    echo "Error: chezmoi not found"
    exit 1
fi

echo "✓ Dotfiles installed successfully!"
