#!/bin/bash
# Print the live notification toasts as one JSON array, oldest first.
# Omarchy mirrors every on-screen toast to a file in this directory and
# deletes the file when it expires or is dismissed, so the directory listing
# is exactly "what is on screen right now".
set -euo pipefail

dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/notifications"
[[ -d $dir ]] || { echo '[]'; exit 0; }

shopt -s nullglob
files=("$dir"/*.json)
if (( ${#files[@]} == 0 )); then
  echo '[]'
  exit 0
fi

cat -- "${files[@]}" | jq -s 'sort_by(.timestamp)'
