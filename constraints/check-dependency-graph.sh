#!/usr/bin/env bash
# =============================================================================
# constraints/check-dependency-graph.sh
#
#   モジュール間の依存が一方向であることを検査する。
#
#   なぜ必要か:
#     循環依存があると、どこから読んでも全体を読まないと理解できなくなる。
#     AI にとっては「この関数だけ読めば挙動が確定する」性質が失われ、
#     コンテキストに全体を載せる必要が生じる。
#     一方向であれば、下位層だけを取り出して検証できる。
#
#   許可する依存の向き（上位 → 下位のみ）:
#     IO → Core
#     Core → （なし。最下層）
#
#   層を増やす場合は LAYERS と ALLOWED を更新すること。
#   更新を怠ると新しい層が検査対象外になり、検出が働かなくなる。
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly SOURCES_DIR="${PROJECT_ROOT}/Sources"

# 層の一覧（下位から順に並べる）
readonly -a LAYERS=(Core IO)

# 「上位|下位」で許可する依存を列挙する。ここに無い依存は違反とみなす。
readonly -a ALLOWED=(
    'IO|Core'
)

# ある依存が許可されているか判定する。
is_allowed() {
    local from="$1" to="$2" entry
    for entry in "${ALLOWED[@]}"; do
        [[ "${entry}" == "${from}|${to}" ]] && return 0
    done
    return 1
}

# ファイルが属する層名を返す。層外なら空。
layer_of() {
    local file="$1" layer
    for layer in "${LAYERS[@]}"; do
        case "${file}" in
            */Sources/"${layer}"/*) printf '%s' "${layer}"; return 0 ;;
        esac
    done
    return 0
}

main() {
    local file from to exit_code=0 checked=0

    if [[ ! -d "${SOURCES_DIR}" ]]; then
        printf 'Sources/ がまだありません（着手前として PASS）\n'
        return 0
    fi

    cd "${PROJECT_ROOT}" || return 1

    while IFS= read -r file; do
        [[ -f "${file}" ]] || continue
        from="$(layer_of "${file}")"
        [[ -n "${from}" ]] || continue
        (( checked++ ))

        # import 文から依存先の層を拾う。
        # コメント行は除外する（説明として書く場合があるため）。
        while IFS= read -r to; do
            [[ -n "${to}" ]] || continue
            # 自分自身の層への import は無害
            [[ "${to}" == "${from}" ]] && continue

            # 層として管理していない名前（Foundation 等）は対象外
            local known=0 layer
            for layer in "${LAYERS[@]}"; do
                [[ "${to}" == "${layer}" ]] && known=1
            done
            (( known )) || continue

            if ! is_allowed "${from}" "${to}"; then
                printf '%s: %s → %s は許可されていません\n' \
                    "${file#${PROJECT_ROOT}/}" "${from}" "${to}" >&2
                exit_code=1
            fi
        done < <(grep -E '^[[:space:]]*import[[:space:]]+' "${file}" |
                 grep -v '^[[:space:]]*//' |
                 sed -E 's/^[[:space:]]*import[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/')
    done < <(find "${SOURCES_DIR}" -name '*.swift' -type f)

    if (( checked == 0 )); then
        printf 'Sources/ に対象ファイルがありません\n'
        return 0
    fi

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: 依存の向きに問題なし\n' "${checked}"
    fi
    return "${exit_code}"
}

main "$@"
