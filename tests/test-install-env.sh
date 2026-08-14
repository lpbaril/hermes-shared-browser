#!/usr/bin/env bash
# shellcheck disable=SC2016,SC1090,SC1091
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
ok() { echo "ok: $*"; }
bad() { echo "fail: $*" >&2; fail=$((fail + 1)); }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HOME="${tmpdir}/home"
export XDG_CONFIG_HOME="${tmpdir}/xdg-config"
export XDG_RUNTIME_DIR="${tmpdir}/runtime"
export HERMES_SKIP_SYSTEMCTL=1
export HERMES_DISPLAY_NUM=99
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
# Pretend a non-snap chromium exists on PATH
mkdir -p "${tmpdir}/bin"
printf '#!/bin/sh\nexit 0\n' > "${tmpdir}/bin/chromium"
chmod 755 "${tmpdir}/bin/chromium"
export PATH="${tmpdir}/bin:${PATH}"

bash "${root}/scripts/install-systemd-user.sh" >/dev/null

env_file="${XDG_CONFIG_HOME}/hermes-shared-browser/env"
unit_dir="${XDG_CONFIG_HOME}/systemd/user"

if [[ -f "$env_file" ]]; then
  ok "env file created at XDG_CONFIG_HOME path"
else
  bad "env file missing: ${env_file}"
fi

# shellcheck disable=SC1090
source "$env_file"

if [[ "${DISPLAY:-}" == ":99" ]]; then
  ok "installer wrote fully expanded DISPLAY=:99"
else
  bad "DISPLAY was '${DISPLAY:-<unset>}' (expected :99)"
fi

if [[ "${DISPLAY:-}" == *'${DISPLAY_NUM}'* ]]; then
  bad "DISPLAY still contains unexpanded DISPLAY_NUM"
fi

if [[ "${CDP_HOST}" == "127.0.0.1" && "${VNC_HOST}" == "127.0.0.1" && "${NOVNC_HOST}" == "127.0.0.1" ]]; then
  ok "CDP/VNC/noVNC hosts are 127.0.0.1"
else
  bad "bind hosts were CDP=${CDP_HOST} VNC=${VNC_HOST} NOVNC=${NOVNC_HOST}"
fi

if [[ -z "${VNC_PASSWORD_FILE:-}" ]]; then
  ok "new env has empty VNC_PASSWORD_FILE (operator must set it)"
else
  bad "unexpected VNC_PASSWORD_FILE=${VNC_PASSWORD_FILE}"
fi

mode="$(stat -c '%a' "${HOME}/.hermes/browser-profiles/shared")"
if [[ "$mode" == "700" ]]; then
  ok "profile directory created mode 0700"
else
  bad "profile directory mode ${mode}, expected 700"
fi

cfg_mode="$(stat -c '%a' "${XDG_CONFIG_HOME}/hermes-shared-browser")"
if [[ "$cfg_mode" == "700" ]]; then
  ok "config directory mode 0700"
else
  bad "config directory mode ${cfg_mode}, expected 700"
fi

env_mode="$(stat -c '%a' "$env_file")"
if [[ "$env_mode" == "600" ]]; then
  ok "env file mode 0600"
else
  bad "env file mode ${env_mode}, expected 600"
fi

if [[ -x "${XDG_CONFIG_HOME}/hermes-shared-browser/bin/start-x11vnc.sh" ]]; then
  ok "helper scripts installed under config dir bin/"
else
  bad "helper scripts missing from config dir bin/"
fi

if [[ -f "${unit_dir}/hermes-browser-chromium.service" ]]; then
  ok "units installed under XDG_CONFIG_HOME/systemd/user"
else
  bad "units not installed to ${unit_dir}"
fi

if grep -q '^EnvironmentFile=%E/hermes-shared-browser/env$' "${unit_dir}/hermes-browser-chromium.service"; then
  ok "installed unit uses %E (matches XDG_CONFIG_HOME)"
else
  bad "installed unit EnvironmentFile mismatch"
fi

if grep -q '^XAUTHORITY=' "$env_file"; then
  ok "XAUTHORITY written into env file"
else
  bad "XAUTHORITY missing from env file"
fi

# Default HOME path (no XDG_CONFIG_HOME): still %E-compatible ~/.config
tmpdir2="$(mktemp -d)"
export HOME="${tmpdir2}/home"
unset XDG_CONFIG_HOME
export XDG_RUNTIME_DIR="${tmpdir2}/runtime"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
bash "${root}/scripts/install-systemd-user.sh" >/dev/null
if [[ -f "${HOME}/.config/hermes-shared-browser/env" ]]; then
  ok "without XDG_CONFIG_HOME, env lands in ~/.config"
else
  bad "default config path not used"
fi
# shellcheck disable=SC1090
source "${HOME}/.config/hermes-shared-browser/env"
if [[ "${DISPLAY}" == ":99" ]]; then
  ok "default-home install also expands DISPLAY=:99"
else
  bad "default-home DISPLAY=${DISPLAY}"
fi

exit "$fail"
