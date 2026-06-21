#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Open in VS Code (raf-dev)
# @raycast.mode silent
# @raycast.packageName Dev
# @raycast.icon 💻
# @raycast.argument1 { "type": "text", "placeholder": "/abs/path on raf-dev (blank = clipboard)", "optional": true }

# Opens a remote folder on raf-dev in local VS Code. With no argument it reads the
# clipboard (e.g. after running `cpwd` in a raf-dev session).

REMOTE_PATH="${1:-}"
[ -z "$REMOTE_PATH" ] && REMOTE_PATH="$(pbpaste | tr -d '\r\n')"
[ -z "$REMOTE_PATH" ] && { echo "No path given and clipboard is empty"; exit 1; }

exec "$HOME/.local/bin/code-remote-open" raf-dev "$REMOTE_PATH"
