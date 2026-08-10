# Phase 1 仕様: CGEventPost による tablet イベント注入の検証

## 目的

macOS のペイントアプリが、`CGEventPost` で合成した tablet イベントを
**筆圧として受け付けるか**を検証する。

### なぜ先にやるか

Phase 0 で「ゲストには mouse イベントのみ届き、筆圧・傾きは無い」ことが
確定した（`knowledge/P0003`）。筆圧を届けるには経路 A（ゲスト内で
CGEventPost により tablet イベントを合成注入する方式）が第一候補である。

この検証は **Virtual Mac を一切触らずに実行できる**。
通れば「あとは値を運ぶだけ」になり、通らなければ macOS 経路を
諦める判断ができる。投資対効果が最も高い。

---

## Phase 0 からの経緯

Phase 0（`docs/phase0-spec.md`）の判定表:

> **mouse イベントで pressure が 0/1 → ホスト側の改造が必要**

Phase 0 spec の「経路 A」の未確認前提 2 点のうち、本 Phase で検証するのは:

> 2. クリスタが `CGEventPost` の合成タブレットイベントを受け付けるか

1（iPadOS 側で `touch.force` が取得できるか）は Phase 2 で扱う。

---

## 成功条件

固定値の筆圧（例: 0.5）を持つ `tabletPoint` イベントを `CGEventPost` で
注入したとき、**受け手のアプリが pressure を非二値の値として認識する**こと。

具体的には、以下のいずれかで確認できれば成功:

- 筆圧可視化ツールが 0.5 付近の値を表示する
- ペイントアプリの線の太さが、通常のマウスクリックと異なる

### 判定結果ごとの次の行動

| 観測結果 | 次の行動 |
|---|---|
| アプリが筆圧を非二値で認識 | Phase 2（iPadOS 側の筆圧取得）へ進む |
| アプリが筆圧を無視する（二値のまま） | tablet proximity イベントの有無、subtype の設定を見直す |
| イベント自体が届かない | アクセシビリティ権限、EventTap との競合を疑う |
| 全アプリで失敗 | 経路 A を断念し、経路 B/C を検討する |

---

## 検証対象（この順序で）

投資判断を早くするため、無料で結果が明確なものから試す。

| 順序 | アプリ | 理由 |
|---|---|---|
| 1 | PenInspector（`github.com/borco/peninspector`） | 筆圧を数値で可視化。判定が最も明確。無料 |
| 2 | Krita | 無料。実装が公開されており、失敗時の原因調査が可能 |
| 3 | FireAlpaca | 無料。macOS 版あり。別実装での再現確認 |
| 4 | クリスタ（CLIP STUDIO PAINT） | 本命だが有料。上記で通れば高い確度で通る |

1 で成功すればイベント合成の正当性が確認でき、
2–4 はアプリ固有の挙動確認になる。

### 検証の段階（アプリより先に自作ツールで確認する）

| 段階 | 手段 | 確認できること |
|---|---|---|
| 0 | Phase 0 の EventTap | 注入が成功し、フィールドが期待通りか |
| 1 | PenInspector | 第三者のツールが筆圧として解釈するか |
| 2–4 | ペイントアプリ | 実用アプリが受け付けるか |

段階 0 で失敗すれば、アプリ側の問題ではないと即座に切り分けられる。
既存の Phase 0 観測ツールを活用する。

**注意**: CGEventTap は注入されたイベントも観測するため、
観測と注入を同一プロセスで行うと相互作用する。
別プロセスにするか、注入時は観測を止めること。

---

## 非目標（Phase 1 では扱わない）

- iPadOS 側からの筆圧取得（Phase 2）
- ホスト⇔ゲストの通信経路（Phase 3）
- Virtual Mac 本体の改造
- 可変の筆圧値の注入（固定値で十分）
- レイテンシやサンプリングレートの最適化

---

## 実装の制約

### ライセンス

OpenDisplay（GPL-3.0）のコードは読まない（`knowledge/P0002` 参照）。
Apple 公式ドキュメントと `CGEvent.h` を一次情報とする。

### 構成

```
Sources/
├── Core/    イベント構築のパラメータ組み立て（純粋）
└── IO/      CGEventPost の実行、アクセシビリティ権限の取得
```

既存の Phase 0 コード（EventTap による観測）と共存させる。
Phase 0 が「読む」側、Phase 1 が「書く」側。

### テスト

Core にはプロパティテストを付ける。
tablet イベントのフィールド設定（筆圧値の範囲、subtype の正当性など）が
プロパティテストの主な対象になる。

### ビルド

`swift build` / `swift test`（Swift Package Manager）。
Xcode は使わない。

### セキュリティ

`CLAUDE.md` のセキュリティ制約に従う。
イベント注入は `CGEventPost` でローカルに行い、ネットワークは使わない。

---

## 技術的な見通し

### 受け手アプリの挙動（推測）

Apple の ForceTouchCatalog サンプルによれば、受け手のアプリは
`event.subtype == .tabletPoint` と `event.pressure` を見ているだけで、
イベントの出所を検証していない。標準的な実装なら通る見込み。

### 注入に必要なイベント構成（一次情報から）

`CGEvent.h` と Apple ドキュメントに基づく。実装時に検証すること。

1. **Tablet proximity イベント**: デバイスの接近を通知。
   これが先に来ないとアプリが tablet モードに入らない可能性がある
2. **Tablet point イベント**: 座標 + 筆圧 + 傾き。
   `kCGTabletEventPointPressure` に筆圧値を設定（型と値域は下記で確認）
3. **subtype の設定**: `kCGEventMouseSubtype` を
   `kCGEventMouseSubtypeTabletPoint` に設定する必要がある

### 一次情報の確認（実装前に必須）

`kCGTabletEventPointPressure` の型と値域を、推測ではなく `CGEventTypes.h` で確認する。

```bash
grep -n 'kCGTabletEvent' \
  "$(xcrun --show-sdk-path)/System/Library/Frameworks/CoreGraphics.framework/Headers/CGEventTypes.h"
```

`CGEventSetIntegerValueField` か `CGEventSetDoubleValueField` かで扱いが変わる。
値が入っているのに反映されない、という分かりにくい失敗を避ける。

### 想定される障害

| 障害 | 対処 |
|---|---|
| アクセシビリティ権限が必要 | Phase 0 で取得済みなら追加不要。未取得なら手動で許可 |
| proximity イベント無しだと筆圧が無視される | proximity → point の順序で注入 |
| 特定アプリが独自のデバイス検証をしている | 検証対象の順序に従い、通るものから確認 |
| VM 環境固有の制限で CGEventPost が効かない | Phase 0 の EventTap で注入イベントが観測できるか確認 |
