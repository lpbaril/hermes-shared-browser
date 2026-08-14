#!/usr/bin/env bash
set -euo pipefail
# Fail-closed x11vnc launcher: fail closed: password file required, loopback bind only.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${here}/lib.sh"

if [[ -z "${VNC_PASSWORD_FILE:-}" ]]; then
  echo "fail: VNC_PASSWORD_FILE is unset. Refusing to start x11vnc without a password." >&2
  echo "Run: make set-vnc-password" >&2
  exit 1
fi

if [[ ! -f "$VNC_PASSWORD_FILE" ]]; then
  echo "fail: VNC password file not found: ${VNC_PASSWORD_FILE}" >&2
  echo "Run: make set-vnc-password" >&2
  exit 1
fi

if [[ ! -s "$VNC_PASSWORD_FILE" ]]; then
  echo "fail: VNC password file is empty: ${VNC_PASSWORD_FILE}" >&2
  echo "Run: make set-vnc-password" >&2
  exit 1
fi

hermes_assert_loopback VNC_HOST "${VNC_HOST:-}"

display="${DISPLAY:?DISPLAY must be set (fully expanded, e.g. :99)}"
xauthority="${XAUTHORITY:?XAUTHORITY must be set}"
vnc_host="${VNC_HOST}"
vnc_port="${VNC_PORT:-5900}"

if [[ ! -f "$xauthority" ]]; then
  echo "fail: XAUTHORITY file not found: ${xauthority}" >&2
  exit 1
fi

# -localhost forces loopback even if -listen is mis-set.
# Unauthenticated VNC is not a fallback.
exec /usr/bin/x11vnc \
  -display "$display" \
  -auth "$xauthority" \
  -listen "$vnc_host" \
  -localhost \
  -rfbport "$vnc_port" \
  -rfbauth "$VNC_PASSWORD_FILE" \
  -forever \
  -shared \
  -nolookup
