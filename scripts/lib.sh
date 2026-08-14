#!/usr/bin/env bash
# Shared helpers for hermes-shared-browser. Safe to source.

hermes_is_loopback() {
  case "${1:-}" in
    127.0.0.1|localhost|::1) return 0 ;;
    *) return 1 ;;
  esac
}

hermes_assert_loopback() {
  local name="${1:?}"
  local value="${2:-}"
  if hermes_is_loopback "$value"; then
    return 0
  fi
  echo "fail: ${name} must be loopback (127.0.0.1). Got: '${value}'" >&2
  echo "CDP, raw VNC, and noVNC are loopback-only. For remote pixels use Tailscale Serve or an SSH tunnel to 127.0.0.1." >&2
  return 1
}

hermes_display_socket() {
  local display="${1:?}"
  local num="${display#:}"
  printf '/tmp/.X11-unix/X%s\n' "$num"
}
