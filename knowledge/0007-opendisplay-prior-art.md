---
id: 0007
title: OpenDisplay が同じ課題（Pencil の筆圧・傾きを Mac へ送る）を扱っている
created: 2026-08-10
verified: 2026-08-10
constraint:
relates: [0003]
---

## 事実

`github.com/peetzweg/opendisplay` は iPhone/iPad を Mac の外部ディスプレイ
として使うオープンソースプロジェクト。Virtualization.framework ではなく
`CGVirtualDisplay`（非公開 CoreGraphics API）を使い、
H.264 ストリームで映像を転送する。

## Pencil 対応の設計方針（Issue #4）

Issue #4 で Pencil の筆圧・傾き対応が roadmap に挙げられていた。
設計方針は以下の 3 点。

1. **iPad 側**: `UITouch` の `force` `altitudeAngle` `azimuthAngle` と
   coalesced touches を取得
2. **Mac 側**: 標準 mouse イベントではなく `CGEvent` の **tablet イベント**
   （proximity + pointer events with pressure/tilt fields）を発行
3. **パーム・リジェクション**: UIKit の Pencil/touch 区別をそのまま利用

Issue #4 のページ（2026-08-10 取得）では PR #163 でマージ済み
（"feat(ios): Apple Pencil input with pressure, tilt and proximity"、
2026-08-02）と読める。ただしこの情報は WebFetch の AI 要約であり、
README 側では依然 roadmap 扱いだった。**実装状況は要再確認。**

実装済みであれば、フォローアップとして以下が挙がっている。

- #189: パーム・リジェクションのエッジケース
- #190: InputInjector の切断時の状態保持
- #191: predicted touch によるレイテンシ削減（描画への影響が最大）
- #192: Apple Pencil Pro のバレルロール対応

## pencil-probe との関係

OpenDisplay と pencil-probe は**同じ問題を別の経路で解いている**。

| | OpenDisplay | pencil-probe |
|---|---|---|
| 転送方式 | CGVirtualDisplay + TCP | Virtualization.framework の VM |
| iPad 側 | 専用アプリ | VirtualMacOniPad（他者のアプリ） |
| Mac 側 | CGEvent tablet イベント注入 | 同じ（候補 A） |
| Pencil 取得 | UITouch プロパティ直接 | ホスト側改造が必要 |

**Mac 側の注入手法（CGEvent tablet events）は共通。**
OpenDisplay が CGEvent tablet イベントで筆圧を Mac アプリに届けられている
なら、pencil-probe の経路 A（ゲスト内 CGEventPost）も実現可能性が高い。

## ライセンス制約

- **OpenDisplay**: GPL-3.0
- **VirtualMacOniPad**: MIT

GPL-3.0 のコードを MIT プロジェクトに取り込むと、
**取り込んだ側全体が GPL-3.0 の条件に従う義務が生じる**。
VirtualMacOniPad は MIT で上流に PR を出す前提のため、
OpenDisplay のコードを直接利用・翻案することはできない。

**設計方針の参照のみに留め、実装は独立に行う。**

具体的には:
- Issue #4 の設計方針（UITouch → CGEvent tablet events）は一般的な技術知識
- コード（PR #163 の差分など）は参照しない
- 同じ公開 API（CGEvent、UITouch）を使うこと自体はライセンス問題にならない

## 参照

- https://github.com/peetzweg/opendisplay（README）
- https://github.com/peetzweg/opendisplay/issues/4
