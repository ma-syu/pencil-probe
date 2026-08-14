# pencil-probe

Use your iPad's display as a pressure-sensitive pen tablet for macOS.

VirtualMac's Virtualization.framework only forwards mouse events, so
Apple Pencil pressure data is lost. pencil-probe works around this
limitation by relaying pressure data from iPad to the guest in real time.

Drawing apps like Clip Studio Paint can then respond to pen pressure
with varying line width and opacity.

## How it works

1. **iPad side**: A patch to VirtualMac captures Apple Pencil touch
   events (pressure + coordinates) and sends them to the guest over TCP.
2. **macOS guest side**: pencil-probe receives the data and injects
   synthetic tablet events via CGEventPost.

## Requirements

- iPad with Apple Pencil
- [VirtualMacOniPad](https://github.com/nfzerox/VirtualMacOniPad)
  with the pencil relay patch applied (see [Host setup](#host-setup-ipad))
- macOS 13+ (guest)

## Install

Run on the macOS guest:

```sh
curl -fsSL https://github.com/ma-syu/pencil-probe/releases/latest/download/install.sh | bash
```

You will be prompted for the guest's IP address and port.

Non-interactive mode:

```sh
curl -fsSL .../install.sh | bash -s -- <guest-ip>
curl -fsSL .../install.sh | bash -s -- <guest-ip> <port>
```

This installs:
- `~/bin/pencil-probe` — binary
- `~/bin/pencil-probe-launcher.sh` — wrapper that reads config and launches the binary
- `~/.config/pencil-probe.conf` — IP/port configuration
- `~/Library/LaunchAgents/com.pencil-probe.plist` — auto-start at login

## Configuration

Edit `~/.config/pencil-probe.conf`:

```
LISTEN=<guest-ip>
PORT=9949
```

Apply changes:

```sh
launchctl kickstart -k gui/$(id -u)/com.pencil-probe
```

## Manual usage

```sh
pencil-probe --listen <guest-ip> --port 9949
```

Options:
- `--listen <IP>` — IP address to bind (default: `127.0.0.1`)
- `--port <port>` — listening port (default: `9949`)
- `--allow <IP>` — only accept connections from this IP

## Accessibility permission

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

Apply the pencil relay patch to VirtualMac and rebuild. The patch adds
TCP transmission of Apple Pencil pressure and coordinates in
`touchesBegan`, `touchesMoved`, and `touchesEnded`.

Connection settings (environment variables):
- `PENCIL_RELAY_HOST` — guest IP address (default: `192.168.1.2`)
- `PENCIL_RELAY_PORT` — port number (default: `9949`)

## Protocol

13 bytes, fixed-length, little-endian:

| Offset | Type    | Description                          |
|--------|---------|--------------------------------------|
| 0      | uint8   | Event type (0=point, 1=enter, 2=leave) |
| 1–4    | float32 | Pressure (0.0–1.0)                   |
| 5–8    | float32 | X (0.0–1.0, normalized)              |
| 9–12   | float32 | Y (0.0–1.0, normalized)              |

## License

MIT
