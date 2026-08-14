#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

failures=0
ran=0
for t in tests/test-*.sh; do
  ran=$((ran + 1))
  echo "=== ${t} ==="
  if bash "$t"; then
    echo "ok: ${t}"
  else
    echo "fail: ${t}" >&2
    failures=$((failures + 1))
  fi
  echo
done

if (( failures > 0 )); then
  echo "fail: ${failures}/${ran} test file(s) failed" >&2
  exit 1
fi
echo "ok: ${ran} test file(s) passed"
