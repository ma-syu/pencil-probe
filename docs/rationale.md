# このプロジェクト固有の規約の理由

汎用的な規約（Core/IO 分離、閾値、テスト方針、ファイル編集、命名、
イテレーション）の理由は `~/.claude/docs/` にある。
ここには**このプロジェクトに固有**のものだけを書く。

---

## なぜセキュリティ制約が厳しいのか

この環境は**ブリッジネットワークで LAN に直結**している。
UTM の NAT と違い、VM が LAN 上の独立ホストになっている。

そのうえで作ろうとしているのは**入力注入プログラム**（マウス・キーボード
イベントの生成）。`0.0.0.0` でリッスンすれば、LAN 上の任意の機器から
ゲストを完全に操作できる。

これは理論上のリスクではなく、実際に到達可能な攻撃経路になる。
ソケットは `127.0.0.1` か、明示的に許可した単一 IP のみにバインドする。

対応する分類: OWASP A01（アクセス制御の不備）、A03（インジェクション）、
CWE-78、CWE-120、CWE-676。

---

## 検査スクリプトの一覧

`constraints/check-all.sh` が全て実行し、終了コードで合否を返す。
新しい検査を追加したら、必ずここに追記すること
（`constraints/check-docs.sh` が、言及のない検査を検出する）。

| スクリプト | 検査内容 | 動作段階 |
|---|---|---|
| `check-var-expansion.sh` | 全角文字の直前の変数展開（`knowledge/0001`） | 常時 |
| `check-shell-hygiene.sh` | シェルの構文と `set -u` の有無 | 常時 |
| `check-secrets.sh` | 認証情報の混入（gitleaks があれば使用） | 常時 |
| `check-docs.sh` | リンク切れ・孤立・未記載の検査・見出しの重複 | 常時 |
| `check-gitignore.sh` | 秘密情報が実際に除外されているか（`git check-ignore`） | 常時 |
| `check-stale-files.sh` | `.bak` 等の残骸、版数付きファイル名 | 常時 |
| `check-naming.sh` | チケット番号・日付・意味のない関数名/ファイル名 | 常時 |
| `check-unsafe-api.sh` | `0.0.0.0` バインド、`system()`、`strcpy` 等 | ソース作成後 |
| `check-purity-boundary.sh` | `Core/` への副作用漏れ | `Sources/Core/` 作成後 |
| `check-test-pairing.sh` | テストの存在・アサーション・プロパティテスト | 同上 |
| `check-dependency-graph.sh` | 層をまたぐ依存の向き・循環依存 | `Sources/` 作成後 |
| `check-declared-deps.sh` | 外部コマンド依存の宣言漏れ | 常時 |
| `check-error-quality.sh` | 違反報告が構造化されているか | 常時 |
| `check-module-boundary.sh` | Swift の層分離がビルドシステムで強制されているか | `Package.swift` 作成後 |

対象ディレクトリが存在しない間は PASS を返す設計にしてある。
着手前でも `check-all.sh` が通り、「まだ書いていないから FAIL」という
無意味な赤を避けるため。

### 追加すべきもの（Swift コード作成後）

- `.swiftlint.yml` + `check-swift-lint.sh` — 循環的複雑度、関数長、
  `closure_body_length`。閾値は実コードを見てから調整する
- `check-mutation.sh` — `scripts/mutate.sh` のラッパー。
  テストが揃ってから有効化する

まず `nix run nixpkgs#swiftlint -- version` で入手可否を確認すること。
使えるなら自作より確実で、多数のルールが一度に手に入る。
