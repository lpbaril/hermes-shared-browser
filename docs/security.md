# Security notes

The important boundary is CDP vs pixels.

## CDP

Chrome DevTools Protocol can fully control the browser and read authenticated state.
Treat it like a privileged local API.

- Bind CDP to `127.0.0.1` only (`--remote-debugging-address=127.0.0.1`).
- Units refuse to start if `CDP_HOST` is not loopback.
- Do not publish CDP through Caddy, nginx, Cloudflare Tunnel, Tailscale Serve,
  LAN listeners, or public ports.
- If a remote automation process must use CDP, connect through SSH port forwarding
  and restrict access tightly.

## VNC / noVNC

VNC/noVNC exposes pixels, keyboard, and mouse. That is interactive account access,
not a harmless dashboard.

- Raw VNC is loopback-only (`127.0.0.1`). Units refuse other binds.
- noVNC is loopback-only by default. Remote humans should use Tailscale Serve HTTPS
  or an SSH tunnel to `127.0.0.1:6080`. See `docs/tailscale.md`.
- If no VNC password file exists, VNC and noVNC **refuse to start**. There is no
  `-nopw` fallback.
- Password file mode is `0600`. Create it with `make set-vnc-password`.

## X11 access control

Xvfb is started with a MIT-MAGIC-COOKIE-1 in `$XAUTHORITY` (`-auth`), not `-ac`.
`-ac` disables X access control and is forbidden here.

## Browser profile and file modes

The profile contains cookies, local storage, OAuth state, downloaded files, and history.

- Profile directory is created `0700` (`mkdir -p -m 0700`).
- Services set `UMask=0077`.
- Config env file and VNC password file are `0600`.
- Config directory is `0700`.
- Do not commit or back up the profile into public repos.

## Saved passwords

`--password-store=basic` is required so Chromium can run without gnome-keyring.
Credentials stored that way are only weakly protected (profile SQLite, not a
user keyring). Do not save passwords in this browser.
`--disable-save-password-bubble` is passed to reduce accidental saves. If a
given Chromium build ignores that flag, the docs warning still applies.

## Sandbox

This stack never adds `--no-sandbox`. If Chromium cannot start, fix the runtime
(Debian distro Chromium in an LXD guest, user namespaces, `/dev/shm`) rather than
disabling the sandbox.

## systemd hardening (what was tested)

Applied on user units:

| Directive | Why | Notes |
| --- | --- | --- |
| `NoNewPrivileges=yes` | Block privilege gain | Safe for user Chromium |
| `ProtectSystem=strict` | `/usr` `/boot` `/etc` read-only | Chromium writes go to the profile |
| `ProtectHome=read-only` | Home not writable by default | `ReadWritePaths` for profile, config, runtime |
| `ReadWritePaths=` | `/tmp` (X11 socket + Chromium temp), profile, config, runtime | Required because `ProtectSystem=strict` makes `/tmp` read-only |
| `RestrictSUIDSGID=yes` | No suid | |
| `LockPersonality=yes` | No personality changes | |
| `MemoryMax=` | Cap (4G Chromium, smaller for others) | Needs cgroup v2 user delegation; ignored or fail on some hosts — raise if needed |
| `TasksMax=` | Cap process count | Chromium 512; raise if renderers are killed |
| `UMask=0077` | New files not group/world readable | |
| `PrivateTmp=yes` | Only on noVNC | **Omitted** on Xvfb/Chromium/VNC: they share `/tmp/.X11-unix` |
| `KillMode=mixed` + `TimeoutStopSec=30` | Chromium only | SIGTERM to main process, then SIGKILL leftovers |

**Not applied** (would likely break user Chromium; not tested live):
`ProtectKernelTunables`, `ProtectKernelModules`, `ProtectKernelLogs`,
`SystemCallFilter`, `RestrictNamespaces`, `PrivateUsers`.

**CI tested:** unit-file static analysis, installer dry-run with fake `HOME` /
`XDG_CONFIG_HOME`, DISPLAY env-file vs literal `Environment=` behavior,
fail-closed VNC script (missing/empty password, non-loopback bind), shellcheck.

**Not integration-tested in CI:** live Chromium under these hardening flags,
Xauthority handshake against Xvfb, Tailscale Serve, LXD guest. Operators should
run `make health` after install.

## Takeover

Human takeover is procedural only. See `docs/handoff.md`. This repo does not
implement a lease/lock service.
