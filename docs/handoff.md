# Procedural takeover (no lease service)

Hermes and a human share one Chromium profile. Coordination is procedural.
This repository does not implement a lock, mutex, or lease server.

## Sequence

1. **Pause.** Stop issuing Hermes browser tools. If a long task is running, ask
   Hermes to pause browser use and wait. Do not fight the agent for the mouse.
2. **Take over.** Open noVNC (`http://127.0.0.1:6080/vnc.html` via Serve or SSH
   tunnel). Complete login, MFA, or inspection.
3. **Hand back.** Close or idle the noVNC session. Tell Hermes it may continue.
4. **Fresh snapshot.** Hermes must not assume the previous DOM, tabs, or CDP
   targets are still valid. It should reconnect to `browser.cdp_url` /
   `BU_CDP_URL` and take a new snapshot (new `/json/list` targets, new
   screenshot/accessibility tree) before clicking or typing.

## Why a fresh snapshot

During takeover the human may have navigated, dismissed dialogs, or spawned tabs.
Cached selectors from before the pause are stale. A reconnect + snapshot is the
recovery path. If Chromium itself was restarted, CDP debug URLs change; read
`/json/version` again (`BU_CDP_WS` must be refreshed if you set it manually).

## What not to build

- Do not add a network lease service, Redis lock, or "who owns the browser" API.
- Do not expose CDP so two agents can "take turns" remotely.
- Do not keep typing from Hermes while a human is in noVNC.

## Operator tips

- One human session at a time (`x11vnc -shared` is on for reconnects, not for
  two operators driving at once).
- Do not restart Chromium mid-login; the profile must flush (`KillMode=mixed`,
  SIGTERM on stop).
