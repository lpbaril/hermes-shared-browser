#!/usr/bin/env bash
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hermes-shared-browser"
password_file="${config_dir}/vnc.pass"
env_file="${config_dir}/env"

umask 077
mkdir -p "$config_dir"
chmod 0700 "$config_dir"

if ! command -v x11vnc >/dev/null 2>&1; then
  echo "x11vnc is required. On Debian/Ubuntu: sudo apt-get install -y x11vnc" >&2
  exit 1
fi

# Interactive store; file mode 0600.
x11vnc -storepasswd "$password_file"
chmod 600 "$password_file"

if [[ -f "$env_file" ]]; then
  if grep -q '^VNC_PASSWORD_FILE=' "$env_file"; then
    tmp="$(mktemp)"
    chmod 600 "$tmp"
    sed "s|^VNC_PASSWORD_FILE=.*|VNC_PASSWORD_FILE=${password_file}|" "$env_file" > "$tmp"
    cat "$tmp" > "$env_file"
    rm -f "$tmp"
  else
    printf '\nVNC_PASSWORD_FILE=%s\n' "$password_file" >> "$env_file"
  fi
  chmod 600 "$env_file"
else
  printf 'VNC_PASSWORD_FILE=%s\n' "$password_file" > "$env_file"
  chmod 600 "$env_file"
fi

cat <<EOF
ok: VNC password stored at ${password_file} (mode 0600)
Restart VNC/noVNC for it to take effect:
  systemctl --user restart hermes-browser-vnc.service hermes-browser-novnc.service
EOF
