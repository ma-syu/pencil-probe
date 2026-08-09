#!/usr/bin/env bash
# =============================================================================
# constraints/check-secrets.sh
#
#   認証情報がソースコードに混入していないか検査する。
#
#   なぜ必要か:
#     上流へ PR を出す前提のため、一度 push すると git 履歴から
#     完全に消すのは困難になる。混入を「入る前」に止める必要がある。
#     AI は例示のつもりでダミーのトークンを書くことがあり、
#     それが本物と区別できない形で残ることがある。
#
#   gitleaks があればそちらを使う（誤検出が少なく、ルールが充実している）。
#   無い場合は簡易パターンにフォールバックする。
#     nix run nixpkgs#gitleaks -- detect --source . --no-git
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 簡易検出パターン。gitleaks が無い環境向けのフォールバック。
# 誤検出を避けるため、明らかに値が埋まっている形だけを対象にする。
readonly -a PATTERNS=(
    'AKIA[0-9A-Z]{16}'                          # AWS アクセスキー
    'gh[pousr]_[A-Za-z0-9]{36,}'                # GitHub トークン
    'sk-[A-Za-z0-9]{32,}'                       # API キー全般
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'        # 秘密鍵
    '(password|passwd|secret|token|api_key)[[:space:]]*=[[:space:]]*"[^"$][^"]{7,}"'
)

# 検査対象を返す。バイナリとログは除く。
collect_targets() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git ls-files
    else
        find . -type f -not -path './.git/*'
    fi | grep -vE '\.(log|png|jpg|jpeg|gif|pdf|zip|img)$'
}

run_gitleaks() {
    gitleaks detect --source "${PROJECT_ROOT}" --no-git --redact --exit-code 1 \
        2>&1 | tail -20
}

run_fallback() {
    local file pattern exit_code=0 checked=0

    while IFS= read -r file; do
        [[ -f "${file}" ]] || continue
        (( checked++ ))
        for pattern in "${PATTERNS[@]}"; do
            # 値そのものは出力しない。ファイルと行番号だけ報告する。
            if grep -nEq "${pattern}" "${file}" 2>/dev/null; then
                printf '%s: 認証情報らしき記述を検出（パターン: %s）\n' \
                    "${file}" "${pattern}" >&2
                exit_code=1
            fi
        done
    done < <(collect_targets)

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: 問題なし\n' "${checked}"
    fi
    return "${exit_code}"
}

main() {
    cd "${PROJECT_ROOT}" || return 1

    if command -v gitleaks >/dev/null 2>&1; then
        run_gitleaks
    else
        run_fallback
    fi
}

main "$@"
