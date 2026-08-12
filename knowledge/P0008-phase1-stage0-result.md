---
id: P0008
title: "Phase 1 段階 0: CGEventPost による tablet イベント注入が observer に届くことを確認"
created: 2026-08-12
verified: 2026-08-12
constraint:
relates: [P0003, P0004]
---

## 事実（2026-08-12 実測）

Phase 0 の EventTap（observer）を動かした状態で、
Phase 1 の TabletInjector（inject）を実行し、
合成した tablet イベントが observer に届くことを確認した。

### 観測されたイベント

```
subtype             x      y      mPressure  tPressure
tabletProximity  400.0  400.0     0.0000     0.0000    ← proximity enter
tabletPoint      400.0  400.0     0.4980     0.5000    ← mouseDown + 筆圧
```

### 確認できたこと

- `kCGTabletEventPointPressure`（tPressure）に 0.5000 が正確に設定された
- `kCGMouseEventPressure`（mPressure）は 0.4980 でわずかに丸められた
- subtype が `tabletPoint` / `tabletProximity` として正しく認識された
- P0004 の合成手順（subtype を先に設定 → フィールド設定 → post）が機能した

### 確認できなかったこと

- drag / mouseUp / proximity leave のイベントが記録されなかった
  - inject が高速に完了し observer が取りこぼした可能性
  - 段階 0 の成功判定には影響しない

### 権限に関する注意

- `CGPreflightPostEventAccess()` は false を返すが、実際の post は成功する
- **SSH 経由では CGEventPost のイベントが配送されない**
  - GUI ターミナル（Terminal.app）から実行する必要がある
  - SSH 経由だと inject は「complete」と報告するが observer にイベントが届かない
  - H0007（SSH GUI 認証）と同じパターン

## 判定

phase1-spec.md 段階 0 の成功条件:
> 注入が成功し、フィールドが期待通りか

**成功。** 段階 1（PenInspector で第三者ツールが筆圧として解釈するか）に進める。
