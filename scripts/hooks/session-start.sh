#!/usr/bin/env bash
# =============================================================================
# scripts/hooks/session-start.sh
#
#   Claude Code の SessionStart フックから呼ばれる。
#   標準出力の内容がそのままコンテキストへ注入される。
#
#   CLAUDE.md と役割が違う点:
#     CLAUDE.md  … 静的な規約。手で書く。
#     このフック … 実行時点の「現在の状態」。自動で変わる。
#
#   注入は毎セッション 1 回なので、多少の長さは許容できる。
#   ただし数十行に抑える。長いと本題を圧迫する。
#
#   設定例（.claude/settings.json）:
#     "hooks": { "SessionStart": [{ "hooks": [{
#       "type": "command",
#       "command": "$CLAUDE_PROJECT_DIR/scripts/hooks/session-start.sh"
#     }]}]}
# =============================================================================

set -uo pipefail

# フック実行時のカレントディレクトリは保証されないため、
# CLAUDE_PROJECT_DIR を優先し、無ければスクリプト位置から辿る。
readonly PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

cd "${PROJECT_ROOT}" || exit 0   # 失敗しても作業は止めない

# 索引を最新にしてから読む。
# 知識を追加したのに再生成し忘れる、という事故を防ぐ。
# 生成物なので、常に作り直しても情報は失われない。
if [[ -x ./scripts/memory-index.sh ]]; then
    ./scripts/memory-index.sh >/dev/null 2>&1 || true
fi

printf '=== プロジェクト状態（自動注入 / %s）===\n' "$(date '+%F %T')"

# --- 制約の現在の合否 -------------------------------------------------------
# 「今どうなっているか」は静的な文書に書けない。ここで実測して伝える。
printf '\n## 制約チェック\n'
if [[ -x ./constraints/check-all.sh ]]; then
    if ./constraints/check-all.sh >/dev/null 2>&1; then
        printf '全て PASS\n'
    else
        printf '**FAIL があります。作業前に ./constraints/check-all.sh を実行し、\n'
        printf '内容を確認してください。**\n'
    fi
else
    printf '（constraints/check-all.sh がありません）\n'
fi

# --- 未コミットの変更 -------------------------------------------------------
# 直前の作業が中断されている可能性を伝える。
printf '\n## 作業ツリー\n'
if git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'ブランチ: %s\n' "$(git branch --show-current 2>/dev/null || echo '(不明)')"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        printf '未コミットの変更あり:\n'
        git status --short 2>/dev/null | head -10 | sed 's/^/  /'
    else
        printf 'clean\n'
    fi
else
    printf '（git リポジトリではありません）\n'
fi

# --- 記録済みの知識 ---------------------------------------------------------
# 索引を載せることで「読みに行く」判断のきっかけを作る。
# 本文は載せない（長くなるため）。
#
# status を front matter から読まない理由:
#   状態（active / violated / orphaned / stale）は静的な値ではなく、
#   制約テストの成否や参照実績から scripts/memory-index.sh が
#   動的に判定する。ここで独自に判定すると同じロジックが 2 箇所に存在し、
#   片方が必ず腐る。実際、当初は front matter を読もうとして
#   常に [unknown] を表示していた。
#
#   MEMORY.md は memory-index.sh の生成物なので、そこから読めば
#   判定は 1 箇所に集約される。
printf '\n## knowledge/ の索引\n'
if [[ -f ./MEMORY.md ]]; then
    # 「## 索引」以降のテーブル行だけを抜き出す。
    # MEMORY.md には状態の凡例テーブルもあるため、
    # 見出しを目印にして範囲を限定する。
    in_index=0
    while IFS= read -r row; do
        case "${row}" in
            '## 索引'*) in_index=1; continue ;;
        esac
        (( in_index )) || continue
        case "${row}" in
            '|---'*|'| ID '*) continue ;;
            '|'*) printf '%s\n' "${row}" ;;
        esac
    done < MEMORY.md
    printf '\n（この索引は ./scripts/memory-index.sh の生成物）\n'
elif [[ -d ./knowledge ]] && compgen -G './knowledge/*.md' >/dev/null; then
    printf 'MEMORY.md が未生成です。./scripts/memory-index.sh を実行してください。\n'
    for entry in ./knowledge/*.md; do
        printf -- '- %s\n' "$(basename "${entry}")"
    done
else
    printf '（記録なし）\n'
fi

printf '\n詳細が必要になったら該当ファイルを読むこと。\n'
exit 0
