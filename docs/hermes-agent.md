# Hermes Agent integration

This repo does not implement a browser engine, MCP server, or Hermes core tool.
It is an externally owned runtime. Hermes connects to Chromium through the
existing CDP configuration:

| Mechanism | Example |
| --- | --- |
| `browser.cdp_url` | `hermes config set browser.cdp_url http://127.0.0.1:9222` |
| `BU_CDP_URL` | `export BU_CDP_URL=http://127.0.0.1:9222` |
| `BU_CDP_WS` | Websocket URL from `http://127.0.0.1:9222/json/version` (`webSocketDebuggerUrl`) |

Prefer `browser.cdp_url` / `BU_CDP_URL` (HTTP endpoint). Hermes discovers the
websocket. If you set `BU_CDP_WS` yourself, copy it from `/json/version` after
Chromium is up, and only use a `ws://127.0.0.1:...` URL.

After the stack is running:

```bash
hermes config set browser.cdp_url http://127.0.0.1:9222
curl -fsS http://127.0.0.1:9222/json/version
```

Then use Hermes browser tools normally. The agent attaches to the visible
Chromium profile instead of creating an ephemeral session.

The runtime is owned by systemd user units, not by Hermes. If Chromium restarts,
Hermes must reconnect. After any human takeover, Hermes must take a **fresh
snapshot** rather than assuming the previous DOM still exists. See
[handoff.md](handoff.md).

Recommended workflow:

1. Hermes pauses browser use (or you do not issue browser tools yet).
2. Open noVNC (via Tailscale Serve or SSH tunnel to `127.0.0.1:6080`).
3. Log in / MFA / inspect.
4. Hand control back.
5. Ask Hermes to snapshot/reconnect and continue.
6. Keep CDP bound to loopback.

Do not build or expect a lease service. Coordination is procedural.
