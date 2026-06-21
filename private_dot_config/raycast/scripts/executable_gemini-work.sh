#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Gemini Work
# @raycast.mode silent
# @raycast.packageName AI Tools
# @raycast.icon https://www.gstatic.com/lamda/images/gemini_sparkle_v002_d4735304ff6292a690345.svg
# @raycast.argument1 { "type": "text", "placeholder": "Ask Gemini (optional)...", "optional": true, "percentEncoded": true }

# --- Configuration ---
BROWSER="Google Chrome"
# Chrome profile *directory* (not display name). Profile 3 = "metr.org" (work).
PROFILE="Profile 3"

# --- Logic ---
# Use the official app URL as default
URL="https://gemini.google.com/app"

# If a query is provided, use the Google Search AI path to force the prompt to trigger
if [[ -n "$1" ]]; then
    URL="https://www.google.com/search?udm=50&q=$1"
fi

open -na "$BROWSER" --args --profile-directory="$PROFILE" "$URL"
