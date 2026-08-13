---
id: P0007
title: "Xcode 26.3 を macbox に導入。従来比一桁小さく、iOS SDK 同梱"
created: 2026-08-12
verified: 2026-08-12
constraint:
relates: [H0006]
validity: current
source_class: observation
verified_at: 
verified_against: 
---

## 事実（2026-08-12 実測）

Xcode 26.3（Apple Silicon 版）を macbox に導入した。

### サイズ

| 項目 | Xcode 26.3 | 従来（参考値） |
|---|---|---|
| .xip | 2.27GB | 8〜13GB |
| 展開後 | 3.7GB | 25〜33GB |

Metal ツールチェーンのアンバンドルと Apple Silicon 専用ビルドの
分離により、従来より一桁近く小さくなっている。

### 展開性能

- 展開時間: 1 分 54 秒（VM、8GB メモリ、215% CPU）

### 同梱 SDK

- iOS SDK（iPhoneOS26.2.sdk）が同梱済み。追加取得不要
- `xcrun --sdk iphoneos clang` / `ibtool` が使える
- `ibtool` は初回 `sudo xcodebuild -runFirstLaunch` が必要
  （それ以前は「A required plugin failed to load」で失敗する）

## 導入経路

1. iPad の Safari で developer.apple.com からダウンロード
   （Apple ID は必要だが無料アカウントで足りる。
   macOS 側の Apple Account 制限とは無関係）
2. 共有フォルダ /Volumes/My Shared Files/ex/devel/ 経由で macbox へ
3. ローカルへコピーしてから `xip --expand`
   （virtiofs 上での展開は避ける）

## Phase 2 への影響

これで Phase 2（Virtual Mac のホスト側改造）の前提が整った。
上流の scripts/build-ipad-app.sh が要求する
`xcrun --sdk iphoneos clang` / `ibtool` が使える。

## 判断の誤り: 「疑った側が誤っていた」3 例目

.xip が 2.27GB だったとき「従来は 8〜13GB なので小さすぎる」と
判断し、ダウンロード失敗を疑った。根拠は 1 年前の記事で、
しかもその記事自体が「22% 小さくなった」という縮小傾向を
報告していた。

正規の URL から取得したファイルであり、.xip は署名付きなので
`xip --expand` を実行すれば真偽が即座に分かる。
推測ではなく検証すべきだった。結果として 2GB 超のダウンロードを
3 回させることになった。

→ H0006 に 3 例目として追記。
