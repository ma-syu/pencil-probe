# P0011: Phase 2 段階 0 — iPad で touch.force が取得できることを確認

status: referenced
refs: P0001, P0010
date: 2026-08-13

## 観測

iPadOS ホスト上の VirtualMacOniPad を改造し、
`UITouchTypePencil` のタッチで `touch.force` をログ出力した。

Apple Pencil (iPad Pro M2) で描画したところ、
`/var/tmp/pencil.log` に筆圧の連続値が記録された。

## データの範囲

| フィールド | 最小値 | 最大値 | 備考 |
|---|---|---|---|
| force | 0.0000 | ~1.74 | ペンを離すと 0、強く押すと増加 |
| maxForce | 4.1667 | 4.1667 | 一貫。正規化: force / maxForce |
| altitude | 0.6490 | 1.1963 | ラジアン。ペンの傾き |
| azimuth | -0.5634 | 1.4067 | ラジアン。ペンの方向 |

## ストローク構造

- `began` → `moved` × N → `ended` の正常なシーケンス
- `ended` の force は常に 0.0000
- 座標は iPad 画面の points 単位（~200–970 × ~60–1004）

## Phase 2 段階 0 の判定

**成功。** force が 0.0〜最大値の連続値として変化しており、
筆圧に応じた値が取得できることが確定した。

Phase 2 仕様の前提「iPadOS 側で touch.force が取得できるか」→ 可能。

## 次のステップ

段階 1: TCP プロトコル設計とゲストへの送信実装。
