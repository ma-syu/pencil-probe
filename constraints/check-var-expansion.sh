#!/usr/bin/env bash
# =============================================================================
# constraints/check-var-expansion.sh
#
#   シェルスクリプト内で、変数展開の直後に非 ASCII 文字が続く箇所を検出する。
#
#   なぜ必要か:
#     bash は変数名の終端を ASCII の英数字・アンダースコア以外で判定するが、
#     マルチバイト文字の先頭バイトを変数名の一部として拾ってしまう。
#     "ボリューム「$LABEL」は..." と書くと $LABEL」 という変数名になり、
#     set -u 環境では unbound variable エラーで停止する。
#     2026-08-08 に uninstall-upstream-nix-macos.sh で実際に遭遇した。
#
#   対処:
#     文字列内の変数は常に ${VAR} の形で囲む。
#
#   関連知識: knowledge/0001-shell-var-expansion.md
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# $VAR の直後に、変数名として妥当でなく、かつ安全でもない文字が続くパターン。
# 許可する後続文字: 英数字 _ { 空白 " ) / . : , ; = | - '
readonly UNSAFE_PATTERN='\$[A-Za-z_][A-Za-z0-9_]*[^{A-Za-z0-9_ ")/.:,;=|'"'"'-]'

main() {
    local file exit_code=0
    local -a targets=()

    cd "${PROJECT_ROOT}" || return 1

    # git 管理下のシェルスクリプトを対象にする。
    # git が無い / リポジトリでない場合は find にフォールバックする。
    if git rev-parse --git-dir >/dev/null 2>&1; then
        while IFS= read -r file; do
            targets+=("${file}")
        done < <(git ls-files '*.sh')
    else
        while IFS= read -r file; do
            targets+=("${file}")
        done < <(find . -name '*.sh' -not -path './.git/*')
    fi

    if (( ${#targets[@]} == 0 )); then
        printf '対象となる .sh ファイルがありません\n'
        return 0
    fi

    for file in "${targets[@]}"; do
        [[ -f "${file}" ]] || continue

        # コメント行は実行されないため対象外にする。
        # 説明のために「悪い例」をコメントで書くことがあり、
        # それを検出すると自己矛盾する（このスクリプト自身が該当した）。
        # 行番号を保つため grep -n の後に awk でフィルタする。
        if grep -n "${UNSAFE_PATTERN}" "${file}" |
           awk -F: '{ line = $0; sub(/^[0-9]+:/, "", line);
                      if (line !~ /^[[:space:]]*#/) print }' |
           grep .; then
            printf '  ↑ %s: 変数展開を ${VAR} で囲んでください\n' "${file}" >&2
            exit_code=1
        fi
    done

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: 問題なし\n' "${#targets[@]}"
    fi
    return "${exit_code}"
}

main "$@"
