#!/usr/bin/env bash
set -euo pipefail
# Generate a MIT-MAGIC-COOKIE-1 for Xvfb. Replaces Xvfb -ac (which disables access control).

: "${XAUTHORITY:?XAUTHORITY must be set}"
: "${DISPLAY:?DISPLAY must be set (fully expanded, e.g. :99)}"

mkdir -p "$(dirname "$XAUTHORITY")"
umask 077
touch "$XAUTHORITY"
chmod 600 "$XAUTHORITY"

if ! command -v xauth >/dev/null 2>&1; then
  echo "fail: xauth is required (Debian/Ubuntu package: xauth)" >&2
  exit 1
fi

# Drop any stale cookie for this display, then add a fresh one.
xauth -f "$XAUTHORITY" remove "$DISPLAY" >/dev/null 2>&1 || true

cookie=""
if command -v mcookie >/dev/null 2>&1; then
  cookie="$(mcookie)"
elif command -v openssl >/dev/null 2>&1; then
  cookie="$(openssl rand -hex 16)"
else
  echo "fail: need mcookie (util-linux) or openssl to generate an X cookie" >&2
  exit 1
fi

xauth -f "$XAUTHORITY" add "$DISPLAY" MIT-MAGIC-COOKIE-1 "$cookie"
chmod 600 "$XAUTHORITY"
