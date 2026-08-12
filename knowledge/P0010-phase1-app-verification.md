---
id: P0010
title: "Phase 1 完了: スタンドアロン tabletPointer でクリスタが筆圧を認識"
created: 2026-08-12
verified: 2026-08-12
constraint:
relates: [P0004, P0008, P0009]
---

## 事実（2026-08-12 実測）

### 方式 (a) vs (b) の結果

P0004 §7 の 2 つの配送形式を検証した。

| 形式 | CGEvent type | NSView callback | アプリの反応 |
|---|---|---|---|
| (a) mouse + tablet subtype | leftMouseDown 等 | mouseDown(with:) | 筆圧は NSEvent.pressure に届くがアプリは無視 |
| (b) standalone tabletPointer | kCGEventTabletPointer | tabletPoint(with:) | **クリスタが筆圧を認識** |

### 方式 (a) の失敗（P0009 の追加検証）

- PenInspector（Qt）: 反応なし
- Krita（Qt）: 線は描かれるが太さ一定
- FireAlpaca（Qt）: 同上
- CLIP STUDIO PAINT: 同上

全アプリが `tabletPoint(with:)` で筆圧を読んでおり、
`mouseDown(with:)` の `event.pressure` は読んでいなかった。

### 方式 (b) の成功

方式 (a) + (b) を両方 post するように変更した結果:

- **CLIP STUDIO PAINT: inject の線が細くなった**（筆圧 0.5 として認識）
  - トラックパッド / Apple Pencil の線は太いまま（pressure = 1.0）
  - inject の線のみ細い = 筆圧が非二値で反映されている

### pressure-check.swift による確認

```
# inject（合成 tablet）
mouseDown    subtype=1  pressure=0.49803922  ← 筆圧 0.5

# Apple Pencil（Virtual Mac 経由、比較用）
mouseDown    subtype=0  pressure=1.0         ← 二値のまま（P0003 と一致）
```

- `tabletPoint(with:)` / `tabletProximity(with:)` は方式 (b) でも
  pressure-check には配送されなかった
- しかしクリスタは認識した。クリスタは独自の低レベル処理を持つと推測

### Qt アプリが認識しなかった理由

Qt は `tabletPoint:` NSEvent を QTabletEvent に変換するが、
CGEventPost で合成した standalone tabletPointer イベントは
Qt のイベントフィルタを通過しない。
Qt 固有の制限であり、macOS の制限ではない。

## Phase 1 の判定

phase1-spec.md の成功条件:
> 受け手のアプリが pressure を非二値の値として認識する

**成功。** CLIP STUDIO PAINT（本命のペイントアプリ）が筆圧 0.5 を認識し、
線の太さに反映した。

## 次の行動

phase1-spec.md の判定表:
> アプリが筆圧を非二値で認識 → Phase 2（iPadOS 側の筆圧取得）へ進む

Phase 2 では iPadOS 側で `touch.force` を取得し、
TCP 経由でゲストに送り、この CGEventPost 経路で注入する。
