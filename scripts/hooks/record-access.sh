#!/usr/bin/env bash
# =============================================================================
# scripts/hooks/record-access.sh
#
#   Claude Code の PostToolUse フックから呼ばれ、knowledge/ 配下への
#   Read / Grep を記録する。
#
#   何を測っているか（重要）:
#     記録できるのは「参照されたか」だけで、「役に立ったか」ではない。
#     AI の発話（「見つけました」等）はフックから取得できないうえ、
#     自然言語の解釈は確率的で、判定を誤ると有効な知識を失う。
#     そのため「参照回数」を代理指標として使い、
#     知識の生死判定そのものは constraints/ のテストに委ねる。
#
#   このフックは絶対に作業を止めない。失敗しても exit 0 を返す。
#
#   設定例（.claude/settings.json）:
#     "hooks": { "PostToolUse": [{
#       "matcher": "Read|Grep",
#       "hooks": [{ "type": "command",
#         "command": "$CLAUDE_PROJECT_DIR/scripts/hooks/record-access.sh" }]
#     }]}
# =============================================================================

set -uo pipefail

readonly PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
readonly LOG_FILE="${PROJECT_ROOT}/.memory/access.log"

main() {
    local input tool path

    # stdin から JSON を受け取る。読めなければ何もしない。
    input="$(cat 2>/dev/null)" || exit 0
    [[ -n "${input}" ]] || exit 0

    # jq が無い環境でも壊れないようにフォールバックする
    if command -v jq >/dev/null 2>&1; then
        tool="$(printf '%s' "${input}" | jq -r '.tool_name // empty' 2>/dev/null)"
        path="$(printf '%s' "${input}" |
            jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
    else
        tool="$(printf '%s' "${input}" |
            sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        path="$(printf '%s' "${input}" |
            sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    fi

    # knowledge/ 配下のみ記録する。他は対象外。
    case "${path}" in
        */knowledge/*) ;;
        *) exit 0 ;;
    esac

    mkdir -p "$(dirname "${LOG_FILE}")" 2>/dev/null || exit 0
    printf '%s\t%s\t%s\n' \
        "$(date -u +%FT%TZ)" "${tool:-unknown}" "${path}" >> "${LOG_FILE}" 2>/dev/null

    exit 0
}

main "$@"
