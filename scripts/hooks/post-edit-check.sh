#!/usr/bin/env bash
# =============================================================================
# scripts/hooks/post-edit-check.sh
#
#   Edit / Write の直後に制約チェックを実行し、結果を Claude に返す。
#
#   なぜこれが最も重要か:
#     自律イテレーションで壊れる主因は「壊れたことに気づかないまま
#     次の作業に進む」こと。編集のたびに検証が走り、その場で
#     フィードバックが返れば、破壊は 1 手で検出される。
#     純粋性の強制や AI レビューより、この即時性の方が効果が大きい。
#
#   速度が重要:
#     このフックが遅いと作業が止まる。静的検査のみを実行し、
#     ビルドやテストは含めない（それらは明示的に実行させる）。
#
#   終了コード 2 を返すと、Claude に stderr の内容がフィードバックされる。
#   0 を返すと何も起きない。
#
#   設定例（.claude/settings.json）:
#     "hooks": { "PostToolUse": [{
#       "matcher": "Edit|Write|MultiEdit",
#       "hooks": [{ "type": "command",
#         "command": "$CLAUDE_PROJECT_DIR/scripts/hooks/post-edit-check.sh" }]
#     }]}
# =============================================================================

set -uo pipefail

readonly PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
readonly CHECK="${PROJECT_ROOT}/constraints/check-all.sh"
readonly VIOLATION_LOG="${PROJECT_ROOT}/.memory/violations.log"

# FAIL した検査名を記録する。
#
# 何のために記録するか:
#   CLAUDE.md に書いた規約のうち、どれが実際に守られていないかを
#   実測するため。頻繁に違反される規約は、書き方が悪いか目立たない。
#   逆に一度も違反されない規約は、CLAUDE.md から削って
#   constraints/ の検査だけに任せられる可能性がある。
#
#   「行数が多いから削る」ではなく「実測で不要と分かったから削る」
#   という判断を可能にする。
record_violations() {
    local output="$1" name

    mkdir -p "$(dirname "${VIOLATION_LOG}")" 2>/dev/null || return 0

    # check-all.sh の出力から [FAIL] 行を拾う
    printf '%s\n' "${output}" |
        sed -n 's/^\[FAIL\][[:space:]]*//p' |
        while IFS= read -r name; do
            [[ -n "${name}" ]] || continue
            printf '%s\t%s\n' "$(date -u +%FT%TZ)" "${name}" \
                >> "${VIOLATION_LOG}" 2>/dev/null
        done
    return 0
}

main() {
    local output

    # stdin の JSON は使わないが、読み捨てないとパイプが詰まる可能性がある
    cat >/dev/null 2>&1 || true

    [[ -x "${CHECK}" ]] || exit 0

    if output="$( cd "${PROJECT_ROOT}" && "${CHECK}" 2>&1 )"; then
        exit 0   # PASS。何も言わない（ノイズを増やさない）
    fi

    record_violations "${output}"

    # FAIL 時のみ Claude にフィードバックする。
    # exit 2 で stderr の内容が Claude に渡る。
    {
        printf '制約チェックが FAIL しました。次の作業に進む前に修正してください。\n\n'
        printf '%s\n' "${output}"
        printf '\n再確認: ./constraints/check-all.sh\n'
    } >&2
    exit 2
}

main "$@"
