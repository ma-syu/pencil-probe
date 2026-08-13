#!/usr/bin/env bash
# =============================================================================
# scripts/session-memory.sh
#
#   記憶システムのセッション開始時処理。
#   scripts/hooks/session-start.sh から呼ばれる。
#
#   hook はハーネス管理で git 追跡外のため、記憶システムの実体は
#   このスクリプト（git 追跡）に置く。hook は呼び出すだけ。
#
#   ハーネス再デプロイ後の復元手順:
#     session-start.sh の末尾（exit 0 の直前）に以下を追加:
#       if [[ -x ./scripts/session-memory.sh ]]; then
#           ./scripts/session-memory.sh
#       fi
#
#   出力は標準出力へ。session-start.sh がコンテキストに注入する。
# =============================================================================

set -uo pipefail

readonly PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

readonly -a REQUIRED_COMMANDS=(git grep sed)
if [[ -f "${PROJECT_ROOT}/scripts/lib/require.sh" ]]; then
    source "${PROJECT_ROOT}/scripts/lib/require.sh"
    require_commands "${REQUIRED_COMMANDS[@]}" || exit 1
fi

cd "${PROJECT_ROOT}" || exit 0

# --- 現在の状態 ---------------------------------------------------------------
printf '\n## 現在の状態\n'
if [[ -f ./memory/current.md ]]; then
    updated="$(grep '^updated:' ./memory/current.md | head -1 | sed 's/^updated:[[:space:]]*//')"
    if [[ -n "${updated}" ]]; then
        printf '(最終更新: %s)\n' "${updated}"
    fi
    tail -n +2 ./memory/current.md | head -40
    total_lines="$(wc -l < ./memory/current.md)"
    if (( total_lines > 60 )); then
        printf '\n⚠ memory/current.md が %d 行（上限目安 60）。古い意図ログを整理してください。\n' "${total_lines}"
    fi
else
    printf '（memory/current.md なし。作業開始前に作成してください）\n'
fi

# --- 前回の意図との照合 -------------------------------------------------------
printf '\n## 前回の意図 → git log 照合\n'
if [[ -f ./memory/current.md ]] && grep -q '^- ' ./memory/current.md; then
    last_intent="$(grep '^- ' ./memory/current.md | tail -1)"
    printf '最後の意図: %s\n' "${last_intent}"
    printf '直近のコミット:\n'
    git log --oneline -3 2>/dev/null | sed 's/^/  /'
else
    printf '（意図ログなし）\n'
fi

# --- 残件 ---------------------------------------------------------------------
# memory/current.md に未完了（- [ ]）の項目があれば表示する。
# 黙って消えるのを防ぐ。
if [[ -f ./memory/current.md ]]; then
    open_items="$(grep -c '^\- \[ \]' ./memory/current.md 2>/dev/null || true)"
    if (( open_items > 0 )); then
        printf '\n## 残件 (%d 件)\n' "${open_items}"
        grep '^\- \[ \]' ./memory/current.md
    fi
fi

# --- read イベント抽出 --------------------------------------------------------
if [[ -x ./scripts/extract-reads.sh ]]; then
    read_result="$(JSONL_DIR="${HOME}/.claude/projects/-Users-wahoo-projects-pencil-probe" \
        EVENTS_FILE="./memory/events.tsv" \
        KNOWLEDGE_DIR="./knowledge" \
        ./scripts/extract-reads.sh 2>&1)" || true
    printf '\n## イベント抽出\n%s\n' "${read_result}"
fi
