#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Glove80 Cheatsheet
# @raycast.mode silent
# @raycast.packageName Dev
# @raycast.icon 🌸

# Opens the always-on local cheatsheet. The LaunchAgent normally keeps it running;
# if it's down, kick it and wait briefly before opening.
URL="http://localhost:5180"
if ! curl -fsS "$URL" >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$(id -u)/com.rafael.cheatsheet" 2>/dev/null || "$HOME/.local/bin/cheatsheet-serve" >/dev/null 2>&1 &
  for _ in $(seq 1 10); do curl -fsS "$URL" >/dev/null 2>&1 && break; sleep 0.5; done
fi
open "$URL"
