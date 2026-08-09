#!/usr/bin/env bash
# =============================================================================
# constraints/check-test-pairing.sh
#
#   Sources/Core/ の各ファイルに、対応するテストが存在するか検査する。
#
#   なぜ必要か:
#     テストのないコードは変更できない。変更しても壊れたかどうか分からず、
#     自動イテレーションが「動いているつもり」で進行してしまう。
#     テストの存在は機械判定できるので、最低限これは強制する。
#
#   検査するのは以下の 3 点。いずれも機械判定可能:
#     1. Sources/Core/Foo.swift に対し Tests/CoreTests/FooTests.swift がある
#     2. テストファイルにアサーションが 1 つ以上ある（空テスト対策）
#     3. プロパティテストの目印がある（CLAUDE.md の方針に対応）
#
#   検査できないこと:
#     テストが妥当か。これは ./scripts/mutate.sh（ミューテーション）に委ねる。
# =============================================================================

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly CORE_DIR="${PROJECT_ROOT}/Sources/Core"
readonly TEST_DIR="${PROJECT_ROOT}/Tests/CoreTests"

# アサーションとみなすパターン。XCTest と swift-testing の両方に対応。
readonly ASSERTION_PATTERN='XCTAssert|XCTFail|XCTUnwrap|#expect|#require'

# プロパティテストの目印。ライブラリ未導入でも、手書きのループで
# 入力を生成していれば認める（forAll / property / randomElement 等）。
readonly PROPERTY_PATTERN='forAll|property\(|\.random\(|randomElement|for _ in 0\.\.<'

main() {
    local source base test_file exit_code=0 checked=0

    if [[ ! -d "${CORE_DIR}" ]]; then
        printf 'Sources/Core/ がまだありません（着手前として PASS）\n'
        return 0
    fi

    cd "${PROJECT_ROOT}" || return 1

    while IFS= read -r source; do
        [[ -f "${source}" ]] || continue
        (( checked++ ))

        base="$(basename "${source}" .swift)"
        test_file="${TEST_DIR}/${base}Tests.swift"

        # 1. 対応するテストファイルの存在
        if [[ ! -f "${test_file}" ]]; then
            printf '%s: 対応するテストがありません（期待: %s）\n' \
                "${source}" "${test_file#${PROJECT_ROOT}/}" >&2
            exit_code=1
            continue
        fi

        # 2. アサーションの存在（空テストで PASS させることを防ぐ）
        if ! grep -qE "${ASSERTION_PATTERN}" "${test_file}"; then
            printf '%s: アサーションがありません\n' \
                "${test_file#${PROJECT_ROOT}/}" >&2
            exit_code=1
        fi

        # 3. プロパティテストの存在
        if ! grep -qE "${PROPERTY_PATTERN}" "${test_file}"; then
            printf '%s: プロパティテストがありません（境界値の検査が不足）\n' \
                "${test_file#${PROJECT_ROOT}/}" >&2
            exit_code=1
        fi
    done < <(find "${CORE_DIR}" -name '*.swift' -type f)

    if (( checked == 0 )); then
        printf 'Sources/Core/ に .swift がありません\n'
        return 0
    fi

    if (( exit_code == 0 )); then
        printf '検査 %d ファイル: テスト対応あり\n' "${checked}"
    fi
    return "${exit_code}"
}

main "$@"
