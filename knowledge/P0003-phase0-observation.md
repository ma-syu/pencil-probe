---
id: P0003
title: "Phase 0 観測結果: ゲストには mouse イベントのみ届き、筆圧・傾きは無い"
created: 2026-08-10
verified: 2026-08-10
constraint:
relates: [P0001, P0002]
validity: current
source_class: observation
verified_at: 
verified_against: 
---

## 事実（2026-08-10 実測）

pencil-probe を VM ゲスト内で実行し、Apple Pencil で描画操作を行った。
ログは `~/pencil-observation.log`（2047 行、3 ストローク分）。

### 1. イベント種別: mouse のみ

全イベントが `leftMouseDown` / `leftMouseDragged` / `leftMouseUp` /
`mouseMoved`。`tabletPointer` / `tabletProximity` は 0 件。
subtype も全て `mouse`（tablet point / tablet proximity なし）。

### 2. 筆圧: 二値のみ

`mPressure` は Down/Dragged 中に `1.0000`、Up/Moved で `0.0000`。
連続値（0.0–1.0 の中間値）は一度も出現しなかった。
`tPressure`（tablet 圧力フィールド）は常に `0`。

### 3. 傾き: 常にゼロ

`tiltX` / `tiltY` は全行 `0.0000`。

### 4. 座標: 固定値の混入（副次的発見）

実座標と `391.6 / 317.5` という固定座標が交互に出現する。
固定値は UIKit のポインタ絶対座標がそのまま漏れ出ていると推測される。

```
275752566798.000	mouse	leftMouseDragged	mouse	375.0	119.5	1.0000	0	0.0000	0.0000
275752722719.000	mouse	leftMouseDragged	mouse	391.6	317.5	1.0000	0	0.0000	0.0000
275752727218.000	mouse	leftMouseDragged	mouse	375.5	119.0	1.0000	0	0.0000	0.0000
275752924159.000	mouse	leftMouseDragged	mouse	391.6	317.5	1.0000	0	0.0000	0.0000
275752925103.000	mouse	leftMouseDragged	mouse	375.5	118.0	1.0000	0	0.0000	0.0000
```

### 5. サンプリングレート: 約 5Hz（副次的発見）

実座標イベントの間隔は約 200ms（~200,000 タイムスタンプ単位）。
Apple Pencil のネイティブレートは 240Hz であり、ホスト側で大幅に間引かれている。
描画品質に直接影響する問題。

## phase0-spec.md 成功条件の判定

| # | 観測項目 | 結果 | 判定 |
|---|---|---|---|
| 1 | イベント種別 | mouse のみ。tablet イベントなし | 観測できた |
| 2 | 座標 | 取得できるが固定値が交互に混入 | 観測できた（問題あり） |
| 3 | 筆圧 | mPressure 0/1 の二値。tPressure 常に 0 | **筆圧なし確定** |
| 4 | 傾き | tiltX / tiltY 常に 0 | **傾きなし確定** |

4 点すべて観測でき、Phase 0 の成功条件を満たす。

## 判定結果と次の行動

phase0-spec.md の判定表に照らすと:

> **mouse イベントで pressure が 0/1 → ホスト側の改造が必要**

P0001（入力経路分析）で判明していた「ホスト側が筆圧を読んでいない」
「転送経路に筆圧フィールドが無い」という事実と完全に一致する。

Phase 1 では以下を行う:
1. ゲスト内で CGEvent tablet イベントを合成注入し、
   クリスタが受け付けるか検証する（spec の「経路 A」、2 の検証）
2. 成功すれば、ホスト側改造の設計に進む
