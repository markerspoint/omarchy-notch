#!/bin/bash
# Sample the wallpaper strip behind the bar, rather than application content.
# Cache by file metadata: image processing runs only when the background changes.
set -u
screen_width=$1
screen_height=$2
bar_height=$3
sample_width=$4
last_key=""
while :; do
  wallpaper=$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)
  key="$wallpaper:$(stat -Lc '%y:%s' "$wallpaper" 2>/dev/null || true)"
  if [[ "$key" != "$last_key" && -f "$wallpaper" ]]; then
    last_key=$key
    sample_x=$(( (screen_width - sample_width) / 2 ))
    rgb=$(magick "$wallpaper" -auto-orient -resize "${screen_width}x${screen_height}^" \
      -gravity center -extent "${screen_width}x${screen_height}" \
      -gravity NorthWest -crop "${sample_width}x${bar_height}+${sample_x}+0" +repage \
      -resize '1x1!' -format '%[fx:int(255*r)],%[fx:int(255*g)],%[fx:int(255*b)]' info:- 2>/dev/null || true)
    if [[ "$rgb" =~ ^([0-9]+),([0-9]+),([0-9]+)$ ]]; then
      sample=$(printf '#%02x%02x%02x' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")
      python -c 'import json,sys; print(json.dumps({"color": sys.argv[1], "path": sys.argv[2], "revision": sys.argv[3]}))' "$sample" "$wallpaper" "$key"
    fi
  fi
  sleep 2
done
