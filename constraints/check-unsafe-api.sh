#!/usr/bin/env bash
# =============================================================================
# constraints/check-unsafe-api.sh
#
#   実害に直結する危険な API の使用を検出する。
#
#   なぜ必要か:
#     この環境はブリッジネットワークで LAN に直結している。
#     入力注入（マウス・キーボードイベント）を扱うプログラムを書くため、
#     0.0.0.0 でリッスンすると LAN 上の任意の機器からゲストを操作できる。
#     これは理論上のリスクではなく、実際に到達可能な攻撃経路になる。
#
#   検出対象は「静的に判定でき、かつ代替手段が明確なもの」に限る。
#   曖昧な指摘は偽陽性を生み、検査そのものが無視されるようになる。
#
#   関連: OWASP A01（アクセス制御の不備）、A03（インジェクション）
#         CWE-78, CWE-120, CWE-676
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 「パターン|理由」の形で定義する。理由を出力に含めることで、
# 指摘を受けた側が代替手段を判断できるようにする。
readonly -a RULES=(
    '0\.0\.0\.0@@LAN 全体から到達可能になる。127.0.0.1 か特定 IP を使うこと'
    'INADDR_ANY@@同上。明示的なアドレスを指定すること'
    '\bsystem[[:space:]]*\(@@コマンドインジェクションの危険。posix_spawn か Process を使うこと'
    '\bpopen[[:space:]]*\(@@同上'
    '\bstrcpy[[:space:]]*\(@@境界チェックなし。strlcpy を使うこと'
    '\bstrcat[[:space:]]*\(@@境界チェックなし。strlcat を使うこと'
    '\bsprintf[[:space:]]*\(@@境界チェックなし。snprintf を使うこと'
    '\bgets[[:space:]]*\(@@境界チェックなし。fgets を使うこと'
)

# 検査対象はソースコードのみ。この検査スクリプト自身とドキュメントは除く。
collect_targets() {
    local file
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git ls-files '*.swift' '*.m' '*.h' '*.c' '*.mm'
    else
        find . \( -name '*.swift' -o -name '*.m' -o -name '*.h' \
                  -o -name '*.c' -o -name '*.mm' \) -not -path './.git/*'
    fi
}

main() {
    local file rule pattern reason exit_code=0 checked=0

    cd "${PROJECT_ROOT}" || return 1

    while IFS= read -r file; do
        [[ -f "${file}" ]] || continue
        (( checked++ ))

        for rule in "${RULES[@]}"; do
            pattern="${rule%%@@*}"
            reason="${rule#*@@}"

            # コメント行は除外する（説明として書く場合があるため）
            if grep -nE "${pattern}" "${file}" |
               awk -F: '{ line = $0; sub(/^[0-9]+:/, "", line);
                          if (line !~ /^[[:space:]]*(\/\/|\/\*|\*)/) print }' |
               grep .; then
                printf '  ↑ %s: %s\n' "${file}" "${reason}" >&2
                exit_code=1
            fi
        done
    done < <(collect_targets)

    if (( checked == 0 )); then
        printf '対象となるソースファイルがまだありません\n'
        return 0
    fi

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: 問題なし\n' "${checked}"
    fi
    return "${exit_code}"
}

main "$@"
