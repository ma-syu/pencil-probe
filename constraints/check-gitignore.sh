#!/usr/bin/env bash
# =============================================================================
# constraints/check-gitignore.sh
#
#   秘密情報が git の追跡対象から確実に外れているかを検査する。
#
#   なぜ必要か:
#     constraints/check-secrets.sh は「混入したら検出する」ものであり、
#     混入自体は防いでいない。しかも既知のパターン（AWS キー、
#     GitHub トークン等）しか拾えず、独自形式は素通りする。
#
#     一度 commit して push すると git 履歴から消すのは困難で、
#     実質的に漏洩したものとして扱うしかない。
#     防御は入口（追跡させない）に置く方が確実。
#
#   何を検査するか:
#     .gitignore の文字列を grep するのではなく、
#     **git check-ignore で実際に除外されるか**を確認する。
#     global gitignore（~/.config/git/ignore）でカバーされていれば
#     プロジェクト側に記述がなくても PASS になる。
#     「どこに書いてあるか」ではなく「実際に守られているか」を見る。
#
#   検査できないこと:
#     未知の形式の秘密情報。ここで守れるのは既知の拡張子・名前だけで、
#     独自命名のファイルは各自が .gitignore に追加する必要がある。
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 除外されていなければならないパスの代表例。
# 実在しなくてよい。git check-ignore はパターン照合のみを行う。
readonly -a MUST_IGNORE=(
    "secret.pem"
    "private.key"
    "id_rsa"
    "id_ed25519"
    ".env"
    "credentials.json"
    ".netrc"
    "app.mobileprovision"
    "service-account.json"
    ".DS_Store"
)

# 逆に、除外されていてはいけないもの。
# 過剰な除外で必要なファイルが追跡されなくなる事故を防ぐ。
readonly -a MUST_NOT_IGNORE=(
    ".env.example"
    "CLAUDE.md"
    "constraints/check-all.sh"
)

main() {
    local path exit_code=0 missing=0

    cd "${PROJECT_ROOT}" || return 1

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        printf 'git リポジトリではありません（git init 前として PASS）\n'
        return 0
    fi

    # 除外されるべきものが除外されているか。
    # --no-index でパターンのみを見る（追跡状態に依存しない判定）。
    for path in "${MUST_IGNORE[@]}"; do
        if ! git check-ignore -q --no-index "${path}" 2>/dev/null; then
            printf '%s が追跡対象になっています\n' "${path}" >&2
            (( missing++ ))
            exit_code=1
        fi
    done

    if (( missing > 0 )); then
        printf '\n' >&2
        printf '  秘密情報が git に入ると、履歴から消すのは困難です。\n' >&2
        printf '  以下のいずれかで除外してください。\n' >&2
        printf '\n' >&2
        printf '  a) 全リポジトリで守る（推奨）:\n' >&2
        printf '       ~/.config/git/ignore に秘密情報のパターンを書く。\n' >&2
        printf '     このパスは git の既定（XDG）なので、置くだけで有効。\n' >&2
        printf '     core.excludesFile の設定は不要。\n' >&2
        printf '     書き忘れても全プロジェクトで守られる。\n' >&2
        printf '\n' >&2
        printf '  b) このプロジェクトのみ:\n' >&2
        printf '       .gitignore に追記する\n' >&2
    fi

    # 除外されてはいけないものが除外されていないか。
    #
    # --no-index が必要な理由:
    #   git check-ignore は既に追跡済みのファイルを
    #   「除外されていない」と報告する（index にあるため）。
    #   過剰な除外パターンを追加しても、既存ファイルでは検出できない。
    #   --no-index はパターンのみで判定するため、
    #   「これから追加されるファイルが除外されるか」が分かる。
    for path in "${MUST_NOT_IGNORE[@]}"; do
        if git check-ignore -q --no-index "${path}" 2>/dev/null; then
            printf '%s が誤って除外されています\n' "${path}" >&2
            printf '  過剰な除外パターンがないか確認してください。\n' >&2
            printf '  既に追跡済みのファイルでも、パターンに一致すれば\n' >&2
            printf '  新しい環境で clone した際に問題になります。\n' >&2
            exit_code=1
        fi
    done

    if (( exit_code == 0 )); then
        printf '秘密情報 %d 種: すべて除外済み\n' "${#MUST_IGNORE[@]}"
    fi
    return "${exit_code}"
}

main "$@"
