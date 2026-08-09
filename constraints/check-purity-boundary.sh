#!/usr/bin/env bash
# =============================================================================
# constraints/check-purity-boundary.sh
#
#   Sources/Core/ に副作用が漏れていないかを検査する。
#
#   なぜ必要か:
#     純粋な関数は、周囲の文脈を知らずに正しさを判定できる。
#     これは限られたコンテキストで作業する AI にとって決定的に重要で、
#     「この関数だけ読めば挙動が確定する」状態を保てるかどうかが、
#     自動イテレーションの安全性を左右する。
#
#   限界（正直に書いておく）:
#     Swift には副作用を型で追跡する仕組みがない。
#     ここで検査できるのは「禁止 API の不使用」であって、
#     「純粋であること」の証明ではない。
#     それでも、危険な API を機械的に締め出せば大半の事故は防げる。
#
#   Sources/Core/ が存在しない間は PASS を返す（着手前でも動くように）。
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly CORE_DIR="${PROJECT_ROOT}/Sources/Core"

# Core/ で使ってはいけないシンボル。「パターン|理由」形式。
readonly -a FORBIDDEN=(
    '\bprint[[:space:]]*\(@@出力は IO/ の責務。値を返して呼び出し側で出力すること'
    '\bNSLog[[:space:]]*\(@@同上'
    '\bFileManager\b@@ファイル操作は IO/ へ'
    '\bURLSession\b@@通信は IO/ へ'
    '\bDate[[:space:]]*\(\)@@現在時刻は引数で受け取ること。テストが不安定になる'
    '\bUUID[[:space:]]*\(\)@@乱数は引数で受け取ること。テストが不安定になる'
    '\bDispatchQueue\b@@並行処理は IO/ へ'
    '\bNotificationCenter\b@@暗黙の依存になる。引数で渡すこと'
    '\bCGEvent[A-Za-z]*\b@@イベント注入は IO/ の責務'
    '^import IO$@@Core は IO に依存してはならない（依存は一方向）'
    '^[[:space:]]*(public[[:space:]]+)?class[[:space:]]@@参照型は共有状態を生む。struct を使うこと'
)

main() {
    local file rule pattern reason exit_code=0 checked=0

    if [[ ! -d "${CORE_DIR}" ]]; then
        printf 'Sources/Core/ がまだありません（着手前として PASS）\n'
        return 0
    fi

    cd "${PROJECT_ROOT}" || return 1

    while IFS= read -r file; do
        [[ -f "${file}" ]] || continue
        (( checked++ ))

        for rule in "${FORBIDDEN[@]}"; do
            pattern="${rule%%@@*}"
            reason="${rule#*@@}"

            # コメント行は除外する
            if grep -nE "${pattern}" "${file}" |
               awk -F: '{ line = $0; sub(/^[0-9]+:/, "", line);
                          if (line !~ /^[[:space:]]*(\/\/|\/\*|\*)/) print }' |
               grep .; then
                printf '  ↑ %s: %s\n' "${file}" "${reason}" >&2
                exit_code=1
            fi
        done
    done < <(find "${CORE_DIR}" -name '*.swift' -type f)

    if (( checked == 0 )); then
        printf 'Sources/Core/ に .swift がありません\n'
        return 0
    fi

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: 副作用の漏れなし\n' "${checked}"
    fi
    return "${exit_code}"
}

main "$@"
