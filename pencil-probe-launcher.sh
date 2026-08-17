#!/bin/sh
set -u
# pencil-probe-launcher.sh
# Called by LaunchAgent. Reads config and launches the binary.
#
# WHY a wrapper: LaunchAgent plists are static XML with no variable
# support. This script reads ~/.config/pencil-probe.conf so users can
# change the vsock port without re-registering the LaunchAgent.
#
# WHY set -u only (no pipefail): /bin/sh is POSIX sh where pipefail
# is not available. This script must run under /bin/sh.

CONFIG="${HOME}/.config/pencil-probe.conf"

if [ ! -f "${CONFIG}" ]; then
    echo "Config not found: ${CONFIG}" >&2
    echo "Run install.sh or create the file manually:" >&2
    echo "  PORT=9949" >&2
    exit 1
fi

# Source the config. Defines PORT.
. "${CONFIG}"

# WHY exec: replaces the wrapper process with the binary so that
# the PID launchctl manages points directly to pencil-probe.
# This ensures signals and KeepAlive restart work correctly.
exec "${HOME}/bin/pencil-probe" \
    --port "${PORT:-9949}"
