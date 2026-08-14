#!/usr/bin/env bash
set -euo pipefail
# usage: wait-for-port.sh HOST PORT
# Used as ExecStartPost so dependents wait until the listener is actually up.

host="${1:?host}"
port="${2:?port}"

i=0
while (( i < 50 )); do
  if bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
    exit 0
  fi
  sleep 0.1
  i=$((i + 1))
done

echo "fail: ${host}:${port} not listening" >&2
exit 1
