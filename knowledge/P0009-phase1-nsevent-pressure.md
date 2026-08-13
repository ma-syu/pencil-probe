---
id: P0009
title: "Phase 1: NSEvent.pressure が合成 tablet イベントの筆圧 0.498 を正しく運ぶ"
created: 2026-08-12
verified: 2026-08-12
constraint:
relates: [P0004, P0008]
validity: current
source_class: observation
verified_at: 
verified_against: 
---

## 事実（2026-08-12 実測）

### NSEvent レベルで筆圧が届くことを確認

最小 AppKit アプリ（tools/pressure-check.swift）で検証。
CGEventPost で注入した tablet イベントが NSEvent として配送される際に、
pressure フィールドが保持されることを確認した。

```
# トラックパッド（通常マウス）
mouseDown    subtype=0  pressure=1.0        ← 二値

# 合成 tablet イベント（CGEventPost 経由）
mouseDown    subtype=1  pressure=0.49803922 ← 非二値。成功
mouseDragged subtype=1  pressure=0.49803922
mouseUp      subtype=1  pressure=0.49803922
```

- `subtype=1` = `NSEventSubtypeTabletPoint`（正しい）
- `pressure=0.49803922` ≈ 入力値 0.5（CGEvent 層の丸めによるずれ）
- 全 20 drag イベントで一貫した値

### tabletPoint(with:) は呼ばれない

NSView の `tabletPoint(with:)` オーバーライドには配送されなかった。
イベントは通常の `mouseDown(with:)` / `mouseDragged(with:)` として届き、
`event.subtype` と `event.pressure` でタブレットデータにアクセスする形。

P0004 §7 の方針 (a)「mouse イベント + tablet subtype」の設計通り。

### Qt アプリは筆圧を認識しなかった

| アプリ | 結果 |
|---|---|
| PenInspector（Qt） | 反応なし。イベント自体が認識されなかった |
| Krita（Qt） | 線は描かれたが太さ一定。筆圧は二値扱い |

原因: Qt は `QTabletEvent` を `tabletPoint:` NSEvent コールバック経由で
生成するが、合成イベントではこのコールバーが呼ばれない。
Qt が `mouseDown:` の `event.pressure` を読まないため、筆圧が無視される。

**これは Qt 固有の制限であり、macOS の制限ではない。**

### CGEvent observer との整合

同時に動かした EventTap observer のログ（/tmp/inject-detail.log）で
全 23 イベント（proximity 2 + point 21）が正しい subtype と筆圧で
配送されていることを確認済み。NSEvent 側の結果と一致する。

## 判定

phase1-spec.md の成功条件:
> 受け手のアプリが pressure を非二値の値として認識する

**NSEvent レベルで成功。** AppKit を直接使うアプリは筆圧を受け取れる。
Qt アプリは固有の制限で認識しない。

## 次の検証

- FireAlpaca / クリスタ（非 Qt）で実用アプリが筆圧を認識するか確認
- 認識すれば Phase 2（iPadOS 側の筆圧取得）へ進む
