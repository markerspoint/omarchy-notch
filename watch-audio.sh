#!/usr/bin/env bash
# The spectrum is optional; missing Cava must not prevent standard installation.
set -euo pipefail

if ! command -v cava >/dev/null 2>&1; then
  exit 0
fi

exec cava -p "$1"
