#!/usr/bin/env bash
set -euo pipefail

# install.sh — Install or uninstall pencil-probe
#
# Usage:
#   curl -fsSL https://github.com/ma-syu/pencil-probe/releases/latest/download/install.sh | sh
#   curl -fsSL ... | sh -s -- 9950                  # non-interactive with port
#   curl -fsSL ... | sh -s uninstall                # uninstall
#
# WHY curl | sh: minimize the number of steps for users.
# Downloads the binary, places it in ~/bin/,
# and registers a system LaunchDaemon — all in one command.
# Requires sudo for /Library/LaunchDaemons/ access.
#
# WHY system LaunchDaemon (not user LaunchAgent):
# VirtualMacOniPad runs macOS in a Virtualization.framework VM where the
# GUI session domain is unstable — it repeatedly enters on-demand-only
# mode, causing user LaunchAgents to spawn/die in a loop. System-level
# LaunchDaemons run in the system domain and are not affected.

# External command dependencies.
# curl/wget: either one is sufficient (OPTIONAL).
# launchctl: macOS-specific but always present on the target platform.
readonly -a REQUIRED_COMMANDS=(launchctl)
readonly -a OPTIONAL_COMMANDS=(curl wget)
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Error: required command not found: ${cmd}" >&2
        exit 1
    fi
done
# Either curl or wget is required
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "Error: curl or wget is required" >&2
    exit 1
fi

REPO="ma-syu/pencil-probe"
BIN_DIR="${HOME}/bin"
BIN="${BIN_DIR}/pencil-probe"
PLIST_NAME="com.pencil-probe.plist"
PLIST_DIR="/Library/LaunchDaemons"
PLIST="${PLIST_DIR}/${PLIST_NAME}"
DEFAULT_PORT=9949

# 旧バージョンの残骸（後方互換のため削除対象として保持）
LEGACY_LAUNCHER="${BIN_DIR}/pencil-probe-launcher.sh"
LEGACY_CONFIG="${HOME}/.config/pencil-probe.conf"
LEGACY_USER_PLIST="${HOME}/Library/LaunchAgents/${PLIST_NAME}"

# --- Uninstall ---
if [ "${1:-}" = "uninstall" ]; then
    echo "=== pencil-probe uninstall ==="

    # Stop and unregister the system LaunchDaemon
    if sudo launchctl list "${PLIST_NAME%.plist}" >/dev/null 2>&1; then
        sudo launchctl bootout "system/${PLIST_NAME%.plist}" 2>/dev/null || true
        echo "  LaunchDaemon stopped"
    fi

    # Clean up legacy user LaunchAgent (v2.x)
    if launchctl list "${PLIST_NAME%.plist}" >/dev/null 2>&1; then
        launchctl bootout "gui/$(id -u)/${PLIST_NAME%.plist}" 2>/dev/null || true
    fi
    rm -f "${LEGACY_USER_PLIST}" && echo "  Removed legacy: ${LEGACY_USER_PLIST}"

    sudo rm -f "${PLIST}" && echo "  Removed: ${PLIST}"
    rm -f "${BIN}"        && echo "  Removed: ${BIN}"
    rm -f "${LEGACY_LAUNCHER}" && echo "  Removed: ${LEGACY_LAUNCHER}"
    rm -f "${LEGACY_CONFIG}"   && echo "  Removed: ${LEGACY_CONFIG}"

    echo "=== Done ==="
    exit 0
fi

echo "=== pencil-probe install ==="

# --- Download binary ---
mkdir -p "${BIN_DIR}"

echo "  Downloading pencil-probe..."
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/pencil-probe"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "${BIN}" "${DOWNLOAD_URL}"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "${BIN}" "${DOWNLOAD_URL}"
else
    echo "Error: curl or wget is required" >&2
    exit 1
fi
chmod +x "${BIN}"
echo "  Installed: ${BIN}"

# --- Clean up legacy files ---
rm -f "${LEGACY_LAUNCHER}"
rm -f "${LEGACY_CONFIG}"
# Migrate from user LaunchAgent (v2.x) to system LaunchDaemon
if [ -f "${LEGACY_USER_PLIST}" ]; then
    launchctl bootout "gui/$(id -u)/${PLIST_NAME%.plist}" 2>/dev/null || true
    rm -f "${LEGACY_USER_PLIST}"
    echo "  Migrated from user LaunchAgent to system LaunchDaemon"
fi

# --- Determine port ---
# Priority: command-line args > existing plist > interactive prompt.
# Vsock needs only a port number. No IP address or access control
# is needed because vsock is VM-internal — only the host (iPad)
# can connect through Virtualization.framework.

PORT=""
OLD_PORT="${DEFAULT_PORT}"

# Read port from existing plist (for re-install)
if [ -f "${PLIST}" ]; then
    # ProgramArguments: [binary, --port, PORT] — PORT は 3 番目の要素
    PLIST_PORT="$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:2" "${PLIST}" 2>/dev/null || true)"
    if [ -n "${PLIST_PORT}" ]; then
        OLD_PORT="${PLIST_PORT}"
    fi
fi

# From command-line arguments
if [ $# -ge 1 ] && [ "${1:-}" != "uninstall" ]; then
    PORT="$1"
fi

# Interactive prompt (only when stdin is a tty and no args given)
if [ -z "${PORT}" ]; then
    if [ -t 0 ]; then
        printf "  Vsock port [%s]: " "${OLD_PORT}"
        read -r PORT
        [ -z "${PORT}" ] && PORT="${OLD_PORT}"
    else
        PORT="${OLD_PORT}"
    fi
fi

PORT="${PORT:-${DEFAULT_PORT}}"

# --- Register system LaunchDaemon ---
# WHY inline generation: plist にバイナリの絶対パスとユーザー名を
# 書き込む必要がある。インストール時に生成する方が確実で、
# BTM に「pencil-probe」と表示される（/bin/sh 経由だと「sh」になる）。
CURRENT_USER="$(id -un)"

sudo tee "${PLIST}" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pencil-probe</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN}</string>
        <string>--port</string>
        <string>${PORT}</string>
    </array>
    <key>UserName</key>
    <string>${CURRENT_USER}</string>
    <key>WorkingDirectory</key>
    <string>${HOME}</string>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/pencil-probe.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/pencil-probe.log</string>
</dict>
</plist>
EOF

# Stop if already running
if sudo launchctl list "${PLIST_NAME%.plist}" >/dev/null 2>&1; then
    sudo launchctl bootout "system/${PLIST_NAME%.plist}" 2>/dev/null || true
fi

sudo launchctl bootstrap system "${PLIST}"
echo "  LaunchDaemon registered and started"

echo ""
echo "=== Done ==="
echo ""
echo "pencil-probe is now running (vsock port ${PORT})."
echo "  Log: /tmp/pencil-probe.log"
echo ""
echo "Two permissions are required (System Settings):"
echo ""
echo "  1. General > Login Items & Extensions"
echo "     Enable 'pencil-probe' under 'Allow in the Background'"
echo ""
echo "  2. Privacy & Security > Accessibility"
echo "     Enable 'pencil-probe'"
