#!/usr/bin/env bash
# =============================================================================
# constraints/check-stale-files.sh
#
#   バックアップの残骸と、版数付きファイル名を検出する。
#
#   なぜ必要か（実測に基づく）:
#     AI は編集前に .bak を作り、作業完了後も削除しない傾向がある。
#     この挙動はこのプロジェクトの構築中にも実際に発生した
#     （uninstall-upstream-nix-macos.sh.bak が放置された）。
#     「念のため残す」判断が繰り返されるため、規約に書くだけでは
#     守られない可能性が高く、機械的に検出する必要がある。
#
#     版数付きの名前（v2 / final / new）も同じ理由で増殖する。
#     一度許すと foo-v2-final-new.sh のような名前に到達する。
#
#   何が問題か:
#     - どれが現行版か判断できなくなる
#     - 古い版を編集してしまう事故が起きる
#     - git があるので、そもそもバックアップは不要
#
#   検出したときの対処:
#     削除する。git 履歴に残るため情報は失われない。
#     経緯が重要なら knowledge/ に記録し、ファイル自体は消す。
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# バックアップとみなすファイル名のパターン。
readonly -a BACKUP_PATTERNS=(
    '\.bak$'
    '\.backup$'
    '\.orig$'
    '\.old$'
    '\.save$'
    '~$'
    '\.copy$'
    '\.tmp$'
    '^copy of '
    ' copy\.'
    ' \(1\)\.'
)

# 版数・修飾語付きの名前。拡張子の直前に現れるものを対象にする。
# 意味のある版数（api-v2 のような外部仕様のバージョン）と
# 区別できないため、検出は「疑い」として報告する。
readonly -a VERSIONED_PATTERNS=(
    '[-_]v[0-9]+\.[a-z]+$'
    '[-_]final\.[a-z]+$'
    '[-_]new\.[a-z]+$'
    '[-_]old\.[a-z]+$'
    '[-_]fixed\.[a-z]+$'
    '[-_]copy\.[a-z]+$'
    '[-_][0-9]+\.[a-z]+$'
)

# 検査対象を返す。git 管理下のみを見る。
# 追跡されていないファイルは .gitignore 対象の可能性があり、
# それらは意図的に残されている場合がある。
collect_targets() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git ls-files
    else
        find . -type f -not -path './.git/*'
    fi
}

main() {
    local file name pattern exit_code=0 checked=0

    cd "${PROJECT_ROOT}" || return 1

    while IFS= read -r file; do
        [[ -n "${file}" ]] || continue
        (( checked++ ))
        name="$(basename "${file}")"

        for pattern in "${BACKUP_PATTERNS[@]}"; do
            if [[ "${name}" =~ ${pattern} ]]; then
                printf '%s: バックアップの残骸です。削除してください。\n' "${file}" >&2
                printf '  git があるためバックアップは不要です。\n' >&2
                printf '  経緯が重要なら knowledge/ に記録し、ファイルは消すこと。\n' >&2
                exit_code=1
                break
            fi
        done

        for pattern in "${VERSIONED_PATTERNS[@]}"; do
            if [[ "${name}" =~ ${pattern} ]]; then
                printf '%s: 版数付きの名前です。\n' "${file}" >&2
                printf '  どれが現行版か判断できなくなり、必ず増殖します。\n' >&2
                printf '  繰り返す操作なら引数で切り替える形に汎用化し、\n' >&2
                printf '  一度きりの操作なら完了後に削除してください。\n' >&2
                printf '  外部仕様の版数（api-v2 等）で意図的な場合は、\n' >&2
                printf '  このスクリプトの VERSIONED_PATTERNS を調整すること。\n' >&2
                exit_code=1
                break
            fi
        done
    done < <(collect_targets)

    if (( checked == 0 )); then
        printf '対象ファイルがありません\n'
        return 0
    fi

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: 残骸なし\n' "${checked}"
    fi
    return "${exit_code}"
}

main "$@"
