---
name: hermes-shared-browser
description: Use when configuring a persistent visible Chromium session for Hermes Agent on a headless Linux server. Guides Xvfb with Xauthority, loopback-only CDP/VNC/noVNC, Tailscale Serve, browser.cdp_url / BU_CDP_URL, procedural handoff, and Debian LXD guest deploy. Never --no-sandbox.
version: 1.1.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [hermes, browser, cdp, chromium, xvfb, vnc, novnc, tailscale, devops]
    related_skills: [hermes-agent]
---

# Hermes Shared Browser

## Overview

Use this skill to configure a reusable, persistent, visible browser runtime for Hermes Agent on a headless Linux host. Hermes already provides the browser automation engine through browser tools, `/browser connect`, and `browser.cdp_url`; this stack is an operational wrapper (externally owned systemd user runtime) that makes a persistent visible Chromium session available. Prefer a Debian LXD guest; Ubuntu snap Chromium is not supported and --no-sandbox is never used.

```text
Hermes Agent -> local Chrome DevTools Protocol -> Chromium profile
Human user   -> VNC/noVNC pixels + keyboard     -> same Chromium profile
```

This lets a person log in once through a visual browser, handle MFA, solve account-specific prompts, or inspect the UI, then let Hermes continue using the same authenticated browser profile through CDP.

The open-source reference implementation (this hardened MIT fork) is:

```text
https://github.com/lpbaril/hermes-shared-browser
```

Upstream (unmodified): https://github.com/Marouan-chak/hermes-shared-browser

Security boundary: CDP is powerful enough to control authenticated accounts and read browser state. Keep CDP, raw VNC, and noVNC bound to loopback (`127.0.0.1`) only. Remote pixels go through Tailscale Serve HTTPS or an SSH tunnel to `127.0.0.1:6080`. noVNC is interactive account access. VNC/noVNC refuse to start without a password file.

## When to Use

Use this skill when the user asks to:

- make Hermes browser automation reuse a browser they can see and log into manually
- run Hermes browser automation on a headless server, VPS, Raspberry Pi, or homelab machine
- connect Hermes Agent to an existing visible Chromium/Chrome session through CDP
- expose browser pixels over Tailscale Serve or SSH tunnel without exposing CDP
- troubleshoot `browser.cdp_url`, CDP connection failures, blank VNC screens, or service startup failures
- package or document a shared browser stack for other Hermes users

Do not use this skill for:

- general Hermes Agent installation or model/provider configuration; use the `hermes-agent` skill
- exposing Chrome DevTools Protocol over the public internet
- storing or committing browser profiles, cookies, screenshots with secrets, or local service environment files
- bypassing website terms of service or automating accounts without authorization

## Reference Architecture

```text
Hermes Agent process
  browser.cdp_url=http://127.0.0.1:9222
        |
        v
  Chromium --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222
        |
        v
  Xvfb virtual display, for example :99
        |
        v
  x11vnc, preferably bound to 127.0.0.1:5900
        |
        v
  noVNC/websockify, bound to a private interface or 127.0.0.1 behind a tunnel
        |
        v
  Human browser/VNC client
```

Default safe bindings:

| Component | Default bind | Exposure guidance |
| --- | --- | --- |
| CDP | `127.0.0.1:9222` | Keep loopback-only. Do not expose to LAN/VPN/public internet. |
| VNC | `127.0.0.1:5900` | Keep loopback-only unless separately authenticated and encrypted. |
| noVNC | `127.0.0.1:6080` | Loopback only. Remote access via Tailscale Serve or SSH `-L 6080:127.0.0.1:6080`. |
| Browser profile | `~/.hermes/browser-profiles/shared` | Persistent local state; never commit or copy into logs. |

## Installation Workflow

Start from the reference repository:

```bash
git clone https://github.com/lpbaril/hermes-shared-browser.git
cd hermes-shared-browser
```

Prefer a Debian LXD guest with distro Chromium (see `docs/lxd-guest.md`). Ubuntu snap Chromium is not supported.

```bash
make install-deps
make install
make set-vnc-password
make start
make health
```

The installer prints `loginctl enable-linger "$USER"` and does not run it. Linger is required for user systemd after logout/reboot.

Equivalent Debian package set:

```bash
sudo apt-get update
sudo apt-get install -y chromium xvfb x11vnc novnc websockify curl jq xauth openssl
```

## Configure Hermes Agent

Point Hermes to the local CDP endpoint:

```bash
hermes config set browser.cdp_url http://127.0.0.1:9222
# or: export BU_CDP_URL=http://127.0.0.1:9222
# BU_CDP_WS is the websocket from http://127.0.0.1:9222/json/version (loopback only)
```

Then restart or relaunch any long-running Hermes session that needs to pick up the updated config.

Smoke-check CDP before using browser tools:

```bash
curl -fsS http://127.0.0.1:9222/json/version | jq .
```

Expected shape:

- HTTP succeeds from the Hermes host itself
- response contains a Chromium/Chrome version
- response contains `webSocketDebuggerUrl`
- `webSocketDebuggerUrl` points to `127.0.0.1` or `localhost`, not a public/private network address

## Configure Remote Human Access

Keep noVNC on loopback. For a remote human, use Tailscale Serve or SSH:

```bash
tailscale serve --bg http://127.0.0.1:6080
# or: ssh -N -L 6080:127.0.0.1:6080 user@server
```

Do not set `NOVNC_HOST` to a tailnet or LAN address; units refuse non-loopback binds.

```bash
CDP_HOST=127.0.0.1
VNC_HOST=127.0.0.1
NOVNC_HOST=127.0.0.1
```

VNC password is required (fail-closed, no `-nopw`):

```bash
make set-vnc-password
```

Handoff is procedural (no lease service): pause Hermes → human takes control in noVNC → hand back → Hermes takes a fresh browser snapshot. See `docs/handoff.md`.

## Verification Checklist

Run these checks before telling the user the setup is ready:

```bash
systemctl --user --no-pager --lines=30 status hermes-browser-xvfb.service
systemctl --user --no-pager --lines=30 status hermes-browser-chromium.service
systemctl --user --no-pager --lines=30 status hermes-browser-vnc.service
systemctl --user --no-pager --lines=30 status hermes-browser-novnc.service
ss -ltnp | grep -E ':(9222|5900|6080)\b'
curl -fsS http://127.0.0.1:9222/json/version | jq .
```

Expected:

- Xvfb service is active
- Chromium service is active and not repeatedly restarting
- CDP listens on `127.0.0.1:<port>` only
- VNC listens on `127.0.0.1:<port>` only
- noVNC listens on 127.0.0.1 only
- Hermes has `browser.cdp_url` set to the local CDP endpoint
- A human can open noVNC and see Chromium
- Hermes browser automation can navigate using the same profile after the human login

CDP exposure guard:

```bash
ss -ltnp | grep ':9222'
```

Reject unsafe results such as:

```text
0.0.0.0:9222
:::9222
<lan-ip>:9222
<tailnet-ip>:9222
```

Accept safe results such as:

```text
127.0.0.1:9222
[::1]:9222
```

## Troubleshooting

### noVNC opens but the screen is blank

Check Xvfb and Chromium logs:

```bash
journalctl --user -u hermes-browser-xvfb.service -n 100 --no-pager
journalctl --user -u hermes-browser-chromium.service -n 100 --no-pager
```

Common causes:

- Chromium binary path is wrong
- Chromium exits because the package is a wrapper that does not behave well under systemd
- display number mismatch between Xvfb, Chromium, and x11vnc
- profile directory permissions are wrong

### CDP does not respond

```bash
curl -v http://127.0.0.1:9222/json/version
journalctl --user -u hermes-browser-chromium.service -n 100 --no-pager
```

Check that Chromium was launched with:

```text
--remote-debugging-address=127.0.0.1
--remote-debugging-port=<port>
```

### Hermes still uses an ephemeral browser

Check the active Hermes config:

```bash
hermes config get browser.cdp_url
```

If the config is correct but the current Hermes session was already running, relaunch Hermes so it reloads config.

### Service starts in a shell but not under systemd

Use explicit absolute paths in `~/.config/hermes-shared-browser/env`:

```bash
CHROME_BIN=/usr/bin/chromium
NOVNC_WEB_DIR=/usr/share/novnc
WEBSOCKIFY_BIN=/usr/bin/websockify
```

Then reload and restart:

```bash
systemctl --user daemon-reload
systemctl --user restart hermes-browser-chromium.service hermes-browser-novnc.service
```

### Remote noVNC is unreachable

Check the bind address and firewall/private network path:

```bash
ss -ltnp | grep ':6080'
curl -fsSI http://127.0.0.1:6080/ | head
```

Remote access should hit Tailscale Serve or `http://127.0.0.1:6080/` through an SSH tunnel, not a LAN bind.

If local loopback works but Serve/tunnel fails, the issue is Serve/ACL/SSH, not Chromium.

## Open-Source Contribution Best Practices

When modifying the reference repo or producing reusable instructions:

- Use `127.0.0.1` examples only. Do not put real hostnames, Tailscale IPs, tailnet DNS, account IDs, tokens, or customer info in files.
- Do not commit `~/.config/hermes-shared-browser/env`, browser profiles, cookies, screenshots, VNC passwords, logs, `.env` files, or generated state.
- Keep CDP examples loopback-only.
- Include verification commands and expected safe/unsafe outputs.
- Test shell scripts with `bash -n`.
- Verify user systemd units with `systemd-analyze --user verify` when available.
- Run `git diff --check` before committing.
- Scan staged changes for sensitive-looking strings before pushing to a public repository.

Pre-push guard for public repos:

```bash
git status --short
git diff --cached --stat
git diff --cached --check
git diff --cached | grep -Ei 'api[_-]?key|token|secret|password|authorization|bearer|private key|BEGIN|\.env' || true
git diff --cached --name-only | grep -Ei '(^|/)(\.env|config\.ya?ml|auth\.json|credentials|secret|secrets|\.pem|\.key|id_rsa|id_ed25519|.*\.db|browser-profiles?)$' && echo 'STOP: sensitive-looking file staged'
```

## Verification Before Finishing

Before finalizing a setup or repo change:

- [ ] The browser stack services are installed and active, or blockers are clearly reported.
- [ ] CDP responds locally on loopback.
- [ ] CDP is not exposed on LAN, VPN, Tailnet, or public interfaces.
- [ ] noVNC is reachable only through the intended private route.
- [ ] Hermes `browser.cdp_url` points at the local CDP URL.
- [ ] A human login and Hermes automation use the same persistent browser profile.
- [ ] Public documentation contains no real secrets, internal hostnames, account IDs, customer data, cookies, screenshots, or local state.
