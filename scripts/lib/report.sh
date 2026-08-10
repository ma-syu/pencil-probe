#!/usr/bin/env bash
# =============================================================================
# scripts/lib/report.sh
#
#   検査スクリプトが違反を報告するための共通ライブラリ。
#   **4 つの要素をすべて埋めることを強制する。**
#
#   なぜ構造を強制するか:
#     「何が問題か」だけを告げるメッセージは、迂回か誤った修正を招く。
#     理由が分からなければ、迂回が合理的に見えるため。
#
#     実例: 「set -u が設定されていません」とだけ表示したところ、
#     source 専用のライブラリに set -u を足そうとした。
#     ライブラリの set は呼び出し元を上書きするため、それは誤りだった。
#     理由が書かれていれば「ライブラリには当てはまらない」と
#     即座に判断できたはずだった。
#
#     確率的生成 AI は特に影響を受ける。人間は「変だな」と疑えるが、
#     AI は理由が示されなければ素直に従い、別の場所を壊す。
#     自律イテレーション中は、人間が気づかないまま進行する。
#
#   4 要素:
#     problem     何が検出されたか
#     consequence **放置するとどうなるか**
#     fix         どう直すか
#     if-wrong    この検査自体が誤っている場合にどうするか
#
#   consequence が最も重要:
#     これを書こうとして書けない検査は、「なんとなく良くない」だけの
#     検査である可能性が高い。要素の強制が、検査自体の妥当性審査になる。
#
#   使い方:
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/report.sh"
#
#     report_violation \
#         --location "scripts/foo.sh:12" \
#         --problem "変数展開が \${VAR} で囲まれていない" \
#         --consequence "bash が全角文字を変数名の一部と解釈し、set -u 環境で unbound variable エラーになる" \
#         --fix "文字列内の変数を \${VAR} の形で囲む" \
#         --if-wrong "外部仕様に由来する記述なら、この検査の除外パターンに追加する" \
#         --knowledge "H0001"
# =============================================================================

# 違反を構造化して報告する。
#
# 4 要素が揃っていなければ、報告そのものを失敗として扱う。
# 「理由を書かない報告」を物理的に出せなくするため。
report_violation() {
    local location="" problem="" consequence="" fix="" if_wrong="" knowledge=""

    while (( $# > 0 )); do
        case "$1" in
            --location)    location="${2:-}";    shift 2 ;;
            --problem)     problem="${2:-}";     shift 2 ;;
            --consequence) consequence="${2:-}"; shift 2 ;;
            --fix)         fix="${2:-}";         shift 2 ;;
            --if-wrong)    if_wrong="${2:-}";    shift 2 ;;
            --knowledge)   knowledge="${2:-}";   shift 2 ;;
            *)
                printf 'report_violation: 不明な引数: %s\n' "$1" >&2
                return 2
                ;;
        esac
    done

    # 必須要素の検証。埋められないなら、その検査の妥当性を疑うこと。
    local -a missing=()
    [[ -n "${problem}" ]]     || missing+=(--problem)
    [[ -n "${consequence}" ]] || missing+=(--consequence)
    [[ -n "${fix}" ]]         || missing+=(--fix)
    [[ -n "${if_wrong}" ]]    || missing+=(--if-wrong)

    if (( ${#missing[@]} > 0 )); then
        {
            printf 'report_violation: 必須要素が欠けています: %s\n' "${missing[*]}"
            printf '\n'
            printf '  理由を書かない報告は、迂回か誤った修正を招きます。\n'
            printf '  特に --consequence（放置するとどうなるか）を書けない場合、\n'
            printf '  その検査自体の必要性を疑ってください。\n'
        } >&2
        return 2
    fi

    {
        if [[ -n "${location}" ]]; then
            printf '%s: %s\n' "${location}" "${problem}"
        else
            printf '%s\n' "${problem}"
        fi
        printf '  なぜ問題か: %s\n' "${consequence}"
        printf '  直し方:     %s\n' "${fix}"
        printf '  この検査が誤っている場合: %s\n' "${if_wrong}"
        [[ -n "${knowledge}" ]] &&
            printf '  背景:       knowledge/%s\n' "${knowledge}"
    } >&2

    return 0
}

# 検査が正常終了したことを報告する。
#
# 形式を揃えることで、check-all.sh の出力が読みやすくなる。
report_ok() {
    local summary="$1"
    printf '%s\n' "${summary}"
    return 0
}
