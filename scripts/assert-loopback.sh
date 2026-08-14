#!/usr/bin/env bash
set -euo pipefail
# usage: assert-loopback.sh NAME VALUE
# Rejects non-loopback bind addresses so CDP/VNC/noVNC cannot be started on LAN/VPN/public interfaces.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${here}/lib.sh"

hermes_assert_loopback "${1:?name}" "${2:-}"
