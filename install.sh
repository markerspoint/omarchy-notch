#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  printf 'Usage: bash install.sh [--glass]\n'
  exit 0
fi
if (( $# > 1 )) || { (( $# == 1 )) && [[ $1 != --glass ]]; }; then
  printf 'Usage: bash install.sh [--glass]\n' >&2
  exit 1
fi

for command in git python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Install failed: %s is required.\n' "$command" >&2
    exit 1
  fi
done

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
git clone --quiet --depth 1 https://github.com/markerspoint/omarchy-notch.git "$workdir/omarchy-notch"
python3 "$workdir/omarchy-notch/install.py" "$@"

if [[ ${1:-} == --glass ]]; then
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload && hyprctl configerrors || printf 'Could not reload or validate Hyprland; run hyprctl reload and hyprctl configerrors.\n' >&2
  else
    printf 'Run hyprctl reload and hyprctl configerrors in your Hyprland session.\n' >&2
  fi
fi
if command -v omarchy >/dev/null 2>&1; then
  omarchy restart shell || printf 'Could not restart the shell; run omarchy restart shell.\n' >&2
else
  printf 'Run omarchy restart shell to load the notch.\n' >&2
fi
