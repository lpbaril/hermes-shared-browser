#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
config_dir="${config_home}/hermes-shared-browser"
unit_dir="${config_home}/systemd/user"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
profile_root="${HOME}/.hermes/browser-profiles"
profile_dir="${profile_root}/shared"

umask 077
mkdir -p "$config_dir/bin" "$unit_dir" "$profile_dir"
chmod 0700 "$config_dir" "$config_dir/bin" "$profile_root" "$profile_dir"

if [[ -f /etc/debian_version ]]; then
  distro_note="Debian/Ubuntu detected. Run 'make install-deps' first if packages are missing."
else
  distro_note="Non-Debian distro detected. This repo is documented for Debian (LXD guest recommended); install equivalent packages manually."
fi

resolve_chrome_bin() {
  local candidate real
  for candidate in chromium google-chrome google-chrome-stable chromium-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      real="$(command -v "$candidate")"
      if [[ "$real" == /snap/* ]] || [[ -L "$real" && "$(readlink -f "$real" 2>/dev/null || true)" == /snap/* ]]; then
        echo "warning: skipping snap Chromium at ${real}. Keep the Chromium sandbox enabled. See docs/lxd-guest.md" >&2
        continue
      fi
      printf '%s\n' "$real"
      return 0
    fi
  done
  if [[ -x /usr/bin/chromium ]]; then
    printf '%s\n' /usr/bin/chromium
    return 0
  fi
  printf '%s\n' chromium
}

is_snap_chrome() {
  local p="${1:-}"
  [[ "$p" == /snap/* ]] && return 0
  if [[ -n "$p" && -e "$p" ]]; then
    local resolved
    resolved="$(readlink -f "$p" 2>/dev/null || true)"
    [[ "$resolved" == /snap/* ]] && return 0
  fi
  return 1
}

chrome_bin="$(resolve_chrome_bin)"
if is_snap_chrome "$chrome_bin"; then
  echo "warning: CHROME_BIN resolves to a snap. Ubuntu snap Chromium is not supported here." >&2
  echo "warning: Use a Debian LXD guest with distro Chromium, or an official Chromium .deb. Keep the Chromium sandbox enabled." >&2
fi

novnc_web=""
for candidate in /usr/share/novnc /usr/share/noVNC /opt/novnc; do
  if [[ -d "$candidate" ]]; then
    novnc_web="$candidate"
    break
  fi
done
novnc_web="${novnc_web:-/usr/share/novnc}"

display_num="${HERMES_DISPLAY_NUM:-99}"
display=":${display_num}"
xauthority="${runtime_dir}/hermes-shared-browser/Xauthority"

env_file="${config_dir}/env"
if [[ ! -f "$env_file" ]]; then
  cat > "$env_file" <<EOF
# Fully expanded at install time. systemd Environment= does NOT expand \${DISPLAY_NUM}.
DISPLAY_NUM=${display_num}
DISPLAY=${display}
SCREEN_GEOMETRY=1600x1000x24
XAUTHORITY=${xauthority}

# Loopback-only. Do not change these bind addresses.
CDP_HOST=127.0.0.1
CDP_PORT=9222
VNC_HOST=127.0.0.1
VNC_PORT=5900
NOVNC_HOST=127.0.0.1
NOVNC_PORT=6080
NOVNC_WEB_DIR=${novnc_web}

CHROME_PROFILE_DIR=${profile_dir}
CHROME_BIN=${chrome_bin}

# Required. Create with: make set-vnc-password
# VNC/noVNC refuse to start without this file.
VNC_PASSWORD_FILE=
EOF
  chmod 600 "$env_file"
else
  # Migrate keys introduced by hardening without rewriting operator values.
  ensure_env_key() {
    local key="$1" value="$2"
    if ! grep -q "^${key}=" "$env_file"; then
      printf '%s=%s\n' "$key" "$value" >> "$env_file"
    fi
  }
  ensure_env_key DISPLAY_NUM "$display_num"
  if ! grep -q '^DISPLAY=' "$env_file"; then
    existing_num="$(grep '^DISPLAY_NUM=' "$env_file" | head -n1 | cut -d= -f2- || true)"
    existing_num="${existing_num:-$display_num}"
    printf 'DISPLAY=:%s\n' "$existing_num" >> "$env_file"
  fi
  ensure_env_key XAUTHORITY "$xauthority"
  chmod 600 "$env_file"
fi

# Copy helper scripts next to the env file so units can use %E/hermes-shared-browser/bin/
for helper in lib.sh assert-loopback.sh prepare-xauth.sh wait-for-x.sh wait-for-port.sh start-x11vnc.sh; do
  install -m 0700 "${repo_dir}/scripts/${helper}" "${config_dir}/bin/${helper}"
done

cp "${repo_dir}"/systemd/user/*.service "${unit_dir}"/ 

if [[ -z "${HERMES_SKIP_SYSTEMCTL:-}" ]] && command -v systemctl >/dev/null 2>&1; then
  if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user daemon-reload
  else
    echo "note: systemctl --user daemon-reload skipped (no user systemd instance)"
  fi
fi

linger_note="User systemd will stop at logout unless lingering is enabled."
if [[ -f "/var/lib/systemd/linger/${USER}" ]]; then
  linger_note="ok: linger already enabled for ${USER}."
else
  linger_note="Linger is not enabled. User systemd stops at logout and may not come back at boot.
This installer does not run privileged loginctl. If you want services after reboot/logout, run:
  loginctl enable-linger ${USER}
See README.md (lingering)."
fi

vnc_pw_note="VNC/noVNC will refuse to start until a password file exists:
  make set-vnc-password"

cat <<EOF
Installed user units to: ${unit_dir}
Config file: ${env_file}
Helper scripts: ${config_dir}/bin

${distro_note}
${linger_note}

${vnc_pw_note}

Next steps:
  1. Review ${env_file}. Keep CDP_HOST, VNC_HOST, and NOVNC_HOST at 127.0.0.1.
     Remote pixels: Tailscale Serve or SSH tunnel to 127.0.0.1:6080 (docs/tailscale.md).
  2. Required:
     make set-vnc-password
  3. Start services:
     make start
  4. Run health checks:
     make health
  5. Point Hermes at local CDP (do not expose CDP):
     hermes config set browser.cdp_url http://127.0.0.1:9222
     # or: export BU_CDP_URL=http://127.0.0.1:9222
EOF
