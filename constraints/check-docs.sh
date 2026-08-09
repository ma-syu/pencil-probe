#!/usr/bin/env bash
# =============================================================================
# constraints/check-docs.sh
#
#   文書が腐るのを機械的に防ぐ。
#
#   なぜ行数を検査しないか（重要）:
#     以前は CLAUDE.md に 120 行の上限を設けていたが、これを撤廃した。
#     命名規約を追加した際に上限を超え、**正確性のために書いた説明を
#     削って行数に収める**という判断をしてしまったため。
#
#     目的は「短いこと」ではなく、AI がコードを破壊せず
#     自律イテレーションを継続できること。行数はその代理指標だが、
#     目的と方向が一致していない。削るほど AI が判断できなくなる。
#     代理指標を強制すると、目的から遠ざかる方向へ最適化が働く。
#
#     詳細: ~/.claude/docs/iteration.md の「行数上限で判断を誤った実例」
#
#   代わりに検査する 4 点（いずれも「読めない・腐る」に直結する）:
#     1. リンク切れ           — 参照できない文書は無いのと同じ
#     2. 孤立した文書         — 索引から辿れない文書は読まれない
#     3. 未記載の検査         — 誰も知らない検査は、失敗時に理由が分からない
#     4. 二重管理             — 同じ規約が複数箇所にあると片方が腐る
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly CLAUDE_MD="${PROJECT_ROOT}/CLAUDE.md"
readonly DOCS_DIR="${PROJECT_ROOT}/docs"

# 全プロジェクト共通の規約。Claude Code が自動で読み込む。
# プロジェクト側と合わせて実質的な規約の総量になるため、
# 片方だけを見ても実態は分からない。
readonly GLOBAL_CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
readonly GLOBAL_DOCS_DIR="${HOME}/.claude/docs"

# 文書とみなすファイル。参照関係はここから辿る。
collect_docs() {
    printf '%s\n' "${CLAUDE_MD}"
    [[ -d "${DOCS_DIR}" ]] && find "${DOCS_DIR}" -name '*.md' -type f
    [[ -f "${GLOBAL_CLAUDE_MD}" ]] && printf '%s\n' "${GLOBAL_CLAUDE_MD}"
    [[ -d "${GLOBAL_DOCS_DIR}" ]] && find "${GLOBAL_DOCS_DIR}" -name '*.md' -type f
    return 0
}

# --- 1. 共通側の存在 --------------------------------------------------------

# プロジェクト側が共通側を参照しているのに実体が無ければ、
# そこに書かれているはずの規約が適用されていない状態になる。
# 規約に穴があることに誰も気づけないため、明示的に検出する。
check_global_exists() {
    [[ -f "${CLAUDE_MD}" ]] || {
        printf 'CLAUDE.md がありません\n' >&2
        return 1
    }

    if [[ -f "${GLOBAL_CLAUDE_MD}" ]]; then
        return 0
    fi

    if grep -q '\.claude/CLAUDE\.md' "${CLAUDE_MD}" 2>/dev/null; then
        printf '%s がありません。\n' "${GLOBAL_CLAUDE_MD}" >&2
        printf '  CLAUDE.md が共通側を参照していますが、実体がありません。\n' >&2
        printf '  そこに書かれているはずの規約が適用されていません。\n' >&2
        return 1
    fi
    return 0
}

# --- 2. リンク切れ -----------------------------------------------------------

check_links() {
    local doc link dir exit_code=0

    while IFS= read -r doc; do
        [[ -f "${doc}" ]] || continue
        dir="$(dirname "${doc}")"

        while IFS= read -r link; do
            [[ -n "${link}" ]] || continue
            case "${link}" in
                http*|\#*) continue ;;
            esac

            # ~/ 記法を展開して確認する
            local expanded="${link/#\~/${HOME}}"

            if [[ -e "${dir}/${link}" || -e "${PROJECT_ROOT}/${link}" ||
                  -e "${expanded}" ]]; then
                continue
            fi

            printf '%s: リンク切れ → %s\n' \
                "${doc/#${HOME}/\~}" "${link}" >&2
            exit_code=1
        done < <(grep -oE '\]\([^)#]+\)' "${doc}" 2>/dev/null |
                 sed -E 's/^\]\(//; s/\)$//')
    done < <(collect_docs)

    return "${exit_code}"
}

# --- 3. 未記載の検査スクリプト ----------------------------------------------

check_orphan_constraints() {
    local script name exit_code=0 all_docs

    all_docs="$(collect_docs | tr '\n' ' ')"

    for script in "${SCRIPT_DIR}"/check-*.sh; do
        [[ -f "${script}" ]] || continue
        name="$(basename "${script}")"
        [[ "${name}" == "check-all.sh" ]] && continue
        [[ "${name}" == "check-docs.sh" ]] && continue

        # shellcheck disable=SC2086
        if ! grep -qF "${name}" ${all_docs} 2>/dev/null; then
            printf 'constraints/%s がどの文書でも言及されていません\n' "${name}" >&2
            printf '  誰も知らない検査は、失敗したとき理由が分かりません。\n' >&2
            printf '  CLAUDE.md か docs/ で触れてください。\n' >&2
            exit_code=1
        fi
    done

    return "${exit_code}"
}

# --- 4. 孤立した文書 ---------------------------------------------------------

# 索引から辿れない文書は読まれず、やがて腐る。
# プロジェクト側・共通側それぞれで、対応する CLAUDE.md からの
# 到達可能性を確認する。
check_orphan_docs() {
    local doc name exit_code=0

    _check_dir() {
        local dir="$1" index="$2" doc name
        [[ -d "${dir}" ]] || return 0
        [[ -f "${index}" ]] || return 0

        while IFS= read -r doc; do
            [[ -f "${doc}" ]] || continue
            name="$(basename "${doc}")"

            if ! grep -qF "${name}" "${index}" 2>/dev/null; then
                printf '%s が %s から参照されていません\n' \
                    "${doc/#${HOME}/\~}" "${index/#${HOME}/\~}" >&2
                printf '  参照されない文書は読まれず、やがて腐ります。\n' >&2
                return 1
            fi
        done < <(find "${dir}" -name '*.md' -type f)
        return 0
    }

    _check_dir "${DOCS_DIR}" "${CLAUDE_MD}" || exit_code=1
    _check_dir "${GLOBAL_DOCS_DIR}" "${GLOBAL_CLAUDE_MD}" || exit_code=1

    return "${exit_code}"
}

# --- 5. 二重管理 -------------------------------------------------------------

# 同じ見出しが共通側とプロジェクト側の両方にあると、
# どちらが正か分からなくなり、片方が必ず腐る。
#
# 見出しの完全一致のみを検出する。部分的な重複は判定不能なので、
# ここで拾えるのは明らかな重複だけ。
check_duplication() {
    local heading exit_code=0

    [[ -f "${GLOBAL_CLAUDE_MD}" ]] || return 0
    [[ -f "${CLAUDE_MD}" ]] || return 0

    while IFS= read -r heading; do
        [[ -n "${heading}" ]] || continue
        # 「参照先」は両方にあって当然なので除外する
        case "${heading}" in
            '## 参照先'*) continue ;;
        esac

        if grep -qxF "${heading}" "${CLAUDE_MD}" 2>/dev/null; then
            printf '見出しが重複しています: %s\n' "${heading}" >&2
            printf '  共通側とプロジェクト側の両方にあります。\n' >&2
            printf '  どちらが正か分からなくなり、片方が必ず腐ります。\n' >&2
            exit_code=1
        fi
    done < <(grep '^##[[:space:]]' "${GLOBAL_CLAUDE_MD}")

    return "${exit_code}"
}

# --- メイン -----------------------------------------------------------------

main() {
    local exit_code=0

    cd "${PROJECT_ROOT}" || return 1

    check_global_exists      || exit_code=1
    check_links              || exit_code=1
    check_orphan_constraints || exit_code=1
    check_orphan_docs        || exit_code=1
    check_duplication        || exit_code=1

    if (( exit_code == 0 )); then
        local doc_count
        doc_count="$(collect_docs | wc -l | tr -d ' ')"
        printf '文書 %s 件: リンク・参照・重複ともに問題なし\n' "${doc_count}"
    fi
    return "${exit_code}"
}

main "$@"
