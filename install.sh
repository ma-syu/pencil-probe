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
# Downloads the binary, places it in ~/bin/, creates a config file,
# and registers a LaunchAgent — all in one command.

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
LAUNCHER="${BIN_DIR}/pencil-probe-launcher.sh"
CONFIG_DIR="${HOME}/.config"
CONFIG="${CONFIG_DIR}/pencil-probe.conf"
PLIST_NAME="com.pencil-probe.plist"
PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST="${PLIST_DIR}/${PLIST_NAME}"
DEFAULT_PORT=9949

# --- Uninstall ---
if [ "${1:-}" = "uninstall" ]; then
    echo "=== pencil-probe uninstall ==="

    # Stop and unregister the LaunchAgent
    if launchctl list "${PLIST_NAME%.plist}" >/dev/null 2>&1; then
        launchctl bootout "gui/$(id -u)" "${PLIST}" 2>/dev/null || true
        echo "  LaunchAgent stopped"
    fi

    rm -f "${PLIST}"   && echo "  Removed: ${PLIST}"
    rm -f "${BIN}"     && echo "  Removed: ${BIN}"
    rm -f "${LAUNCHER}" && echo "  Removed: ${LAUNCHER}"

    # Keep the config file so re-install preserves settings
    if [ -f "${CONFIG}" ]; then
        echo "  Kept: ${CONFIG} (remove manually if not needed)"
    fi

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

# --- Download launcher script ---
LAUNCHER_URL="https://github.com/${REPO}/releases/latest/download/pencil-probe-launcher.sh"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "${LAUNCHER}" "${LAUNCHER_URL}"
else
    wget -qO "${LAUNCHER}" "${LAUNCHER_URL}"
fi
chmod +x "${LAUNCHER}"
echo "  Installed: ${LAUNCHER}"

# --- Create config file ---
# Priority: command-line args > existing config > interactive prompt.
# On re-run, existing values are shown as defaults.
#
# Vsock needs only a port number. No IP address or access control
# is needed because vsock is VM-internal — only the host (iPad)
# can connect through Virtualization.framework.

PORT=""

# Read existing config for default values
if [ -f "${CONFIG}" ]; then
    . "${CONFIG}" 2>/dev/null || true
    OLD_PORT="${PORT:-${DEFAULT_PORT}}"
    PORT=""
else
    OLD_PORT="${DEFAULT_PORT}"
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

mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG}" <<EOF
# pencil-probe configuration
# Edit this file and restart the LaunchAgent to apply changes:
#   launchctl kickstart -k gui/\$(id -u)/com.pencil-probe
PORT=${PORT:-${DEFAULT_PORT}}
EOF
echo "  Config: ${CONFIG} (PORT=${PORT:-${DEFAULT_PORT}})"

# --- Register LaunchAgent ---
mkdir -p "${PLIST_DIR}"

PLIST_URL="https://github.com/${REPO}/releases/latest/download/${PLIST_NAME}"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "${PLIST}" "${PLIST_URL}"
else
    wget -qO "${PLIST}" "${PLIST_URL}"
fi

# Stop if already running
if launchctl list "${PLIST_NAME%.plist}" >/dev/null 2>&1; then
    launchctl bootout "gui/$(id -u)" "${PLIST}" 2>/dev/null || true
fi

launchctl bootstrap "gui/$(id -u)" "${PLIST}"
echo "  LaunchAgent registered and started"

echo ""
echo "=== Done ==="
echo ""
echo "pencil-probe is now running (vsock port ${PORT:-${DEFAULT_PORT}})."
echo "  Config: ${CONFIG}"
echo "  Log:    /tmp/pencil-probe.log"
echo ""
echo "Accessibility permission is required."
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Enable 'pencil-probe'"
