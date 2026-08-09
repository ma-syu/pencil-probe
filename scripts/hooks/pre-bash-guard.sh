#!/usr/bin/env bash
# =============================================================================
# scripts/hooks/pre-bash-guard.sh
#
#   Bash 経由でのファイル全体書き換えを検出する。
#
#   なぜ必要か:
#     pre-write-guard.sh が Write をブロックしても、
#     `bash -c 'cat > file <<EOF ...'` や `sed -i` で同じことができる。
#     制約に抜け道があると、それは制約ではなく「面倒な提案」になり、
#     やがて誰も守らなくなる。
#
#   ただし完璧な検出は不可能:
#     シェルの表現力は高く、全ての書き込み経路を静的に塞ぐことはできない。
#     このフックは「うっかり迂回」を止めるためのものであり、
#     意図的な回避を防ぐものではない。
#     だからこそ、拒否メッセージで「なぜ」と「正規の逃げ道」を必ず示す。
#
#   設定例（.claude/settings.json）:
#     "hooks": { "PreToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{ "type": "command",
#         "command": "$CLAUDE_PROJECT_DIR/scripts/hooks/pre-bash-guard.sh" }]
#     }]}
# =============================================================================

set -uo pipefail

readonly PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 「パターン|何が問題か」形式。
# 検出は保守的にする。誤検出が多いと、このフック自体が無視される。
readonly -a SUSPICIOUS=(
    '>[[:space:]]*[^|&>[:space:]]*\.(swift|m|h|c|sh|nix|md)@@リダイレクトによるファイル全体の上書き'
    'tee[[:space:]]+[^|]*\.(swift|m|h|c|sh|nix|md)@@tee によるファイル全体の上書き'
    'sed[[:space:]]+-i@@sed -i によるその場編集'
    'cat[[:space:]]*>[[:space:]]*[^|&]@@ヒアドキュメントによるファイル生成'
    'perl[[:space:]]+-i@@perl -i によるその場編集'
    'truncate@@ファイルの切り詰め'
)

# 明らかに安全な用途は除外する。
# 一時ファイル・ログ・追記は、既存ソースを壊さない。
readonly -a SAFE_PATTERNS=(
    '>>'                    # 追記
    '/tmp/'                 # 一時ファイル
    '/dev/null'
    '\.log'
    '\.memory/'
    'MEMORY\.md'            # 生成物
)

is_safe() {
    local command="$1" pattern
    for pattern in "${SAFE_PATTERNS[@]}"; do
        [[ "${command}" =~ ${pattern} ]] && return 0
    done
    return 1
}

# 拒否メッセージ。「なぜ」と「正規の逃げ道」を必ず両方示す。
# 理由だけでは迂回を促し、逃げ道だけでは制約が形骸化する。
print_rejection() {
    local command="$1" reason="$2"

    cat >&2 <<EOF
ファイルを直接書き換えるコマンドが検出されました。

  検出: ${reason}
  内容: ${command}

## なぜブロックするか

全体書き換えは、変更していないつもりの箇所も巻き添えで変える。
元のコメント、微妙な条件分岐、他の作業者の変更が消える。
差分レビューも git blame も機能しなくなり、
「何がどう変わったか」を後から追えなくなる。

Edit（文字列置換）なら変更範囲が明示され、他は保持される。
この差が、自律イテレーションで壊れるか壊れないかを分ける。

## 正しい手順

1. **Edit ツールを使う** — 変更箇所だけを置換する

2. **Edit では手数が多すぎる場合**（全ファイルの一括変換など）
   scripts/ に冪等なスクリプトを作り、それを実行する。
   条件: 2回実行しても結果が変わらない / dry-run がある /
         スクリプト自体がレビュー対象として残る

3. **この制約自体が間違っていると判断した場合**
   迂回せず、以下を人間に報告して判断を仰ぐこと。
   - 何をしようとしたか
   - なぜ Edit や冪等スクリプトでは不十分か
   - この制約をどう変更すべきか

   制約は不完全であり、正当な例外は存在する。
   **隠れて迂回するのではなく、制約の側を直す。**
   その方が次回以降も効き、他の人にも利益がある。

## 制約を変更する手順

scripts/hooks/pre-bash-guard.sh の SAFE_PATTERNS に追加するか、
docs/rationale.md に例外の根拠を記載したうえで変更する。
変更したら、なぜその例外が安全かをコメントに残すこと。
EOF
}

main() {
    local input command rule pattern reason

    input="$(cat 2>/dev/null)" || exit 0
    [[ -n "${input}" ]] || exit 0

    if command -v jq >/dev/null 2>&1; then
        command="$(printf '%s' "${input}" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    else
        command="$(printf '%s' "${input}" |
            sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')"
    fi

    [[ -n "${command}" ]] || exit 0

    # 安全な用途なら通す
    is_safe "${command}" && exit 0

    for rule in "${SUSPICIOUS[@]}"; do
        pattern="${rule%%@@*}"
        reason="${rule#*@@}"

        if [[ "${command}" =~ ${pattern} ]]; then
            print_rejection "${command}" "${reason}"
            exit 2
        fi
    done

    exit 0
}

main "$@"
