#!/usr/bin/env bash
set -euo pipefail
# Block until the Xvfb unix socket exists so Chromium/x11vnc do not race Xvfb.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${here}/lib.sh"

display="${DISPLAY:?DISPLAY must be set (fully expanded, e.g. :99)}"
sock="$(hermes_display_socket "$display")"

i=0
while (( i < 50 )); do
  if [[ -S "$sock" ]]; then
    exit 0
  fi
  sleep 0.1
  i=$((i + 1))
done

echo "fail: X socket ${sock} not ready" >&2
exit 1
