#!/bin/sh
set -eu

# install.sh — pencil-probe のインストール・アンインストール
#
# Usage:
#   curl -fsSL https://github.com/ma-syu/pencil-probe/releases/latest/download/install.sh | sh
#   curl -fsSL ... | sh -s -- 192.168.1.2          # IP 指定（非対話）
#   curl -fsSL ... | sh -s -- 192.168.1.2 9950     # IP + ポート指定
#   curl -fsSL ... | sh -s uninstall                # アンインストール
#
# WHY curl | sh: ユーザが最小の手順でインストールできるようにする。
# バイナリのダウンロード、配置、LaunchAgent 登録を 1 コマンドで完了する。

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

# --- アンインストール ---
if [ "${1:-}" = "uninstall" ]; then
    echo "=== pencil-probe uninstall ==="

    # LaunchAgent を停止・解除
    if launchctl list "${PLIST_NAME%.plist}" >/dev/null 2>&1; then
        launchctl bootout "gui/$(id -u)" "${PLIST}" 2>/dev/null || true
        echo "  LaunchAgent stopped"
    fi

    rm -f "${PLIST}"   && echo "  Removed: ${PLIST}"
    rm -f "${BIN}"     && echo "  Removed: ${BIN}"
    rm -f "${LAUNCHER}" && echo "  Removed: ${LAUNCHER}"

    # config は残す（再インストール時に設定を引き継ぐため）
    if [ -f "${CONFIG}" ]; then
        echo "  Kept: ${CONFIG} (remove manually if not needed)"
    fi

    echo "=== Done ==="
    exit 0
fi

echo "=== pencil-probe install ==="

# --- バイナリのダウンロード ---
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

# --- ラッパースクリプトのダウンロード ---
LAUNCHER_URL="https://github.com/${REPO}/releases/latest/download/pencil-probe-launcher.sh"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "${LAUNCHER}" "${LAUNCHER_URL}"
else
    wget -qO "${LAUNCHER}" "${LAUNCHER_URL}"
fi
chmod +x "${LAUNCHER}"
echo "  Installed: ${LAUNCHER}"

# --- 設定ファイルの作成 ---
# 引数で IP/ポートが指定されていればそれを使う。
# なければ既存の config からデフォルト値を読む。
# どちらもなければ対話的に聞く。

LISTEN=""
PORT=""

# 既存の config があればデフォルト値として読む
if [ -f "${CONFIG}" ]; then
    . "${CONFIG}" 2>/dev/null || true
    OLD_LISTEN="${LISTEN:-}"
    OLD_PORT="${PORT:-${DEFAULT_PORT}}"
    LISTEN=""
    PORT=""
else
    OLD_LISTEN=""
    OLD_PORT="${DEFAULT_PORT}"
fi

# 引数から取得
if [ $# -ge 1 ] && [ "${1:-}" != "uninstall" ]; then
    LISTEN="$1"
fi
if [ $# -ge 2 ]; then
    PORT="$2"
fi

# 対話的に聞く（引数がなく、tty が使える場合）
if [ -z "${LISTEN}" ]; then
    if [ -t 0 ]; then
        if [ -n "${OLD_LISTEN}" ]; then
            printf "  Listen IP [%s]: " "${OLD_LISTEN}"
        else
            printf "  Listen IP (guest macOS IP): "
        fi
        read -r LISTEN
        [ -z "${LISTEN}" ] && LISTEN="${OLD_LISTEN}"
    else
        LISTEN="${OLD_LISTEN}"
    fi
fi

if [ -z "${PORT}" ]; then
    if [ -t 0 ]; then
        printf "  Port [%s]: " "${OLD_PORT}"
        read -r PORT
        [ -z "${PORT}" ] && PORT="${OLD_PORT}"
    else
        PORT="${OLD_PORT}"
    fi
fi

# IP が空なら中断（必須）
if [ -z "${LISTEN}" ]; then
    echo "Error: Listen IP is required." >&2
    echo "  Re-run with: sh install.sh <guest-ip>" >&2
    # バイナリは入ったので config だけ作ればよい
    exit 1
fi

mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG}" <<EOF
# pencil-probe configuration
# Edit this file and restart the LaunchAgent to apply changes:
#   launchctl kickstart -k gui/\$(id -u)/com.pencil-probe
LISTEN=${LISTEN}
PORT=${PORT:-${DEFAULT_PORT}}
EOF
echo "  Config: ${CONFIG} (LISTEN=${LISTEN}, PORT=${PORT:-${DEFAULT_PORT}})"

# --- LaunchAgent の登録 ---
mkdir -p "${PLIST_DIR}"

PLIST_URL="https://github.com/${REPO}/releases/latest/download/${PLIST_NAME}"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "${PLIST}" "${PLIST_URL}"
else
    wget -qO "${PLIST}" "${PLIST_URL}"
fi

# 既に動いていたら停止
if launchctl list "${PLIST_NAME%.plist}" >/dev/null 2>&1; then
    launchctl bootout "gui/$(id -u)" "${PLIST}" 2>/dev/null || true
fi

launchctl bootstrap "gui/$(id -u)" "${PLIST}"
echo "  LaunchAgent registered and started"

echo ""
echo "=== Done ==="
echo ""
echo "pencil-probe is now running."
echo "  Config: ${CONFIG}"
echo "  Log:    /tmp/pencil-probe.log"
echo ""
echo "Accessibility permission is required."
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Enable 'pencil-probe'"
