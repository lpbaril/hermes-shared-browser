#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
# Prove systemd-style Environment= does not expand ${DISPLAY_NUM},
# and that the env-file approach writes a fully expanded DISPLAY=:N.

fail=0
ok() { echo "ok: $*"; }
bad() { echo "fail: $*" >&2; fail=$((fail + 1)); }

export DISPLAY_NUM=99

# systemd Environment= values are taken literally from the unit file.
# The unit line Environment=DISPLAY=:${DISPLAY_NUM} therefore sets DISPLAY to
# the characters :${DISPLAY_NUM} — not :99 — even when DISPLAY_NUM=99 exists.
systemd_environment_value=':${DISPLAY_NUM}'
shell_expanded_value=":${DISPLAY_NUM}"

if [[ "$systemd_environment_value" == ':${DISPLAY_NUM}' ]]; then
  ok "systemd-style Environment= value stays literal"
else
  bad "literal value mutated unexpectedly: ${systemd_environment_value}"
fi

if [[ "$systemd_environment_value" != ":99" ]]; then
  ok "literal Environment= value is not :99"
else
  bad "literal value unexpectedly equalled :99"
fi

if [[ "$shell_expanded_value" == ":99" ]]; then
  ok "shell/env-file expansion of DISPLAY_NUM=99 yields :99"
else
  bad "shell expansion failed: ${shell_expanded_value}"
fi

if [[ "$systemd_environment_value" == "$shell_expanded_value" ]]; then
  bad "literal and expanded values must differ"
else
  ok "literal Environment= and expanded env-file values differ"
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf 'DISPLAY_NUM=99\nDISPLAY=:99\n' > "$tmp"
# shellcheck disable=SC1090
source "$tmp"
if [[ "${DISPLAY}" == ":99" && "${DISPLAY}" != *'${DISPLAY_NUM}'* ]]; then
  ok "sourcing env file yields DISPLAY=:99"
else
  bad "env file DISPLAY was '${DISPLAY}'"
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if grep -R '^Environment=DISPLAY=' "${root}/systemd/user"; then
  bad "units still contain Environment=DISPLAY="
else
  ok "units do not use Environment=DISPLAY="
fi

exit "$fail"
