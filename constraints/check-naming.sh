#!/usr/bin/env bash
# =============================================================================
# constraints/check-naming.sh
#
#   関数名・ファイル名が、何をするものか分からない形になっていないか検査する。
#
#   なぜ必要か（実運用での失敗に基づく）:
#     チケット番号を名前にした関数（fixJIRA1234 など）は、
#     チケットが閉じた後、本人にも何の関数か分からなくなる。
#     追跡システムを移行すれば番号自体が意味を失う。
#     後から直すコストが跳ね上がる。
#
#     AI は文脈を持たないため、この種の名前を見ても
#     何をする関数か推測できず、変更のたびに全体を読む必要が生じる。
#     良い名前は、そのままコンテキスト削減になる。
#
#   検査できないこと:
#     「名前が実態を表しているか」は機械判定できない。
#     ここで潰せるのは「明らかに情報量がゼロの名前」だけ。
#     残りはレビューと docs/comment-style.md の方針に委ねる。
#
#   誤検出への配慮:
#     ループ変数の i / j / x / y は正当なので、局所変数は対象外にする。
#     検査するのは関数名とファイル名のみ。
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 「パターン@@理由」形式。
# 区切りに @@ を使うのは、パターン内の | と衝突するため（knowledge/0002）。
readonly -a BAD_NAME_RULES=(
    '[A-Za-z]+[-_]?[0-9]{3,}@@チケット番号や連番に見えます。何をするものかを名前にしてください'
    '(19|20)[0-9]{6}@@日付が含まれています。いつ作ったかではなく何をするかを名前にしてください'
    '^(tmp|temp|test|data|info|util|misc|stuff|thing|item|obj|val|foo|bar|baz|hoge|fuga)$@@情報量がありません。具体的な役割を名前にしてください'
    '^(func|function|method|proc|do|run|exec|handle|process|manage)[0-9]*$@@何を処理するのかが分かりません'
    '[Ss]tuff|[Tt]hingy?$|[Mm]isc$|[Hh]oge|[Ff]uga|[Pp]iyo@@意味のない語が含まれています。具体的な役割を名前にしてください'
    '^.{1,2}$@@短すぎます。関数名・ファイル名は役割が分かる長さにしてください'
)

# --- 関数名の抽出 -----------------------------------------------------------

# Swift / ObjC / シェルから関数名を「行番号:名前」形式で出力する。
extract_function_names() {
    local file="$1"

    case "${file}" in
        *.swift)
            grep -nE '^[[:space:]]*(public |private |internal |static |)*func[[:space:]]+[A-Za-z_]' "${file}" 2>/dev/null |
                sed -E 's/^([0-9]+):.*func[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1:\2/'
            ;;
        *.m|*.mm|*.c|*.h)
            # ObjC のメソッドと C 関数の両方を拾う
            grep -nE '^[[:space:]]*[-+][[:space:]]*\([^)]+\)[[:space:]]*[A-Za-z_]' "${file}" 2>/dev/null |
                sed -E 's/^([0-9]+):.*\)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*).*/\1:\2/'
            grep -nE '^[[:space:]]*(static[[:space:]]+)?[A-Za-z_][A-Za-z0-9_ *]*[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\(' "${file}" 2>/dev/null |
                sed -E 's/^([0-9]+):.*[[:space:]*]([A-Za-z_][A-Za-z0-9_]*)\(.*/\1:\2/'
            ;;
        *.sh)
            grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{' "${file}" 2>/dev/null |
                sed -E 's/^([0-9]+):[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)\(\).*/\1:\2/'
            ;;
    esac
    return 0
}

# --- 判定 -------------------------------------------------------------------

# 名前が禁止パターンに該当するかを調べ、該当すれば理由を出力する。
# 該当しなければ何も出力せず 1 を返す。
judge_name() {
    local name="$1" rule pattern reason

    for rule in "${BAD_NAME_RULES[@]}"; do
        pattern="${rule%%@@*}"
        reason="${rule#*@@}"

        if [[ "${name}" =~ ${pattern} ]]; then
            printf '%s' "${reason}"
            return 0
        fi
    done
    return 1
}

collect_targets() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git ls-files '*.swift' '*.m' '*.mm' '*.c' '*.h' '*.sh'
    else
        find . \( -name '*.swift' -o -name '*.m' -o -name '*.mm' \
                  -o -name '*.c' -o -name '*.h' -o -name '*.sh' \) \
             -not -path './.git/*'
    fi
}

# --- メイン -----------------------------------------------------------------

main() {
    local file base entry line name reason exit_code=0 checked=0

    cd "${PROJECT_ROOT}" || return 1

    while IFS= read -r file; do
        [[ -f "${file}" ]] || continue
        (( checked++ ))

        # ファイル名（拡張子を除く）
        base="$(basename "${file}")"
        base="${base%.*}"
        if reason="$(judge_name "${base}")"; then
            printf '%s: %s\n' "${file}" "${reason}" >&2
            exit_code=1
        fi

        # 関数名
        while IFS= read -r entry; do
            [[ -n "${entry}" ]] || continue
            line="${entry%%:*}"
            name="${entry#*:}"
            [[ -n "${name}" ]] || continue

            if reason="$(judge_name "${name}")"; then
                printf '%s:%s: 関数 %s — %s\n' \
                    "${file}" "${line}" "${name}" "${reason}" >&2
                exit_code=1
            fi
        done < <(extract_function_names "${file}")
    done < <(collect_targets)

    if (( checked == 0 )); then
        printf '対象ファイルがありません\n'
        return 0
    fi

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: 命名に問題なし\n' "${checked}"
    fi
    return "${exit_code}"
}

main "$@"
