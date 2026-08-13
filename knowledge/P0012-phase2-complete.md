---
id: P0012
title: "Phase 2 完了: Apple Pencil 筆圧が macOS ゲストのクリスタで動作"
created: 2026-08-13
constraint:
relates: [P0010, P0011, P0003]
validity: current
source_class: observation
verified_at: 2026-08-13T17:10+09:00
verified_against: ユーザによるクリスタでの実描画テスト
---

# Phase 2 完了: Apple Pencil 筆圧が macOS ゲストのクリスタで動作

## 観測結果

Phase 2 の成功条件「Apple Pencil でクリスタのキャンバスに描画したとき、
筆圧に応じて線の太さが変わる」を達成した。

- 筆圧に応じて線の太さが変化する
- クリスタの筆圧調整機能で筆圧グラフが正しく表示される
- 体感遅延なし（ペンタブレット素人の主観評価）
- Pencil リフト時の余計な線なし（パッチ v2 の early return で修正済み）

## 構成

| コンポーネント | 内容 |
|---|---|
| iPad (ホスト) | VirtualMac パッチ v2。Pencil の touch.force を TCP 送信 |
| macOS VM (ゲスト) | pencil-probe relay。TCP 受信 → CGEventPost で tablet イベント注入 |
| プロトコル | 13 バイト/イベント（type + pressure + x + y） |
| ネットワーク | 直接 TCP。ゲスト 192.168.1.2:9923、iPad 192.168.1.15 のみ許可 |

## セキュリティに関する注記

spec では SSH ポートフォワード経由を推奨していたが、
テスト時は直接 TCP + IP フィルタ（`--allow`）で実施。
レイテンシが問題ないことが確認できたため、
SSH ポートフォワードへの切り替えを検討可能。

## 次のステップ候補

- SSH ポートフォワードによるセキュリティ強化
- 上流 PR の準備
- 傾き（azimuth/altitude）の転送追加
