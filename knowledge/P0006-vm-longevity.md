---
id: P0006
title: "Virtual Mac を前面に保てば 14 時間以上生存する（jetsam 回避）"
created: 2026-08-12
verified: 2026-08-12
constraint:
relates: [P0003]
validity: current
source_class: observation
verified_at: 
verified_against: 
---

## 事実（2026-08-12 実測）

### 成功条件: Virtual Mac を前面 + 19W PD 充電

- Virtual Mac を前面にしたまま Magic Keyboard を閉じて 14 時間放置
- Anker 737（120W）PD 充電器。実際の供給は 19W（9V/2.11A）
- mainbox から SSH 接続、画面は消灯

結果:
- ChargeLimiter の 5 分データが 8/11 19:15 → 8/12 09:10 まで連続
- 温度は 33℃ 前後で安定。急落なし
- 残量は 71% → 68%（14 時間で 3%）

### 失敗条件: Virtual Mac を背面（8/10 の事例）

- Virtual Mac をホーム画面に戻した状態で放置
- 充電器 13W（5V/2.5A）
- 10 時間で 11% 減、VM が落ちた。アプリのアイコンも消失

充電器も異なるため単一要因の証明ではないが、
アイコン消失は jetsam による kill の挙動と一致する。

## メカニズム

**画面ロックとアプリの前面/背面は別の状態。**
Magic Keyboard を閉じてもアプリは前面のまま維持される。
背面に回すと jetsam の優先対象になり、8GB を保持する
Virtual Mac は真っ先に kill される。

## バッテリー消費の内訳（24 時間）

- 仮想 Mac 92%、ホームおよびロック画面 4%、Safari 2%、Sileo 2%
- 「画面オン 53 分 / 画面オフ 8 分」でこの比率
- 画面より VM の CPU 消費が支配的

## 運用指針

長時間放置する場合:
1. Virtual Mac を前面にしたまま Magic Keyboard を閉じる
2. 19W 以上の PD 充電器を使う
