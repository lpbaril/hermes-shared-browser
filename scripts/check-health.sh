#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${here}/lib.sh"

config_file="${XDG_CONFIG_HOME:-$HOME/.config}/hermes-shared-browser/env"
services=(
  hermes-browser-xvfb.service
  hermes-browser-chromium.service
  hermes-browser-vnc.service
  hermes-browser-novnc.service
)

if [[ ! -f "$config_file" ]]; then
  echo "fail: missing config file: $config_file" >&2
  echo "Run: make install" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$config_file"

failures=0
warn() { echo "warn: $*" >&2; }
fail() { echo "fail: $*" >&2; failures=$((failures + 1)); }

for svc in "${services[@]}"; do
  if systemctl --user is-active --quiet "$svc"; then
    echo "ok: $svc active"
  else
    fail "$svc not active"
    systemctl --user --no-pager --lines=20 status "$svc" || true
  fi
done

echo
echo "listeners:"
ss -ltnp | grep -E ":(${CDP_PORT:-9222}|${VNC_PORT:-5900}|${NOVNC_PORT:-6080})\b" || warn "no matching listeners found"

echo
echo "cdp version:"
if ! curl -fsS "http://127.0.0.1:${CDP_PORT:-9222}/json/version" | { command -v jq >/dev/null && jq . || python3 -m json.tool; }; then
  fail "CDP did not respond on 127.0.0.1:${CDP_PORT:-9222}"
fi

echo
echo "security checks:"

if ! hermes_is_loopback "${CDP_HOST:-}"; then
  fail "CDP_HOST is not loopback: ${CDP_HOST:-<unset>}"
fi
if ! hermes_is_loopback "${VNC_HOST:-}"; then
  fail "VNC_HOST is not loopback: ${VNC_HOST:-<unset>}"
fi
if ! hermes_is_loopback "${NOVNC_HOST:-}"; then
  fail "NOVNC_HOST is not loopback: ${NOVNC_HOST:-<unset>} (use Tailscale Serve or SSH tunnel)"
fi

if ss -ltnp | grep -E ":${CDP_PORT:-9222}\b" | grep -vqE "127\.0\.0\.1:${CDP_PORT:-9222}|\[::1\]:${CDP_PORT:-9222}"; then
  fail "CDP appears to be listening on a non-loopback address"
else
  echo "ok: CDP is loopback-only"
fi

if ss -ltnp | grep -E ":${VNC_PORT:-5900}\b" | grep -vqE "127\.0\.0\.1:${VNC_PORT:-5900}|\[::1\]:${VNC_PORT:-5900}"; then
  fail "raw VNC appears reachable beyond loopback"
else
  echo "ok: raw VNC is loopback-only"
fi

if ss -ltnp | grep -E ":${NOVNC_PORT:-6080}\b" | grep -vqE "127\.0\.0\.1:${NOVNC_PORT:-6080}|\[::1\]:${NOVNC_PORT:-6080}"; then
  fail "noVNC appears reachable beyond loopback; bind 127.0.0.1 and use Tailscale Serve or an SSH tunnel"
else
  echo "ok: noVNC is loopback-only"
fi

if [[ -z "${VNC_PASSWORD_FILE:-}" || ! -f "${VNC_PASSWORD_FILE}" ]]; then
  fail "VNC password file missing. VNC/noVNC must not run without one. Run: make set-vnc-password"
else
  echo "ok: VNC password file present"
fi

if [[ -n "${CHROME_PROFILE_DIR:-}" && -d "${CHROME_PROFILE_DIR}" ]]; then
  mode="$(stat -c '%a' "${CHROME_PROFILE_DIR}" 2>/dev/null || stat -f '%OLp' "${CHROME_PROFILE_DIR}")"
  if [[ "$mode" != "700" && "$mode" != "0700" ]]; then
    fail "browser profile directory mode is ${mode}, expected 0700: ${CHROME_PROFILE_DIR}"
  else
    echo "ok: browser profile directory mode 0700"
  fi
fi

# Intentional literal match for a broken unexpanded DISPLAY value.
# shellcheck disable=SC2016
if [[ "${DISPLAY:-}" == *'${DISPLAY_NUM}'* || "${DISPLAY:-}" == ':${DISPLAY_NUM}' ]]; then
  fail "DISPLAY is not fully expanded (systemd Environment= would leave this literal). Re-run make install."
else
  echo "ok: DISPLAY is fully expanded (${DISPLAY:-<unset>})"
fi

if command -v hermes >/dev/null 2>&1; then
  configured_cdp="$(hermes config get browser.cdp_url 2>/dev/null || true)"
  if [[ "$configured_cdp" == "http://127.0.0.1:${CDP_PORT:-9222}" ]]; then
    echo "ok: Hermes browser.cdp_url points at local CDP"
  else
    warn "Hermes browser.cdp_url is not set to http://127.0.0.1:${CDP_PORT:-9222}"
    warn "Current value: ${configured_cdp:-<unset or unavailable>}"
  fi
else
  warn "hermes CLI not found in PATH; skipping browser.cdp_url check"
fi

echo "note: noVNC is interactive account access (keyboard/mouse to the authenticated profile), not a dashboard."
echo "note: --password-store=basic stores credentials weakly in the profile; do not save passwords there."

if (( failures > 0 )); then
  echo "fail: $failures health check(s) failed" >&2
  exit 1
fi

echo "ok: health checks passed"
