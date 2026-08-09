#!/usr/bin/env bash
# =============================================================================
# scripts/hooks/pre-write-guard.sh
#
#   既存ファイルに対する Write（全体書き換え）を拒否し、Edit を促す。
#
#   なぜ必要か:
#     AI がファイルを丸ごと生成し直すと、意図しない箇所が巻き添えで変わる。
#     元のコメントや微妙な条件が消え、差分レビューも git blame も壊れる。
#     Edit（文字列置換）なら変更範囲が明示され、他は保持される。
#     この差は自律イテレーションの安全性に直結する。
#
#   何を許可するか:
#     - 新規ファイルの作成（Edit では作れないため）
#     - 小さいファイル（閾値以下。誤爆を避ける）
#     - 生成物（MEMORY.md 等。スクリプトが作るもの）
#
#   終了コード 2 で stderr の内容が Claude にフィードバックされ、
#   ツール実行がブロックされる。
#
#   設定例（.claude/settings.json）:
#     "hooks": { "PreToolUse": [{
#       "matcher": "Write",
#       "hooks": [{ "type": "command",
#         "command": "$CLAUDE_PROJECT_DIR/scripts/hooks/pre-write-guard.sh" }]
#     }]}
# =============================================================================

set -uo pipefail

readonly PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# この行数以下なら全体書き換えを許可する。
# 小さいファイルは全体を見渡せるため、巻き添え被害が起きにくい。
readonly SMALL_FILE_LINES=30

# スクリプトが生成するファイル。手で書かない前提なので上書きを許可する。
readonly -a GENERATED=(
    "MEMORY.md"
)

# ファイルが生成物かどうかを判定する。
is_generated() {
    local target="$1" name
    name="$(basename "${target}")"
    local entry
    for entry in "${GENERATED[@]}"; do
        [[ "${name}" == "${entry}" ]] && return 0
    done
    return 1
}

main() {
    local input path lines

    input="$(cat 2>/dev/null)" || exit 0
    [[ -n "${input}" ]] || exit 0

    if command -v jq >/dev/null 2>&1; then
        path="$(printf '%s' "${input}" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
    else
        path="$(printf '%s' "${input}" |
            sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    fi

    # パスが取れなければ判断できないので通す（フックで作業を止めない）
    [[ -n "${path}" ]] || exit 0

    # 新規作成は許可。Edit では新しいファイルを作れない。
    [[ -e "${path}" ]] || exit 0

    # 生成物は許可
    is_generated "${path}" && exit 0

    lines="$(wc -l < "${path}" 2>/dev/null | tr -d ' ')"
    [[ -n "${lines}" ]] || exit 0

    # 小さいファイルは許可（誤爆を避ける）
    (( lines <= SMALL_FILE_LINES )) && exit 0

    {
        printf '既存ファイルの全体書き換え（Write）はブロックされました。\n\n'
        printf '  対象: %s（%s 行）\n\n' "${path}" "${lines}"
        printf '## なぜブロックするか\n\n'
        printf '全体生成は、変更していないつもりの箇所も巻き添えで変える。\n'
        printf '元のコメント、微妙な条件分岐、他の作業者の変更が消える。\n'
        printf '差分レビューも git blame も機能しなくなり、\n'
        printf '「何がどう変わったか」を後から追えなくなる。\n\n'
        printf '## 正しい手順\n\n'
        printf '1. **Edit ツールを使う** — 変更箇所だけを置換する\n\n'
        printf '2. **Edit では手数が多すぎる場合**（一括変換など）\n'
        printf '   scripts/ に冪等なスクリプトを作って実行する。\n'
        printf '   条件: 2回実行しても結果が変わらない / dry-run がある /\n'
        printf '         スクリプト自体がレビュー対象として残る\n\n'
        printf '3. **ファイル分割の兆候かもしれない**\n'
        printf '   Write を使いたくなるほど広範囲を変えるなら、\n'
        printf '   そのファイルに責務が複数ある可能性がある\n\n'
        printf '4. **この制約自体が間違っていると判断した場合**\n'
        printf '   Bash や他の手段で迂回せず、以下を人間に報告すること。\n'
        printf '   - 何をしようとしたか\n'
        printf '   - なぜ Edit や冪等スクリプトでは不十分か\n'
        printf '   - この制約をどう変更すべきか\n\n'
        printf '   制約は不完全であり、正当な例外は必ず存在する。\n'
        printf '   **隠れて迂回するのではなく、制約の側を直す。**\n'
        printf '   その方が次回以降も効き、他の人にも利益がある。\n\n'
        printf '詳細: docs/rationale.md\n'
    } >&2
    exit 2
}

main "$@"
