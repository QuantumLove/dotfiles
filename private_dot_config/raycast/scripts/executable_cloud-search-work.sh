#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Cloud Search Work
# @raycast.mode silent
# @raycast.packageName Work Tools
# @raycast.icon 🔍
# @raycast.argument1 { "type": "text", "placeholder": "Search work docs...", "optional": true, "percentEncoded": true }

# --- Configuration ---
BROWSER="Google Chrome"
# Chrome profile *directory* (not display name). Profile 3 = "metr.org" (work).
# Map is in: ~/Library/Application Support/Google/Chrome/Local State -> profile.info_cache
PROFILE="Profile 3"
BASE_URL="https://cloudsearch.google.com/cloudsearch/search"

# --- Logic ---
URL="$BASE_URL"
if [[ -n "$1" ]]; then
    URL="${BASE_URL}?q=$1"
fi

open -na "$BROWSER" --args --profile-directory="$PROFILE" "$URL"
