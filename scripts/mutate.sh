#!/usr/bin/env bash
# =============================================================================
# scripts/mutate.sh
#
#   簡易ミューテーションテスト。
#   ソースを機械的に改変し、テストが失敗するかを確認する。
#
#   何のためにあるか:
#     カバレッジは「実行されたか」しか測れない。アサーションが無くても
#     100% になる。「テストが意味を持つか」を機械判定できるのは
#     ミューテーションテストだけで、AI が書いたテストの質を
#     人間の目視に頼らず評価する唯一の手段になる。
#
#   判定:
#     変異させてテストが FAIL → その変異は「殺された」= テストが有効
#     変異させてもテストが PASS → その変異は「生存」= テストが不十分
#     生存率 = 生存数 / 変異総数。閾値以下なら PASS。
#
#   限界:
#     等価変異（意味が変わらない改変）を検出できないため、
#     生存率 0% は現実的でない。20% を目安とする。
#     専用ツール（muter 等）が使える環境ならそちらが望ましい。
#
#   使い方:
#     ./scripts/mutate.sh                 # Sources/Core/ を対象
#     ./scripts/mutate.sh --threshold 30  # 閾値を変える
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly CORE_DIR="${PROJECT_ROOT}/Sources/Core"
readonly BACKUP_DIR="${PROJECT_ROOT}/.mutate-backup"

THRESHOLD=20   # 生存率の上限（%）

# 変異ルール。「元|置換」形式。
# 境界条件・符号・論理演算子を狙う。これらは AI が最も見落としやすい。
readonly -a MUTATIONS=(
    '>=|>'
    '<=|<'
    ' > | >= '
    ' < | <= '
    '==|!='
    '&&|||'
    ' + | - '
    'true|false'
)

# テストを実行し、成否を返す。出力は捨てる。
run_tests() {
    ( cd "${PROJECT_ROOT}" && swift test >/dev/null 2>&1 )
}

# 対象ファイルを退避する。
backup_sources() {
    rm -rf "${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
    cp -R "${CORE_DIR}" "${BACKUP_DIR}/"
}

# 退避から復元する。中断時にも必ず呼ぶ。
restore_sources() {
    if [[ -d "${BACKUP_DIR}/Core" ]]; then
        rm -rf "${CORE_DIR}"
        cp -R "${BACKUP_DIR}/Core" "${CORE_DIR}"
    fi
    rm -rf "${BACKUP_DIR}"
}

main() {
    local file rule from to line_num total=0 survived=0 rate

    if [[ "${1:-}" == "--threshold" && -n "${2:-}" ]]; then
        THRESHOLD="$2"
    fi

    if [[ ! -d "${CORE_DIR}" ]]; then
        printf 'Sources/Core/ がまだありません（着手前として PASS）\n'
        return 0
    fi

    cd "${PROJECT_ROOT}" || return 1

    # 前提: 変異前のテストが通っていること。
    # 通っていない状態で始めると、全ての変異が「殺された」ように見える。
    printf '変異前のテストを確認中...\n'
    if ! run_tests; then
        printf 'テストが失敗しています。先に修正してください。\n' >&2
        return 1
    fi

    backup_sources
    # 中断されても必ず復元する
    trap restore_sources EXIT INT TERM

    while IFS= read -r file; do
        for rule in "${MUTATIONS[@]}"; do
            from="${rule%%|*}"
            to="${rule#*|}"

            # 該当する行を 1 つずつ変異させる
            while IFS= read -r line_num; do
                [[ -n "${line_num}" ]] || continue

                # 1 行だけ置換する（sed のアドレス指定）
                sed -i '' "${line_num}s|${from}|${to}|" "${file}" 2>/dev/null || continue
                (( total++ ))

                if run_tests; then
                    (( survived++ ))
                    printf '  生存: %s:%s (%s → %s)\n' \
                        "$(basename "${file}")" "${line_num}" "${from}" "${to}"
                fi

                # この 1 変異を巻き戻してから次へ
                cp "${BACKUP_DIR}/Core/$(basename "${file}")" "${file}" 2>/dev/null || true
            done < <(grep -nF "${from}" "${file}" 2>/dev/null | cut -d: -f1)
        done
    done < <(find "${CORE_DIR}" -name '*.swift' -type f)

    restore_sources
    trap - EXIT INT TERM

    if (( total == 0 )); then
        printf '変異対象がありませんでした\n'
        return 0
    fi

    rate=$(( survived * 100 / total ))
    printf '\n変異 %d 件 / 生存 %d 件 / 生存率 %d%%（閾値 %d%%）\n' \
        "${total}" "${survived}" "${rate}" "${THRESHOLD}"

    if (( rate > THRESHOLD )); then
        printf '生存率が閾値を超えています。テストを追加してください。\n' >&2
        return 1
    fi
    return 0
}

main "$@"
