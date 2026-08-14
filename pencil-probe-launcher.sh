#!/bin/sh
# pencil-probe-launcher.sh
# LaunchAgent から呼ばれ、config を読んでバイナリを起動する。
#
# WHY ラッパー: LaunchAgent の plist は静的 XML で変数を使えない。
# config ファイルを読むことで、plist を再登録せずに
# IP/ポートを変更できる。

CONFIG="${HOME}/.config/pencil-probe.conf"

if [ ! -f "${CONFIG}" ]; then
    echo "Config not found: ${CONFIG}" >&2
    echo "Run install.sh or create the file manually:" >&2
    echo "  LISTEN=<guest-ip>" >&2
    echo "  PORT=9949" >&2
    exit 1
fi

# config を読み込む。LISTEN と PORT が定義される。
. "${CONFIG}"

# WHY exec: ラッパーのプロセスをバイナリで置き換える。
# launchctl が管理する PID が直接 pencil-probe を指すので、
# シグナル配送や KeepAlive の再起動判定が正しく動く。
exec "${HOME}/bin/pencil-probe" \
    --listen "${LISTEN:-127.0.0.1}" \
    --port "${PORT:-9949}"
