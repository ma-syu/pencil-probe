---
id: P0002
title: OpenDisplay が同じ課題（Pencil の筆圧・傾きを Mac へ送る）を扱っている
created: 2026-08-10
verified: 2026-08-10
constraint:
relates: [P0001]
validity: current
source_class: observation
verified_at: 
verified_against: 
---

## 事実

`github.com/peetzweg/opendisplay` は iPhone/iPad を Mac の外部ディスプレイ
として使うオープンソースプロジェクト。Virtualization.framework ではなく
`CGVirtualDisplay`（非公開 CoreGraphics API）を使い、
H.264 ストリームで映像を転送する。

## Pencil 対応の実装状況

Issue #4 で Pencil の筆圧・傾き対応が roadmap に挙げられていた。
設計方針は以下の 3 点。

1. **iPad 側**: `UITouch` の `force` `altitudeAngle` `azimuthAngle` と
   coalesced touches を取得
2. **Mac 側**: 標準 mouse イベントではなく `CGEvent` の **tablet イベント**
   （proximity + pointer events with pressure/tilt fields）を発行
3. **パーム・リジェクション**: UIKit の Pencil/touch 区別をそのまま利用

### 実装済み（確認済み）

- **PR #163** "Apple Pencil support w/ pressure/tilt/proximity"
  2026-07-20 作成、jlfwong 氏（外部コントリビュータ）、6 tasks done
  （出典: GitHub PR 一覧を人間が直接確認、2026-08-10）
- **v1.15.0** で筆圧・チルト・ホバー（12mm）に対応
  （出典: リリースノートを人間が直接確認、2026-08-10）
- Apple Pencil Pro のバレルロールは未対応

### 文書と実態の乖離

Issue #4 は Open のまま、README も roadmap 表記のまま。
文書が実装に追いついていない。

**教訓**: Issue の状態だけで実装の有無を判断しない。
外部コントリビュータの PR は Issue に自動リンクされないことがある。
確認すべき経路: PR 一覧、リリースノート、CHANGELOG、報道。

### フォローアップ issue

以下は WebFetch で取得したページに含まれていた番号であり、**実在は未確認**。

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
OpenDisplay は v1.15.0 で CGEvent tablet イベントによる筆圧転送を実現しており、
pencil-probe の経路 A（ゲスト内 CGEventPost）の実現可能性を裏付ける。

## ライセンス制約

- **OpenDisplay**: GPL-3.0
- **VirtualMacOniPad**: MIT

GPL-3.0 のコードを MIT プロジェクトに取り込むと、
**取り込んだ側全体が GPL-3.0 の条件に従う義務が生じる**。
VirtualMacOniPad は MIT で上流に PR を出す前提のため、
OpenDisplay のコードを直接利用・翻案することはできない。

**設計方針の参照のみに留め、実装は独立に行う。**

v1.15.0 で動くコードが存在するため、参照の誘惑が強くなる。
GPL コードを「参考にしただけ」でも翻案と見なされるリスクがある。

具体的には:
- Issue #4 の設計方針（UITouch → CGEvent tablet events）は一般的な技術知識
- **PR #163 の差分・OpenDisplay のソースコードは読まない**
- 同じ公開 API（CGEvent、UITouch）を使うこと自体はライセンス問題にならない
- Apple 公式ドキュメントと CGEvent.h のヘッダから独立に実装する

## 参照

- https://github.com/peetzweg/opendisplay（README）
- https://github.com/peetzweg/opendisplay/issues/4
