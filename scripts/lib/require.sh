#!/usr/bin/env bash
# =============================================================================
# scripts/lib/require.sh
#
#   スクリプトが依存する外部コマンド・環境変数を「宣言」し、
#   その宣言を実行時の検証に使うための共有ライブラリ。
#
#   なぜ宣言させるか:
#     確率的生成 AI は暗黙の依存を推測できない。
#     「このスクリプトは diskutil がある前提」「git add 済みが前提」は
#     コードのどこにも書かれていないため、環境が変わったときに
#     何が壊れるか予測できず、原因の切り分けもできない。
#
#   なぜ「文書に書く」では不十分か:
#     文書の依存表は、コードが変わっても自動では更新されない。
#     必ず腐る。宣言が**実際の動作に必要**であれば腐らない。
#
#     Rust の所有権や ECS のシステム宣言が腐らないのは、
#     宣言しないとコンパイルが通らない／スケジューラが動かないため。
#     同じ性質をシェルで再現する。
#
#   使い方:
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/require.sh"
#
#     readonly -a REQUIRED_COMMANDS=(git awk grep)
#     readonly -a REQUIRED_ENV=(CLAUDE_PROJECT_DIR)
#     require_commands "${REQUIRED_COMMANDS[@]}"
#     require_env "${REQUIRED_ENV[@]}"
#
#   静的検査:
#     constraints/check-declared-deps.sh が、スクリプト内で実際に
#     呼ばれているコマンドと REQUIRED_COMMANDS を照合する。
#     宣言漏れがあれば FAIL する。
# =============================================================================

# 外部コマンドの存在を検証する。
#
# 見つからないコマンドをすべて列挙してから停止する。
# 1 つずつ報告して止まると、環境構築のたびに実行し直すことになるため。
require_commands() {
    local command_name missing=0
    local -a absent=()

    for command_name in "$@"; do
        if ! command -v "${command_name}" >/dev/null 2>&1; then
            absent+=("${command_name}")
            (( missing++ ))
        fi
    done

    (( missing == 0 )) && return 0

    {
        printf '必要なコマンドが見つかりません: %s\n' "${absent[*]}"
        printf '\n'
        printf 'このスクリプトは上記のコマンドに依存しています。\n'
        printf 'インストールするか、環境を確認してください。\n'
        printf '一時的に使うなら: nix shell nixpkgs#<名前>\n'
    } >&2
    return 1
}

# 環境変数が設定されていることを検証する。
#
# 空文字列も未設定として扱う。空を許容したい場合は
# 呼び出し側で個別に判定すること（意図が曖昧になるため）。
require_env() {
    local name missing=0
    local -a absent=()

    for name in "$@"; do
        if [[ -z "${!name:-}" ]]; then
            absent+=("${name}")
            (( missing++ ))
        fi
    done

    (( missing == 0 )) && return 0

    {
        printf '必要な環境変数が設定されていません: %s\n' "${absent[*]}"
        printf '\n'
        printf 'このスクリプトは上記の環境変数に依存しています。\n'
    } >&2
    return 1
}

# git リポジトリであることを検証する。
#
# 「git 管理下のファイルを対象にする」検査で頻出する前提。
# 暗黙にしておくと「対象ファイルがありません」という
# 誤解を招くメッセージが出る（実際に発生した）。
require_git_repo() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        return 0
    fi
    {
        printf 'git リポジトリではありません。\n'
        printf '\n'
        printf 'このスクリプトは git 管理下のファイルを対象にします。\n'
        printf '先に git init を実行してください。\n'
    } >&2
    return 1
}

# git の index に変更が反映されていることを検証する。
#
# git ls-files は index を見るため、新規ファイルを作っただけでは
# 検査対象に入らない。「検査したのに問題が見つからない」という
# 最も気づきにくい失敗を防ぐ。
require_git_staged() {
    require_git_repo || return 1

    if [[ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
        return 0
    fi

    {
        printf '未追跡のファイルがあります。\n'
        printf '\n'
        printf 'git ls-files は index を見るため、これらは検査対象外です。\n'
        printf '検査したのに問題が見つからない、という誤解を招きます。\n'
        printf '先に git add -A を実行してください。\n'
        printf '\n'
        printf '対象:\n'
        git ls-files --others --exclude-standard 2>/dev/null |
            head -10 | sed 's/^/  /'
    } >&2
    return 1
}
