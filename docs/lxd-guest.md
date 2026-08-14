# Debian LXD guest (recommended isolated deploy)

Run this stack inside a Debian LXD guest (container or VM), not as Snap Chromium
on an Ubuntu 24.04 host.

Ubuntu 24.04 `chromium-browser` is a Snap transition package. Snap Chromium does
not match this systemd-user design, and this project will **never** add
`--no-sandbox` to make a Snap/confined browser start.

## Topology (generic)

```text
Linux host (any)
  └── LXD
        └── Debian guest (distro chromium or official .deb)
              ├── systemd --user (this repo)
              ├── Chromium + CDP 127.0.0.1:9222
              ├── x11vnc 127.0.0.1:5900
              └── noVNC 127.0.0.1:6080
                    └── Tailscale Serve or SSH -L 6080:127.0.0.1:6080
```

No hostnames, tailnet DNS names, or node IDs belong in this document.

## Guest OS

- **Recommended:** Debian bookworm or trixie, package `chromium`.
- Alternatives: ungoogled-chromium, or an official Chromium `.deb`.
- Set `CHROME_BIN` to the absolute binary path if it is not `/usr/bin/chromium`.

## Launch sketch

Names below are placeholders. Use your own guest name.

```bash
# VM is often easier for Chromium than an unprivileged container:
lxc launch images:debian/13 debian-browser --vm

lxc exec debian-browser -- apt-get update
lxc exec debian-browser -- apt-get install -y chromium xvfb x11vnc novnc websockify curl jq xauth openssl sudo systemd

# Copy this repo into the guest, then as the unprivileged operator:
make install-deps   # or skip if packages are already present
make install
make set-vnc-password
loginctl enable-linger "$USER"   # run yourself; installers only print this
make start
make health
```

If you use a container instead of a VM, you may need nested user namespaces and
a reasonable `/dev/shm`. If Chromium refuses to start, fix the guest (VM, nesting,
package choice) — do not pass `--no-sandbox`.

## Host vs guest

- Installer on an Ubuntu **host** prints a Snap warning and will not install
  snap Chromium.
- `install-debian-packages.sh` installs a real apt `chromium` when it is not a
  snap/transitional dummy; otherwise it leaves `CHROME_BIN` for you to set.
- Tailscale can run in the guest (Serve to `127.0.0.1:6080`) or the host can
  SSH-forward into the guest loopback. Either way, listeners stay on loopback
  inside the guest.

## Linger

User systemd units use `WantedBy=default.target`. They come back after reboot
only if lingering is enabled. The installer prints `loginctl enable-linger`
and does not run it.
