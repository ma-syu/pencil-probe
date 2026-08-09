#!/usr/bin/env bash
# =============================================================================
# scripts/rule-audit.sh
#
#   どの規約が実際に守られていないかを実測から集計する。
#
#   何のためにあるか:
#     CLAUDE.md をどう整理するかを、行数ではなく実測で決めるため。
#     本来の目的は「短いこと」ではなく「AI がコードを破壊せず
#     自律イテレーションを継続できること」。
#     行数は代理指標に過ぎず、根拠のある数字ではない。
#
#   何が分かるか:
#     - 頻繁に違反される検査 → 規約の書き方が悪いか目立たない。強化する
#     - 一度も違反されない検査 → CLAUDE.md から削り、検査だけに任せられる
#     - CLAUDE.md にあるが検査が無い項目 → 検査を追加できないか検討する
#
#   何が分からないか:
#     「違反されなかった」のが、規約が効いたからか、
#     そもそもその状況に遭遇しなかったからかは区別できない。
#     判断材料であって、判断そのものではない。
#
#   使い方:
#     ./scripts/rule-audit.sh
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly VIOLATION_LOG="${PROJECT_ROOT}/.memory/violations.log"
readonly CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"

# --- 違反回数の集計 ---------------------------------------------------------

report_violations() {
    printf '## 違反された検査（多い順）\n\n'

    if [[ ! -f "${VIOLATION_LOG}" ]]; then
        printf '記録なし。まだ一度も FAIL していないか、運用前です。\n\n'
        return 0
    fi

    local total
    total="$(wc -l < "${VIOLATION_LOG}" | tr -d ' ')"

    if [[ "${total}" == "0" ]]; then
        printf '記録なし。\n\n'
        return 0
    fi

    printf '| 回数 | 検査 | 最終違反 |\n'
    printf '|---|---|---|\n'

    # 検査名ごとに回数と最終日時を集計する
    cut -f2 "${VIOLATION_LOG}" | sort -u | while IFS= read -r name; do
        [[ -n "${name}" ]] || continue
        local count last
        count="$(grep -cF "	${name}" "${VIOLATION_LOG}" 2>/dev/null || printf '0')"
        last="$(grep -F "	${name}" "${VIOLATION_LOG}" 2>/dev/null | tail -1 | cut -f1)"
        printf '| %s | %s | %s |\n' "${count}" "${name}" "${last:-—}"
    done | sort -rn

    printf '\n合計 %s 件\n\n' "${total}"
}

# --- 一度も違反されていない検査 ---------------------------------------------

report_never_violated() {
    local script name

    printf '## 一度も違反されていない検査\n\n'
    printf 'CLAUDE.md から該当する記述を削り、検査だけに任せられる候補。\n'
    printf 'ただし「遭遇しなかっただけ」の可能性もあるため、削除は慎重に。\n\n'

    for script in "${PROJECT_ROOT}"/constraints/check-*.sh; do
        [[ -f "${script}" ]] || continue
        name="$(basename "${script}" .sh)"
        [[ "${name}" == "check-all" ]] && continue

        if [[ -f "${VIOLATION_LOG}" ]] &&
           grep -qF "	${name}" "${VIOLATION_LOG}" 2>/dev/null; then
            continue
        fi
        printf -- '- %s\n' "${name}"
    done
    printf '\n'
}

# --- 検査されていない規約 ---------------------------------------------------

# CLAUDE.md の見出しのうち、対応する検査が無さそうなものを列挙する。
# 完全な判定はできないので、あくまで見直しのきっかけとして出す。
report_unchecked_rules() {
    printf '## 検査で裏付けられていない可能性のある節\n\n'
    printf 'CLAUDE.md の見出しのうち、constraints/ に対応が見当たらないもの。\n'
    printf '検査を追加できるなら追加し、できないなら文書に残す必要がある。\n\n'

    [[ -f "${CLAUDE_MD}" ]] || { printf 'CLAUDE.md がありません\n\n'; return 0; }

    local heading key found script
    while IFS= read -r heading; do
        [[ -n "${heading}" ]] || continue

        # 見出しから検索用のキーワードを作る（記号を除いた最初の語）
        key="$(printf '%s' "${heading}" |
               sed 's/^#*[[:space:]]*//; s/（.*//; s/[[:space:]].*//')"
        [[ -n "${key}" ]] || continue

        found=0
        for script in "${PROJECT_ROOT}"/constraints/check-*.sh; do
            [[ -f "${script}" ]] || continue
            if grep -qF "${key}" "${script}" 2>/dev/null; then
                found=1
                break
            fi
        done

        (( found )) || printf -- '- %s\n' "${heading}"
    done < <(grep '^##[[:space:]]' "${CLAUDE_MD}")

    printf '\n'
}

# --- 参考情報 ---------------------------------------------------------------

report_size() {
    local lines
    [[ -f "${CLAUDE_MD}" ]] || return 0
    lines="$(wc -l < "${CLAUDE_MD}" | tr -d ' ')"

    printf '## 参考: CLAUDE.md の行数\n\n'
    printf '%s 行\n\n' "${lines}"
    printf '行数そのものに根拠のある上限はない。1M context に対して\n'
    printf '100 行程度は誤差であり、実害は「重要な指示が埋もれること」。\n'
    printf '上の集計を見て、守られていない規約を強化し、\n'
    printf '検査で代替できる規約を削る、という判断材料にすること。\n\n'
}

# --- メイン -----------------------------------------------------------------

main() {
    cd "${PROJECT_ROOT}" || return 1

    printf '# 規約の実効性レポート（%s）\n\n' "$(date '+%F %T')"
    report_violations
    report_never_violated
    report_unchecked_rules
    report_size
}

main "$@"
