#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${root}/scripts/start-x11vnc.sh"
fail=0
ok() { echo "ok: $*"; }
bad() { echo "fail: $*" >&2; fail=$((fail + 1)); }

if grep -q -- '-nopw' "$script"; then
  bad "start-x11vnc.sh contains -nopw"
else
  ok "start-x11vnc.sh has no -nopw"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export DISPLAY=:99
export XAUTHORITY="${tmpdir}/Xauthority"
touch "$XAUTHORITY"
export VNC_HOST=127.0.0.1
export VNC_PORT=5900
unset VNC_PASSWORD_FILE || true

set +e
out="$(bash "$script" 2>&1)"
status=$?
set -e
if [[ "$status" -ne 0 && "$out" == *"VNC_PASSWORD_FILE is unset"* ]]; then
  ok "unset VNC_PASSWORD_FILE is rejected (exit ${status})"
else
  bad "unset password did not fail closed (exit ${status}): ${out}"
fi

export VNC_PASSWORD_FILE="${tmpdir}/missing.pass"
set +e
out="$(bash "$script" 2>&1)"
status=$?
set -e
if [[ "$status" -ne 0 && "$out" == *"not found"* ]]; then
  ok "missing password file is rejected (exit ${status})"
else
  bad "missing file did not fail closed (exit ${status}): ${out}"
fi

: > "${tmpdir}/empty.pass"
export VNC_PASSWORD_FILE="${tmpdir}/empty.pass"
set +e
out="$(bash "$script" 2>&1)"
status=$?
set -e
if [[ "$status" -ne 0 && "$out" == *"empty"* ]]; then
  ok "empty password file is rejected (exit ${status})"
else
  bad "empty file did not fail closed (exit ${status}): ${out}"
fi

printf 'dummy\n' > "${tmpdir}/ok.pass"
export VNC_PASSWORD_FILE="${tmpdir}/ok.pass"
# Documentation TEST-NET address: must be rejected (not loopback).
export VNC_HOST=192.0.2.1
set +e
out="$(bash "$script" 2>&1)"
status=$?
set -e
if [[ "$status" -ne 0 && "$out" == *"loopback"* ]]; then
  ok "non-loopback VNC_HOST is rejected (exit ${status})"
else
  bad "non-loopback bind did not fail closed (exit ${status}): ${out}"
fi

assert="${root}/scripts/assert-loopback.sh"
set +e
bash "$assert" CDP_HOST 127.0.0.1
s1=$?
bash "$assert" CDP_HOST 192.0.2.1 >/dev/null 2>&1
s2=$?
set -e
if [[ "$s1" -eq 0 && "$s2" -ne 0 ]]; then
  ok "assert-loopback accepts 127.0.0.1 and rejects 192.0.2.1"
else
  bad "assert-loopback behavior wrong (${s1}, ${s2})"
fi

exit "$fail"
