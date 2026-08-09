#!/usr/bin/env bash
# =============================================================================
# constraints/check-shell-hygiene.sh
#
#   シェルスクリプトの最低限の品質を検査する。
#     1. 構文が通ること（bash -n）
#     2. set -u 系のオプションが設定されていること
#
#   なぜ必要か:
#     set -u が無いと、未定義変数が空文字列として静かに通過する。
#     check-var-expansion.sh が検出する問題も、set -u が無ければ
#     エラーにならず、意図しない引数でコマンドが実行される。
#     「静かに間違う」より「大声で止まる」方が、AI 協働では安全。
#
#   set -e を必須にしていないのは、集計型スクリプト（1 つ失敗しても
#   最後まで走らせたいもの）では意図的に外す場合があるため。
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 検査対象のシェルスクリプト一覧を返す。
# 外部から取得したもの（インストーラ等）は対象外にする。
collect_targets() {
    local file
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git ls-files '*.sh'
    else
        find . -name '*.sh' -not -path './.git/*'
    fi | while IFS= read -r file; do
        # 上流から取得したインストーラは自分たちの規約の対象外
        case "$(basename "${file}")" in
            nix-install.sh) continue ;;
        esac
        printf '%s\n' "${file}"
    done
}

main() {
    local file detail exit_code=0 checked=0

    cd "${PROJECT_ROOT}" || return 1

    while IFS= read -r file; do
        [[ -f "${file}" ]] || continue
        (( checked++ ))

        # 1. 構文チェック
        if ! bash -n "${file}" 2>/dev/null; then
            printf '%s: 構文エラー\n' "${file}" >&2
            # sed でインデントしない（BSD sed がマルチバイトで落ちるため）
            while IFS= read -r detail; do
                printf '    %s\n' "${detail}" >&2
            done < <(bash -n "${file}" 2>&1)
            exit_code=1
            continue
        fi

        # 2. set -u が有効か（-uo pipefail / -euo pipefail のいずれか）
        if ! grep -qE '^\s*set\s+-[a-z]*u' "${file}"; then
            printf '%s: set -u が設定されていません\n' "${file}" >&2
            exit_code=1
        fi
    done < <(collect_targets)

    if (( checked == 0 )); then
        printf '対象となる .sh ファイルがありません\n'
        return 0
    fi

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: 問題なし\n' "${checked}"
    fi
    return "${exit_code}"
}

main "$@"
