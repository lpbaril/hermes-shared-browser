#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f /etc/debian_version ]]; then
  echo "This installer is intentionally Debian/Ubuntu focused for now." >&2
  echo "Install equivalent packages manually on other distributions." >&2
  echo "Recommended isolated deploy: Debian LXD guest (docs/lxd-guest.md)." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required to install packages." >&2
  exit 1
fi

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
fi

if [[ "${ID:-}" == "ubuntu" ]]; then
  echo "warning: Ubuntu's chromium-browser package is a Snap transition on current Ubuntu releases." >&2
  echo "warning: Snap Chromium is a poor fit for this systemd user stack." >&2
  echo "warning: This script will NOT install snap Chromium and will not disable the Chromium sandbox." >&2
  echo "warning: Recommended: Debian LXD guest with distro Chromium (docs/lxd-guest.md)," >&2
  echo "warning: or install a real Chromium .deb / ungoogled-chromium and set CHROME_BIN." >&2
fi

sudo apt-get update

# Display, VNC, noVNC, and Xauthority tooling. Chromium is handled separately
# so Ubuntu snap transitional packages are never installed silently.
packages=(xvfb x11vnc novnc websockify curl jq xauth openssl)

apt_package_looks_like_snap() {
  local pkg="$1"
  apt-cache show "$pkg" 2>/dev/null | grep -qiE 'snap|transitional dummy|empty transitional'
}

chromium_pkg=""
if apt-cache show chromium >/dev/null 2>&1 && ! apt_package_looks_like_snap chromium; then
  chromium_pkg=chromium
fi

if [[ -n "$chromium_pkg" ]]; then
  packages=("${chromium_pkg}" "${packages[@]}")
else
  echo "warning: No non-snap Chromium apt package found." >&2
  echo "warning: Install Debian distro Chromium, ungoogled-chromium, or an official Chromium .deb." >&2
  echo "warning: Then set CHROME_BIN in the env file. Keep the Chromium sandbox enabled." >&2
fi

sudo apt-get install -y "${packages[@]}"

echo "ok: Debian/Ubuntu dependencies installed (Chromium package: ${chromium_pkg:-none — set CHROME_BIN manually})"
echo "note: this stack keeps the Chromium sandbox enabled."
