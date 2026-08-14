# Hardening changelog (verified against 5a9cd12)

Source tree was fetched from
`https://github.com/Marouan-chak/hermes-shared-browser/archive/5a9cd1216eca112adb26cfb80838c3c984d4fd95.tar.gz`
(no git clone). MIT `LICENSE` and upstream attribution are unchanged.

## Hypotheses vs fetched source

### 1. Chromium unit `Environment=DISPLAY=:${DISPLAY_NUM}` — **confirmed, fixed**

`systemd/user/hermes-browser-chromium.service` had `Environment=DISPLAY=:${DISPLAY_NUM}`.
systemd does **not** expand `${DISPLAY_NUM}` inside `Environment=` values, so Chromium
would see a literal `DISPLAY=:${DISPLAY_NUM}`.

Nuance: `ExecStart=` *does* expand EnvironmentFile variables, so Xvfb
`:${DISPLAY_NUM}` would have worked. The broken path was Chromium's `DISPLAY`
environment, not the Xvfb argument.

**Fix:** installer writes `DISPLAY=:99` (fully expanded) into the env file.
Units use `EnvironmentFile=` only (no `Environment=DISPLAY=`).
Test: `tests/test-display-env.sh`.

### 2. XDG_CONFIG_HOME vs hardcoded `%h/.config/.../env` — **confirmed, fixed**

Installer honored `XDG_CONFIG_HOME`; units hardcoded `%h/.config/hermes-shared-browser/env`.

**Fix:** units use `EnvironmentFile=%E/hermes-shared-browser/env` (`%E` is
`$XDG_CONFIG_HOME` or `%h/.config` for user units). Installer still writes env
and copies units under `${XDG_CONFIG_HOME:-$HOME/.config}`.
Test: `tests/test-install-env.sh`.

### 3. Xvfb `-ac` — **confirmed, fixed**

Xvfb ExecStart included `-ac`.

**Fix:** `scripts/prepare-xauth.sh` generates MIT-MAGIC-COOKIE-1, `xauth add`,
Xvfb `-auth ${XAUTHORITY}` and `-nolisten tcp`. No `-ac`.
Smoke-tested locally with `xauth`; not a full Xvfb handshake in CI.

### 4. VNC `-nopw` fallback — **confirmed, fixed**

VNC ExecStart used bash `-lc` with `-nopw` when no password file existed.

**Fix:** `scripts/start-x11vnc.sh` refuses unset/missing/empty password files
and refuses non-loopback `VNC_HOST`. noVNC `ExecStartPre` also requires the
password file. No `-nopw` path.
Test: `tests/test-vnc-fail-closed.sh`.

### 5. Profile `0700` / `UMask=0077` — **confirmed missing, fixed**

`mkdir -p` without mode; no `UMask` in units.

**Fix:** `UMask=0077` on all units; `mkdir -p -m 0700` for the profile;
installer `chmod 0700` on config/profile dirs; env and VNC password `0600`.

### 6. `--password-store=basic` — **confirmed present, documented / hardened**

Flag was already on Chromium. It is still required without gnome-keyring.

**Fix:** keep `--password-store=basic`, add `--disable-save-password-bubble`,
document that saved passwords are weakly protected. The extra flag was not
live-tested against a running Chromium; unknown flags are typically ignored.

### 7. systemd hardening — **confirmed missing, added (conservative)**

**Applied:** `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=read-only`,
`ReadWritePaths` (profile, config, runtime, `/tmp`), `RestrictSUIDSGID`,
`LockPersonality`, `MemoryMax`, `TasksMax`, `UMask=0077`.
`PrivateTmp=yes` only on noVNC.

**Not applied:** `ProtectKernelTunables`, `ProtectKernelModules`,
`ProtectKernelLogs`, `SystemCallFilter`, `RestrictNamespaces`, `PrivateUsers`
(likely break user Chromium; not tested).

**PrivateTmp omitted** on Xvfb/Chromium/VNC because they share `/tmp/.X11-unix`
and Xvfb's `/tmp/.Xn-lock`. `ProtectSystem=strict` requires `ReadWritePaths=/tmp`
on those units.

**CI tested:** static unit parsing only. Live Chromium under these flags was
**not** run in CI.

### 8. Procedural takeover — **not applicable as a bug; documented**

No lease service existed at 5a9cd12. None was added. See `docs/handoff.md`.

### 9. Tests + CI — **confirmed missing, added**

`tests/` + `.github/workflows/ci.yml` + `make lint` / `make test`.
Ran locally: shellcheck clean; 4/4 test files passed.

### 10. Chromium install / Snap / `--no-sandbox` — **confirmed Snap risk; `--no-sandbox` was already absent**

`--no-sandbox` was **not** in 5a9cd12 (hypothesis of a present flag was wrong).
Ubuntu `chromium-browser` Snap risk was real: installer considered
`chromium-browser` and even a `/snap/chromium/...` path.

**Fix:** never install snap/transitional Chromium; warn on Ubuntu; never add
sandbox-disable flags; document Debian LXD guest (`docs/lxd-guest.md`).

### 11. noVNC loopback / Tailscale — **partially confirmed, fixed**

Defaults were already `NOVNC_HOST=127.0.0.1`, but the installer detected a
Tailscale IPv4 and told the operator to bind `NOVNC_HOST` to it.

**Fix:** no Tailscale IP detection; loopback asserts on CDP/VNC/noVNC;
`docs/tailscale.md` uses Tailscale Serve HTTPS in front of `127.0.0.1:6080`
with generic ACL/grant examples (no hostnames or tailnet DNS).

### 12. Browser runtime externally owned — **confirmed by design; documented**

Already a systemd wrapper, not Hermes core. Docs now state that explicitly
(`browser.cdp_url` / `BU_CDP_URL` / `BU_CDP_WS`, no MCP/plugins).

## Other correctness fixes

- Explicit `After=` / `Requires=` (xvfb before vnc/chromium; vnc before novnc).
- Xvfb `ExecStartPost` waits for the X unix socket; VNC waits for the RFB port.
- Chromium `KillMode=mixed`, `TimeoutStopSec=30`, `ExecStop` SIGTERM.
- `WantedBy=default.target` kept; linger documented, installer print-only.
