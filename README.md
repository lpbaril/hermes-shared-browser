# Hermes Shared Browser

A small, reusable deployment wrapper for Hermes Agent's existing local Chromium CDP support.

This is a security-hardened public MIT fork of the upstream project
[Marouan-chak/hermes-shared-browser](https://github.com/Marouan-chak/hermes-shared-browser).
License remains MIT (see `LICENSE`).

Hermes already provides the browser automation engine: browser tools, `/browser connect`,
and `browser.cdp_url` (also `BU_CDP_URL` / `BU_CDP_WS`). This repo does **not** replace
or fork that functionality. It packages a Debian-focused headless-server runtime that
makes a persistent visible Chromium session available through systemd user units, Xvfb,
x11vnc, and noVNC.

The browser runtime is **externally owned**: systemd starts and stops it. Hermes only
connects over loopback CDP. There is no lease service and no Hermes-core plugin.

Use it when Hermes runs on a Linux server but a human still needs to see the browser,
log in, complete MFA, or inspect pages before Hermes continues in the same session.

The pattern is:

- Chromium runs headed under a virtual X display (Xvfb) with Xauthority (not `-ac`).
- The human connects through noVNC (loopback + Tailscale Serve or SSH tunnel) to log in.
- Hermes connects locally to Chrome DevTools Protocol (CDP) and reuses the same profile.
- CDP, raw VNC, and noVNC bind to `127.0.0.1` only. Never expose CDP.

## Architecture

```text
Hermes Agent ── local CDP ──> 127.0.0.1:9222
                                │
                            Chromium
                                │
                           Xvfb :99  (Xauthority)
                                │
                  x11vnc 127.0.0.1:5900  (password required)
                                │
             noVNC/websockify 127.0.0.1:6080
                                │
              Tailscale Serve HTTPS or SSH tunnel
                                │
                     Human browser/VNC client
```

## Why not just expose CDP?

CDP is effectively remote code execution inside your authenticated browser profile.
Anyone who can reach it can read cookies, navigate as you, execute JavaScript,
download files, and control accounts. Keep it loopback-only.

Expose only pixels/keyboard through noVNC, and only via Tailscale Serve, WireGuard
+ SSH tunnel, or an SSH local forward to `127.0.0.1:6080`. noVNC is interactive
account access, not a dashboard.

## Recommended deploy: Debian LXD guest

Ubuntu 24.04 `chromium-browser` is a Snap transition. Snap Chromium is a poor fit
for this systemd user stack, and this project **never** adds `--no-sandbox`.

Preferred topology: a Debian LXD guest (distro `chromium` package, or ungoogled-chromium,
or an official Chromium `.deb`) running this stack. See [docs/lxd-guest.md](docs/lxd-guest.md).

## Requirements

Debian (bookworm/trixie) or a Debian LXD guest. Ubuntu hosts: see the Snap warning above.

```bash
make install-deps
```

Equivalent manual command on Debian:

```bash
sudo apt-get update
sudo apt-get install -y chromium xvfb x11vnc novnc websockify curl jq xauth openssl
```

## Quick start

```bash
make install-deps
make install
make set-vnc-password   # required; VNC/noVNC refuse to start without it
make start
make health
```

For services to survive logout/reboot, enable lingering. The installer **prints**
this command and does not run it:

```bash
loginctl enable-linger "$USER"
```

Set Hermes to use the local CDP endpoint:

```bash
hermes config set browser.cdp_url http://127.0.0.1:9222
# equivalently, for environments that use env vars:
# export BU_CDP_URL=http://127.0.0.1:9222
```

Open noVNC via Tailscale Serve (keeps the listener on loopback) or an SSH tunnel.
See [docs/tailscale.md](docs/tailscale.md). Example tunnel:

```bash
ssh -N -L 6080:127.0.0.1:6080 user@server
```

Then open `http://127.0.0.1:6080/vnc.html` locally.

Human takeover is procedural: pause Hermes, take control, hand back, then Hermes
takes a **fresh browser snapshot**. See [docs/handoff.md](docs/handoff.md).

## Configuration

Services read `${XDG_CONFIG_HOME:-$HOME/.config}/hermes-shared-browser/env`
(`EnvironmentFile=%E/hermes-shared-browser/env` in the units).

`DISPLAY` is written as a fully expanded value at install time (for example
`DISPLAY=:99`). systemd does **not** expand `${DISPLAY_NUM}` inside `Environment=`
values, so units do not set `Environment=DISPLAY=:${DISPLAY_NUM}`.

Defaults:

```bash
DISPLAY_NUM=99
DISPLAY=:99
SCREEN_GEOMETRY=1600x1000x24
CDP_HOST=127.0.0.1
CDP_PORT=9222
VNC_HOST=127.0.0.1
VNC_PORT=5900
NOVNC_HOST=127.0.0.1
NOVNC_PORT=6080
NOVNC_WEB_DIR=/usr/share/novnc
CHROME_PROFILE_DIR=$HOME/.hermes/browser-profiles/shared
CHROME_BIN=/usr/bin/chromium
VNC_PASSWORD_FILE=   # required; set by make set-vnc-password
```

Keep `CDP_HOST`, `VNC_HOST`, and `NOVNC_HOST` at `127.0.0.1`. Services refuse to
start if those are not loopback. Do not bind noVNC to a tailnet or LAN address;
use Tailscale Serve or SSH instead.

`--password-store=basic` is set because Chromium has no gnome-keyring in this
runtime. Saved passwords in the profile are **weakly protected**. Do not save
passwords in this browser. `--disable-save-password-bubble` is also passed.

## Verification

```bash
make status
make health
make test
```

Expected:

- CDP listens on `127.0.0.1:9222`.
- VNC listens on `127.0.0.1:5900`.
- noVNC listens on `127.0.0.1:6080`.
- `/json/version` returns a Chromium version and a `webSocketDebuggerUrl` on loopback.

## Security checklist

- [ ] CDP bound to `127.0.0.1` only.
- [ ] Raw VNC bound to `127.0.0.1` only, with a password file (no `-nopw`).
- [ ] noVNC bound to `127.0.0.1` only; remote access via Tailscale Serve or SSH.
- [ ] Browser profile directory mode `0700`; config and VNC password files `0600`.
- [ ] Do not commit cookies, profiles, screenshots, downloads, `.env`, or VNC passwords.
- [ ] No `--no-sandbox`.
- [ ] Restart Chromium only when nobody is mid-login; after hand-back, take a fresh snapshot.

Details: [docs/security.md](docs/security.md).

## Docs

- [docs/security.md](docs/security.md)
- [docs/tailscale.md](docs/tailscale.md)
- [docs/hermes-agent.md](docs/hermes-agent.md)
- [docs/lxd-guest.md](docs/lxd-guest.md)
- [docs/handoff.md](docs/handoff.md)

## License

MIT. Upstream copyright is retained in `LICENSE`.
