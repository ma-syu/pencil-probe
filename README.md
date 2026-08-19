# pencil-probe

Use your iPad's display as a pressure-sensitive pen tablet for macOS.

VirtualMac's Virtualization.framework only forwards mouse events, so
Apple Pencil pressure data is lost. pencil-probe works around this
limitation by relaying pressure data from iPad to the guest in real time.

Drawing apps like Clip Studio Paint can then respond to pen pressure
with varying line width and opacity.

## How it works

1. **iPad side**: VirtualMacOniPad captures Apple Pencil touch events
   (pressure, coordinates, tilt) and sends them to the guest over
   vsock (VZVirtioSocketDevice).
2. **macOS guest side**: pencil-probe receives the data and injects
   synthetic tablet events via CGEventPost.

## Requirements

- iPad with Apple Pencil
- [VirtualMacOniPad](https://github.com/nfzerox/VirtualMacOniPad)
  (pencil relay is included since [PR #49](https://github.com/nfzerox/VirtualMacOniPad/pull/49))
- macOS 13+ (guest)

## Install

Run on the macOS guest:

```sh
curl -fsSL https://github.com/ma-syu/pencil-probe/releases/latest/download/install.sh | bash
```

You will be prompted for the vsock port (default: 9949).

Non-interactive mode:

```sh
curl -fsSL .../install.sh | bash -s -- 9949
```

This installs:
- `~/bin/pencil-probe` — binary
- `~/Library/LaunchAgents/com.pencil-probe.plist` — auto-start at login

To change the vsock port, re-run install.sh with the new port number.

## Manual usage

```sh
pencil-probe --port 9949
```

Options:
- `--port <port>` — vsock port (default: `9949`)

## Required permissions

pencil-probe needs two macOS permissions. **Both must be enabled** for
pressure and tilt detection to work.

### Background Task Management (BTM)

pencil-probe runs as a LaunchAgent. macOS requires explicit approval in
**System Settings > General > Login Items & Extensions**.

Find `pencil-probe` (displayed as `sh` because it launches via
`/bin/sh -c`) and make sure it is enabled. If disabled, pencil-probe
will not start and only basic mouse input (no pressure or tilt) will be
available via SPICE.

### Accessibility

pencil-probe injects events via CGEventPost, which requires macOS
Accessibility permission.

Go to **System Settings > Privacy & Security > Accessibility** and
enable the appropriate entry for your setup:

- **LaunchAgent (normal usage)** — Enable `pencil-probe`. This is all
  you need for the standard setup.
- **Running from Terminal.app** — Enable `Terminal` instead.
- **Running via SSH** — Enable `sshd-keygen-wrapper` instead. Only
  needed when launching pencil-probe over an SSH session for debugging.

A warning is printed at startup if the permission is missing.

After updating the binary (re-running install.sh), you must re-register
the accessibility permission: remove the old entry and add the new one.

## Stop / restart

```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.pencil-probe.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pencil-probe.plist
```

## Uninstall

```sh
curl -fsSL https://github.com/ma-syu/pencil-probe/releases/latest/download/install.sh | bash -s uninstall
```

## Host setup (iPad)

The pencil relay is included in
[VirtualMacOniPad](https://github.com/nfzerox/VirtualMacOniPad)
(merged in [PR #49](https://github.com/nfzerox/VirtualMacOniPad/pull/49)).
Build VirtualMacOniPad and install it on your iPad — no patches needed.

The vsock port is defined as `kPencilVsockPort` (default: `9949`) in
`VirtualMacApp.m`. It must match the port used by pencil-probe on
the guest.

## Protocol

21 bytes, fixed-length, little-endian (backward-compatible with
13-byte legacy packets that omit tilt fields):

| Offset | Type    | Description                            |
|--------|---------|----------------------------------------|
| 0      | uint8   | Event type (0=point, 1=enter, 2=leave) |
| 1–4    | float32 | Pressure (0.0–1.0)                     |
| 5–8    | float32 | X (0.0–1.0, normalized)                |
| 9–12   | float32 | Y (0.0–1.0, normalized)                |
| 13–16  | float32 | Altitude (0=parallel, π/2=perpendicular) |
| 17–20  | float32 | Azimuth (0–2π, tilt direction)         |

## Verify downloads

SHA256 checksums are available in the
[release assets](https://github.com/ma-syu/pencil-probe/releases/latest).

```sh
# Download the checksums file
curl -fsSLO https://github.com/ma-syu/pencil-probe/releases/latest/download/SHA256SUMS

# Verify a downloaded file
shasum -a 256 -c SHA256SUMS
```

## License

MIT
