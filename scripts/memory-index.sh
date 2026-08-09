#!/usr/bin/env bash
# =============================================================================
# scripts/memory-index.sh
#
#   knowledge/*.md の front matter を読み、MEMORY.md（索引）を生成する。
#   あわせて各知識の状態を機械的に判定する。
#
#   判定ロジック（全て機械的。人間・AI の主観を入れない）:
#     constraint あり + テスト PASS      → active    有効
#     constraint あり + テスト FAIL      → violated  規約違反 or 制約が古い
#     constraint あり + ファイル無し     → orphaned  リンク切れ
#     constraint なし + 90日以上未参照   → stale     格下げ候補
#     constraint なし + 参照あり         → referenced
#
#   「役に立ったか」は判定不能なので扱わない。
#   知識の生死は、可能な限り constraints/ のテストに紐づけて判定する。
#   紐づけられない知識（単なる事実の記録）は参照実績で代理する。
#
#   MEMORY.md は生成物。直接編集しないこと。
#
#   使い方:
#     ./scripts/memory-index.sh          # MEMORY.md を生成
#     ./scripts/memory-index.sh --audit  # 要対応のものだけ表示
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly KNOWLEDGE_DIR="${PROJECT_ROOT}/knowledge"
readonly ACCESS_LOG="${PROJECT_ROOT}/.memory/access.log"
readonly OUTPUT="${PROJECT_ROOT}/MEMORY.md"
readonly STALE_DAYS=90

# --- front matter の読み取り ------------------------------------------------

# 指定ファイルの front matter から 1 フィールドを取り出す。
# front matter は先頭の --- から次の --- までとする。
read_field() {
    local file="$1" field="$2"
    awk -v key="${field}" '
        NR == 1 && $0 == "---" { inside = 1; next }
        inside && $0 == "---"  { exit }
        inside {
            if (index($0, key ":") == 1) {
                sub("^" key ":[[:space:]]*", "")
                print
                exit
            }
        }
    ' "${file}"
}

# --- 参照実績 ---------------------------------------------------------------

# access.log から、そのファイルが最後に参照された日時を返す（無ければ空）。
last_access() {
    local file="$1"
    [[ -f "${ACCESS_LOG}" ]] || return 0
    grep -F "$(basename "${file}")" "${ACCESS_LOG}" 2>/dev/null |
        tail -1 | cut -f1
}

# 参照回数を返す。
access_count() {
    local file="$1"
    [[ -f "${ACCESS_LOG}" ]] || { printf '0'; return 0; }
    grep -cF "$(basename "${file}")" "${ACCESS_LOG}" 2>/dev/null || printf '0'
}

# --- 状態判定 ---------------------------------------------------------------

# 知識ファイルの状態を判定して返す。
#   active / violated / orphaned / referenced / stale
judge_status() {
    local file="$1"
    local constraint count last epoch_last epoch_now age_days

    constraint="$(read_field "${file}" constraint)"

    if [[ -n "${constraint}" ]]; then
        if [[ ! -f "${PROJECT_ROOT}/${constraint}" ]]; then
            printf 'orphaned'
            return 0
        fi
        if ( cd "${PROJECT_ROOT}" && "./${constraint}" >/dev/null 2>&1 ); then
            printf 'active'
        else
            printf 'violated'
        fi
        return 0
    fi

    # constraint が無い知識は参照実績で判定する
    count="$(access_count "${file}")"
    if [[ "${count}" != "0" ]]; then
        printf 'referenced'
        return 0
    fi

    # 一度も参照されていない場合、作成からの経過日数で判定する
    last="$(read_field "${file}" created)"
    if [[ -n "${last}" ]]; then
        # macOS の date は -j -f、GNU は -d。両方試す。
        epoch_last="$(date -j -f '%Y-%m-%d' "${last}" '+%s' 2>/dev/null ||
                      date -d "${last}" '+%s' 2>/dev/null || printf '')"
        if [[ -n "${epoch_last}" ]]; then
            epoch_now="$(date '+%s')"
            age_days=$(( (epoch_now - epoch_last) / 86400 ))
            if (( age_days >= STALE_DAYS )); then
                printf 'stale'
                return 0
            fi
        fi
    fi
    printf 'unused'
}

# --- 出力 -------------------------------------------------------------------

generate_index() {
    local file id title constraint status count

    {
        printf '# MEMORY.md\n\n'
        printf '`knowledge/` の索引。**このファイルは生成物。直接編集しない。**\n'
        printf '再生成: `./scripts/memory-index.sh`\n\n'
        printf '生成日時: %s\n\n' "$(date '+%F %T')"

        printf '## 状態の意味\n\n'
        printf '| 状態 | 意味 | 対応 |\n'
        printf '|---|---|---|\n'
        printf '| active | 制約テストが PASS | なし |\n'
        printf '| violated | 制約テストが FAIL | **要対応**。規約違反か制約が古い |\n'
        printf '| orphaned | 制約ファイルが存在しない | **要対応**。リンク切れ |\n'
        printf '| referenced | 制約なし・参照実績あり | なし |\n'
        printf '| unused | 制約なし・未参照 | 経過観察 |\n'
        printf '| stale | 制約なし・%d日以上未参照 | 格下げ・削除を検討 |\n\n' "${STALE_DAYS}"

        printf '## 索引\n\n'
        printf '| ID | タイトル | 状態 | 制約 | 参照 |\n'
        printf '|---|---|---|---|---|\n'

        for file in "${KNOWLEDGE_DIR}"/*.md; do
            [[ -f "${file}" ]] || continue
            id="$(read_field "${file}" id)"
            title="$(read_field "${file}" title)"
            constraint="$(read_field "${file}" constraint)"
            status="$(judge_status "${file}")"
            count="$(access_count "${file}")"

            printf '| [%s](%s) | %s | %s | %s | %s |\n' \
                "${id:-?}" \
                "knowledge/$(basename "${file}")" \
                "${title:-（タイトル未設定）}" \
                "${status}" \
                "${constraint:-—}" \
                "${count}"
        done
    } > "${OUTPUT}"

    printf 'MEMORY.md を生成しました: %s\n' "${OUTPUT}"
}

# 要対応のものだけ表示する。CI や定期実行で使う。
run_audit() {
    local file status exit_code=0

    for file in "${KNOWLEDGE_DIR}"/*.md; do
        [[ -f "${file}" ]] || continue
        status="$(judge_status "${file}")"
        case "${status}" in
            violated|orphaned)
                printf '[要対応] %s: %s\n' "${status}" "$(basename "${file}")" >&2
                exit_code=1
                ;;
            stale)
                printf '[格下げ候補] %s\n' "$(basename "${file}")"
                ;;
        esac
    done

    (( exit_code == 0 )) && printf '要対応の知識はありません\n'
    return "${exit_code}"
}

# --- メイン -----------------------------------------------------------------

main() {
    if [[ ! -d "${KNOWLEDGE_DIR}" ]]; then
        printf 'knowledge/ がありません\n' >&2
        return 1
    fi

    case "${1:-}" in
        --audit) run_audit ;;
        "")      generate_index ;;
        *)       printf '使い方: %s [--audit]\n' "$0" >&2; return 2 ;;
    esac
}

main "$@"
