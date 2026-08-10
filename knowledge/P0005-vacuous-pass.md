---
id: P0005
title: "PASS は検査が機能していることを意味しない — 空振り検査の構造"
created: 2026-08-10
verified: 2026-08-10
constraint: constraints/check-module-boundary.sh
relates: [P0003, H0005]
---

## 事実

`check-module-boundary.sh` の `check_dependency_direction` に 2 つのバグがあり、
逆方向の依存（Core → IO）を検出できなかった。

1. **`target_block` の複数行定義バグ**: `name:` の行から括弧の depth を
   数え始めていたため、`.target(` が別行にある定義では `(` を数え損ね、
   depth=0 で即終了し 1 行しか取得できなかった
2. **層名とターゲット名の不一致**: `LAYERS=(Core IO)` で "IO" を検索するが、
   実際のターゲット名は "pencil-probe"（`path: "Sources/IO"`）。
   `has_target "IO"` が失敗し、IO 層が丸ごとスキップされていた

**いずれも check-all.sh は PASS していた。**

**訂正**: 当初「`check-dependency-graph.sh` が Package.swift の単一ターゲットで
空振りしていた」と判断したが、これは誤り。Package.swift は Phase 0 の時点で
既に層ごとにターゲットが分かれており、`check-dependency-graph.sh` は機能していた。
実際に空振りしていたのは `check-module-boundary.sh` 自身。

## 修正内容

1. **`target_block`**: `.target(` の行からブロックを蓄積し、括弧が閉じた時点で
   `name:` の一致を判定する方式に変更
2. **`target_name_for_dir` 関数を追加**: ディレクトリ名（IO）から
   実際のターゲット名（pencil-probe）を Package.swift の `path:` 指定で解決する
3. **`check_dependency_direction`**: 層名ではなく解決後のターゲット名で
   ブロック取得と依存検査を行う

## 構造的な教訓

「検査が PASS していることは、検査が機能していることを意味しない。」

| 例 | 観測系 | 空振りの原因 |
|---|---|---|
| 本件 | `check-module-boundary.sh` | `target_block` と名前解決のバグ |
| H0006 | `check-error-quality.sh` | 旧版にはチェック対象の関数がなく検出不能 |
| H0006 | harness 自体 | そもそも配布元で検査を回していない |
| テスト全般 | テストスイート | アサーションがない（常に緑） |

共通する構造:
- 検査は「違反を見つけたら FAIL」という設計
- 検査対象が存在しない / 到達不能なとき、違反は見つからない
- 結果として PASS を返すが、これは「問題がない」ではなく「検査していない」

## Package.swift の正しい構成

```swift
.target(
    name: "Core",
    path: "Sources/Core"
),
.executableTarget(
    name: "pencil-probe",
    dependencies: ["Core"],
    path: "Sources/IO"
),
.testTarget(
    name: "CoreTests",
    dependencies: ["Core"],
    path: "Tests/CoreTests"
),
```

- Core: 依存なし。公開型に `public` を付ける
- pencil-probe（IO）: Core に依存。`import Core` が必要
- CoreTests: Core に依存
