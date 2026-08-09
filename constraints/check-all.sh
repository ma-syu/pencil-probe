#!/usr/bin/env bash
# =============================================================================
# constraints/check-all.sh
#
#   constraints/ 配下の check-*.sh を全て実行し、結果を集計する。
#   個別チェックは「終了コード 0 = PASS、非 0 = FAIL」を守ること。
#
#   このスクリプト自身の終了コードが、プロジェクト全体の合否になる。
#   AI・人間・CI のいずれも、この 1 コマンドで判定できる状態を保つ。
#
#   使い方:
#     ./constraints/check-all.sh          # 全チェック
#     ./constraints/check-all.sh --list   # 一覧のみ表示（実行しない）
# =============================================================================

set -uo pipefail   # -e は付けない。1 つ失敗しても全て実行して集計するため。

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- チェック対象の収集 -----------------------------------------------------

# check-all.sh 自身を除いた check-*.sh を名前順に返す。
collect_checks() {
    local path
    for path in "${SCRIPT_DIR}"/check-*.sh; do
        [[ -f "${path}" ]] || continue
        [[ "$(basename "${path}")" == "check-all.sh" ]] && continue
        printf '%s\n' "${path}"
    done | sort
}

# --- 実行 -------------------------------------------------------------------

main() {
    local path name output status detail
    local passed=0 failed=0
    local -a failures=()

    if [[ "${1:-}" == "--list" ]]; then
        collect_checks | while IFS= read -r path; do
            printf '  %s\n' "$(basename "${path}")"
        done
        return 0
    fi

    cd "${PROJECT_ROOT}" || return 1

    while IFS= read -r path; do
        name="$(basename "${path}" .sh)"

        # 実行権が無いだけで落とさない（clone 直後などを想定）
        if [[ ! -x "${path}" ]]; then
            chmod +x "${path}" 2>/dev/null || true
        fi

        output="$("${path}" 2>&1)"
        status=$?

        if (( status == 0 )); then
            printf '[PASS] %s\n' "${name}"
            (( passed++ ))
        else
            printf '[FAIL] %s\n' "${name}"
            # 失敗時のみ詳細を出す。PASS 時のノイズを避ける。
            #
            # sed でインデントしない理由:
            #   macOS の BSD sed は、ロケールが C や未設定のとき
            #   マルチバイト文字を含む行で "illegal byte sequence" を起こす。
            #   検査の出力には日本語が含まれるため、sed を通すと
            #   そこで処理が止まり、以降の行が失われる。
            while IFS= read -r detail; do
                printf '       %s\n' "${detail}"
            done <<< "${output}"
            failures+=("${name}")
            (( failed++ ))
        fi
    done < <(collect_checks)

    printf '\n'
    if (( passed + failed == 0 )); then
        printf 'チェックが 1 件もありません。constraints/check-*.sh を追加してください。\n' >&2
        return 1
    fi

    printf 'PASS: %d / FAIL: %d\n' "${passed}" "${failed}"

    if (( failed > 0 )); then
        printf '失敗: %s\n' "${failures[*]}" >&2
        return 1
    fi
    return 0
}

main "$@"
