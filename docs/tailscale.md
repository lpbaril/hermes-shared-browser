# Tailscale Serve (loopback noVNC)

Keep noVNC bound to `127.0.0.1:6080`. Do not set `NOVNC_HOST` to a tailnet IP
or any non-loopback address — units refuse to start if it is not loopback.

Tailscale Serve publishes HTTPS on your tailnet in front of that loopback listener.

## Serve HTTPS to loopback noVNC

On the machine running this stack (generic example):

```bash
tailscale serve --bg http://127.0.0.1:6080
```

Then open the Serve URL Tailscale prints (it will be HTTPS on your tailnet).
The noVNC UI is typically at `/vnc.html`.

Equivalent idea with an SSH tunnel from a laptop, no Serve required:

```bash
ssh -N -L 6080:127.0.0.1:6080 user@server
```

Open `http://127.0.0.1:6080/vnc.html` on the laptop.

## What must stay local

```bash
CDP_HOST=127.0.0.1
VNC_HOST=127.0.0.1
NOVNC_HOST=127.0.0.1
```

Do not Serve, proxy, or port-forward CDP (`127.0.0.1:9222`) or raw VNC
(`127.0.0.1:5900`) onto the tailnet.

## Password

VNC/noVNC will not start without `make set-vnc-password`. Serve HTTPS does not
replace that password: noVNC is still interactive account access.

## ACL / grant (generic)

Restrict which tailnet identities can reach Serve. A generic grant shape:

```json
{
  "grants": [
    {
      "src": ["group:browsers-ops"],
      "dst": ["tag:shared-browser"],
      "app": {
        "tailscale.com/cap/serve": []
      }
    }
  ]
}
```

Use your own tag and group names. Do not copy hostnames, tailnet DNS names, or
node IDs into this repository.

Also limit who can SSH to the guest. CDP remains loopback-only even for those
identities.

## Checklist

- [ ] `NOVNC_HOST=127.0.0.1`
- [ ] Serve or SSH tunnel only; no LAN bind
- [ ] VNC password configured
- [ ] CDP not published via Serve
