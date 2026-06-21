#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Cloud Search Work
# @raycast.mode silent
# @raycast.packageName Work Tools
# @raycast.icon 🔍
# @raycast.argument1 { "type": "text", "placeholder": "Search work docs...", "optional": true, "percentEncoded": true }

# Raycast scripts run with a minimal PATH — add Homebrew so jq is found.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

BROWSER="Google Chrome"
BASE_URL="https://cloudsearch.google.com/cloudsearch/search"

# Resolve the Chrome profile *directory* from its display name, so this works on any
# machine regardless of profile creation order (dirs are Default / Profile 1 / Profile 3 / …).
PROFILE_NAME="metr.org"
LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"
PROFILE="$(jq -r --arg n "$PROFILE_NAME" '.profile.info_cache | to_entries[] | select(.value.name==$n) | .key' "$LOCAL_STATE" 2>/dev/null | head -n1)"
PROFILE="${PROFILE:-Default}"

URL="$BASE_URL"
[[ -n "$1" ]] && URL="${BASE_URL}?q=$1"

open -na "$BROWSER" --args --profile-directory="$PROFILE" "$URL"
