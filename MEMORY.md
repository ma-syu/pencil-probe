# MEMORY.md

`knowledge/` の索引。**このファイルは生成物。直接編集しない。**
再生成: `./scripts/memory-index.sh`

生成日時: 2026-08-10 06:58:30

## 状態の意味

| 状態 | 意味 | 対応 |
|---|---|---|
| active | 制約テストが PASS | なし |
| violated | 制約テストが FAIL | **要対応**。規約違反か制約が古い |
| orphaned | 制約ファイルが存在しない | **要対応**。リンク切れ |
| referenced | 制約なし・参照実績あり | なし |
| unused | 制約なし・未参照 | 経過観察 |
| stale | 制約なし・90日以上未参照 | 格下げ・削除を検討 |

## 索引

| ID | タイトル | 状態 | 制約 | 参照 |
|---|---|---|---|---|
| [0001](knowledge/0001-shell-var-expansion.md) | シェル変数展開と全角文字の衝突 | active | constraints/check-var-expansion.sh | 0
0 |
| [0002](knowledge/0002-rule-delimiter.md) | パターンと理由の区切りに `|` を使うと正規表現の選択と衝突する | referenced | — | 0
0 |
| [0003](knowledge/0003-input-path-analysis.md) | Virtual Mac の入力転送経路には筆圧のフィールドが無い | referenced | — | 1 |
| [0004](knowledge/0004-claude-md-split.md) | CLAUDE.md を共通側とプロジェクト側に分割した（仮説・未検証） | referenced | — | 0
0 |
| [0005](knowledge/0005-proxy-metric-failure.md) | 代理指標（行数上限）が目的を侵食した | referenced | — | 0
0 |
| [0006](knowledge/0006-bsd-sed-multibyte.md) | macOS の BSD sed はマルチバイト文字で illegal byte sequence を起こす | referenced | — | 0
0 |
| [0007](knowledge/0007-opendisplay-prior-art.md) | OpenDisplay が同じ課題（Pencil の筆圧・傾きを Mac へ送る）を扱っている | referenced | — | 0
0 |
