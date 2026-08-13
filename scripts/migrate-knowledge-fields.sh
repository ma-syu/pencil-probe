#!/usr/bin/env bash
# =============================================================================
# scripts/migrate-knowledge-fields.sh
#
#   knowledge/ ファイルに記憶システムの必須フィールドを追加する。
#   冪等: 既にフィールドがあれば何もしない。2 回実行しても結果は同じ。
#
#   追加するフィールド:
#     validity: current
#     source_class: observation
#     verified_at:
#     verified_against:
#
#   既存の status: フィールドは残す（memory-index.sh が参照している）。
#   温度システム完成後に status: を廃止する。
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly KNOWLEDGE_DIR="${PROJECT_ROOT}/knowledge"

# ヘッダ領域にフィールドがあるか確認する。
# YAML front matter（--- で囲まれた領域）と plain（最初の空行まで）に対応。
header_has_field() {
    local file="$1" field="$2"
    awk -v f="${field}" '
        NR == 1 && /^---[[:space:]]*$/ { yaml = 1; next }
        yaml && /^---[[:space:]]*$/ { exit }
        !yaml && /^$/ { exit }
        $0 ~ "^" f ":" { found = 1; exit }
        END { exit !found }
    ' "${file}"
}

add_field_if_missing() {
    local file="$1" field="$2" value="$3"
    if header_has_field "${file}" "${field}"; then
        return 0
    fi
    local tmp
    tmp="$(mktemp)"
    # YAML: 閉じ --- の直前に挿入。plain: 最初の空行の直前に挿入。
    awk -v f="${field}" -v v="${value}" '
        NR == 1 && /^---[[:space:]]*$/ { yaml = 1; print; next }
        !inserted && yaml && /^---[[:space:]]*$/ {
            print f ": " v
            inserted = 1
        }
        !inserted && !yaml && /^$/ {
            print f ": " v
            inserted = 1
        }
        { print }
    ' "${file}" > "${tmp}"
    mv "${tmp}" "${file}"
}

main() {
    local file count=0

    for file in "${KNOWLEDGE_DIR}"/*.md; do
        [[ -f "${file}" ]] || continue
        add_field_if_missing "${file}" "validity" "current"
        add_field_if_missing "${file}" "source_class" "observation"
        add_field_if_missing "${file}" "verified_at" ""
        add_field_if_missing "${file}" "verified_against" ""
        count=$(( count + 1 ))
        printf '  %s\n' "$(basename "${file}")"
    done

    printf 'Updated %d files\n' "${count}"
}

main "$@"
