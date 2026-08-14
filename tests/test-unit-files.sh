#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
units="${root}/systemd/user"
fail=0
check() {
  local msg="$1"
  shift
  if "$@"; then
    echo "ok: ${msg}"
  else
    echo "fail: ${msg}" >&2
    fail=$((fail + 1))
  fi
}

if grep -R --line-number -E '^Environment=DISPLAY=' "${units}"; then
  echo "fail: Environment=DISPLAY= present; units must use EnvironmentFile only" >&2
  fail=$((fail + 1))
else
  echo "ok: no Environment=DISPLAY= in units"
fi

check "xvfb EnvironmentFile uses %E" grep -q '^EnvironmentFile=%E/hermes-shared-browser/env$' "${units}/hermes-browser-xvfb.service"
check "chromium EnvironmentFile uses %E" grep -q '^EnvironmentFile=%E/hermes-shared-browser/env$' "${units}/hermes-browser-chromium.service"
check "vnc EnvironmentFile uses %E" grep -q '^EnvironmentFile=%E/hermes-shared-browser/env$' "${units}/hermes-browser-vnc.service"
check "novnc EnvironmentFile uses %E" grep -q '^EnvironmentFile=%E/hermes-shared-browser/env$' "${units}/hermes-browser-novnc.service"

if grep -E -- '-ac(\s|$)' "${units}/hermes-browser-xvfb.service"; then
  echo "fail: xvfb unit contains -ac" >&2
  fail=$((fail + 1))
else
  echo "ok: xvfb ExecStart does not contain -ac"
fi
check "xvfb uses -auth" grep -q -- '-auth' "${units}/hermes-browser-xvfb.service"

if grep -R -- '-nopw' "${units}" "${root}/scripts"; then
  echo "fail: -nopw present in units or scripts" >&2
  fail=$((fail + 1))
else
  echo "ok: no -nopw in units/scripts"
fi
check "fail-closed VNC helper referenced" grep -q 'start-x11vnc.sh' "${units}/hermes-browser-vnc.service"
check "novnc requires password file" grep -q 'VNC_PASSWORD_FILE' "${units}/hermes-browser-novnc.service"

check "CDP loopback assert" grep -q 'assert-loopback.sh CDP_HOST' "${units}/hermes-browser-chromium.service"
check "remote-debugging-address uses CDP_HOST" grep -q -- '--remote-debugging-address=${CDP_HOST}' "${units}/hermes-browser-chromium.service"
check "VNC loopback assert" grep -q 'assert-loopback.sh VNC_HOST' "${units}/hermes-browser-vnc.service"
check "noVNC loopback assert" grep -q 'assert-loopback.sh NOVNC_HOST' "${units}/hermes-browser-novnc.service"

for u in hermes-browser-xvfb hermes-browser-chromium hermes-browser-vnc hermes-browser-novnc; do
  check "UMask=0077 in ${u}" grep -q '^UMask=0077$' "${units}/${u}.service"
done

check "profile mkdir -m 0700" grep -q 'mkdir -p -m 0700 ${CHROME_PROFILE_DIR}' "${units}/hermes-browser-chromium.service"

if grep -R --line-number -- '--no-sandbox' "${units}" "${root}/scripts"; then
  echo "fail: --no-sandbox present in units/scripts" >&2
  fail=$((fail + 1))
else
  echo "ok: --no-sandbox not used in units/scripts"
fi

check "chromium After xvfb" grep -q '^After=hermes-browser-xvfb.service$' "${units}/hermes-browser-chromium.service"
check "chromium Requires xvfb" grep -q '^Requires=hermes-browser-xvfb.service$' "${units}/hermes-browser-chromium.service"
check "vnc After xvfb" grep -q '^After=hermes-browser-xvfb.service$' "${units}/hermes-browser-vnc.service"
check "vnc Requires xvfb" grep -q '^Requires=hermes-browser-xvfb.service$' "${units}/hermes-browser-vnc.service"
check "novnc After vnc" grep -q '^After=hermes-browser-vnc.service$' "${units}/hermes-browser-novnc.service"
check "novnc Requires vnc" grep -q '^Requires=hermes-browser-vnc.service$' "${units}/hermes-browser-novnc.service"
check "WantedBy=default.target xvfb" grep -q '^WantedBy=default.target$' "${units}/hermes-browser-xvfb.service"
check "KillMode=mixed chromium" grep -q '^KillMode=mixed$' "${units}/hermes-browser-chromium.service"
check "TimeoutStopSec chromium" grep -q '^TimeoutStopSec=30$' "${units}/hermes-browser-chromium.service"
check "ExecStop SIGTERM chromium" grep -q 'kill -s TERM' "${units}/hermes-browser-chromium.service"

for flag in NoNewPrivileges=yes ProtectSystem=strict ProtectHome=read-only RestrictSUIDSGID=yes LockPersonality=yes; do
  check "${flag} in chromium" grep -q "^${flag}$" "${units}/hermes-browser-chromium.service"
done

if grep -R -E 'ProtectKernelTunables|ProtectKernelModules|ProtectKernelLogs|SystemCallFilter' "${units}"; then
  echo "fail: untested kernel/syscall hardening present" >&2
  fail=$((fail + 1))
else
  echo "ok: no untested ProtectKernel or SystemCallFilter directives"
fi

exit "$fail"
