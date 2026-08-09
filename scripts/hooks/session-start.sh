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
printf '\n## knowledge/ の索引\n'
if [[ -d ./knowledge ]] && compgen -G './knowledge/*.md' >/dev/null; then
    local_file=""
    for local_file in ./knowledge/*.md; do
        # front matter の title を拾う。無ければファイル名。
        title="$(sed -n 's/^title:[[:space:]]*//p' "${local_file}" | head -1)"
        status="$(sed -n 's/^status:[[:space:]]*//p' "${local_file}" | head -1)"
        printf -- '- %s [%s] %s\n' \
            "$(basename "${local_file}")" "${status:-unknown}" "${title:-}"
    done
else
    printf '（記録なし）\n'
fi

printf '\n詳細が必要になったら該当ファイルを読むこと。\n'
exit 0
