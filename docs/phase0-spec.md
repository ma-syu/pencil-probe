# Phase 0 仕様: 入力イベントの観測

## 目的

Apple Pencil の入力が **ゲスト macOS にどう届いているか**を実測する。
推測で実装を始めると、届いていない情報を変換しようとして時間を浪費する。

---

## 上流ソース調査で判明している事実

実装前に `VirtualMacOniPad` のソースを読んで確認した内容。
**これらは実測で裏付けを取る対象であって、前提として信じきらないこと。**

### ホスト側（iPadOS）は筆圧を読んでいない

`vz/host/VirtualMacApp.m` の `touchesBegan:` / `touchesMoved:` は
`[touch locationInView:]` のみを読み、`touch.force` を参照していない。

```objc
CGPoint point = [touch locationInView:self];
sendPointer(point, self.bounds, activePointerButtons());
```

### 転送経路に筆圧のフィールドが無い

ゲストへの送信は非公開クラス経由で行われる。

```objc
_VZScreenCoordinatePointerEvent
    initWithLocation:pressedButtons:
```

**引数は座標とボタンマスクのみ。** 筆圧・傾き・回転を運ぶ余地がない。
`sendMagnifyEvents:` `sendRotationEvents:` `sendSmartMagnifyEvents:` も
あるが、いずれもジェスチャ用で筆圧とは無関係。

### ただし touch.type は既にログに出ている

```objc
printf("[VirtualMac] touch began type=%ld buttons=0x%lx\n",
       (long)touch.type, (unsigned long)gTouchButtons);
```

`UITouchType` は `.direct`(0) `.indirect`(1) `.pencil`(2) `.indirectPointer`(3)。
**この既存ログを見るだけで、Pencil が Pencil として認識されているかが分かる。**

### この事実から導かれる見通し

ホスト側が筆圧を読まず、転送経路にも枠が無い以上、
**ゲストに筆圧が届いている可能性は低い**。
Phase 0 はこの見通しを確認し、次に何をすべきかを確定させるためにある。

---

## 成功条件（これが満たされれば Phase 0 完了）

以下 4 点が**ログとして観測できる**こと。値の内容は問わない。
「届いていない」ことが確認できるのも成功。

| # | 観測項目 | 判定 |
|---|---|---|
| 1 | イベント種別 | mouse か tablet か。`CGEventType` の値 |
| 2 | 座標 | 描画中に連続した座標列が取れるか |
| 3 | 筆圧 | `kCGMouseEventPressure` / `kCGTabletEventPointPressure` の値 |
| 4 | 傾き | `kCGTabletEventTiltX` / `TiltY` の値 |

3 が常に 0 または 1 の二値なら「筆圧なし」が確定する。

### 判定結果ごとの次の行動

| 観測結果 | Phase 1 で何をするか |
|---|---|
| tablet イベントで pressure が連続値 | 実装不要。既に動いている |
| mouse イベントで pressure が 0/1 | ホスト側の改造が必要（後述の調査へ） |
| そもそもイベントが届かない | EventTap の権限か VM の入力経路を疑う |

---

## 非目標（Phase 0 では作らない）

- 筆圧の**注入**（Phase 1）
- ホスト⇔ゲストの通信（Phase 3）
- GUI
- Virtual Mac 本体の改造

観測だけに絞る。ここで実装を広げると、何が原因で動かないか切り分けられない。

---

## 実装の制約

### 構成

```
Sources/
├── Core/    イベント情報の整形・分類（純粋）
└── IO/      CGEventTap の設置、ログ出力
```

`docs/architecture.md` の分離規約に従う。
Core には `docs/rationale.md` の方針に沿ってプロパティテストを付ける。

### 想定される障害

**アクセシビリティ権限**: `CGEventTap` はシステム全体の入力監視にあたり、
「システム設定 > プライバシーとセキュリティ > アクセシビリティ」での
許可が必要。**VM 内でこの許可ダイアログが正常に出るかは未検証。**

出ない、または許可しても効かない場合は、以下を順に試す。

1. `tccutil` での確認（`tccutil reset Accessibility` は他の許可も消すので注意）
2. アプリ内のイベント（`NSView` の `mouseDragged:`）のみを観測する方式へ変更
   → システム全体は見えないが、自前ウィンドウ上の入力は取れる

2 に切り替えた場合、**観測範囲が狭まることを明記して報告すること。**
「クリスタ上でどう見えるか」は別途確認が必要になる。

### ビルド

Xcode は無い。`swift build` / `swift test`（Swift Package Manager）を使う。
`Package.swift` が必要なら作成してよい。

---

## Phase 0 で課題が見つかった場合の調査手順

「筆圧が届いていない」と判明した場合、**なぜ届かないか**と
**どうすれば届けられるか**を上流ソースから調べる。

### 読むべき箇所

```bash
# ホスト側の入力処理
vz/host/VirtualMacApp.m  の VZInputView（765行付近〜）
  - touchesBegan: / touchesMoved:     touch.force を読んでいないことの確認
  - sendPointer()（181行付近）          転送の実装
  - handleHover:                       ホバー時の座標

# 既存のシム群（新しい入力経路を足す際の手本）
vz/host/NSViewShim.m
vz/host/vmmhook.m
vz/host/vzxpchook.m
```

### 調査で明らかにすべきこと

| 問い | 調べ方 |
|---|---|
| `_VZScreenCoordinatePointerEvent` 以外に入力イベントのクラスがあるか | `class-dump` / `nm` で Virtualization.framework のシンボルを列挙 |
| ゲスト側で受け取っているのは何のデバイスか | ゲスト内で `ioreg` / `hidutil list` を実行 |
| ホスト⇔ゲストで別経路を作れるか | 既存の仮想 USB 実装（DFU 用）が転用できるか |

### 想定される 3 つの実装経路

`docs/rationale.md` には書いていない設計判断なので、
調査結果が出たら比較表を作って報告すること。

| 経路 | 概要 | 難易度 |
|---|---|---|
| A: ゲスト内アプリ + CGEventPost | ホストから座標＋筆圧を送り、ゲスト内で合成イベントを注入 | 中。**VM 本体を触らない** |
| B: 仮想 HID デバイス | タブレットとして認識させる | 高。Virtualization.framework に枠が無い |
| C: ホスト側フレームワークにフック | 既存シムと同じ流儀 | 最高。非公開 ABI 依存 |

**A を第一候補とする。** VM 本体を改造せず、独立して検証でき、
失敗しても環境を壊さないため。ブリッジネットワークが使えるので
ホスト⇔ゲストの通信は TCP で足りる。

ただし A には未確認の前提が 2 つある。

1. iPadOS 側で `touch.force` が取得できるか
   （`UIPointerInteraction` 経由だと落ちている可能性）
2. クリスタが `CGEventPost` の合成タブレットイベントを受け付けるか
   （Astropad 等が動作している実績から可能性は高いが未検証）

**2 は Phase 1 で、Virtual Mac を一切触らずに検証できる。**
固定値の筆圧イベントを注入して線の太さが変われば確定する。
1 より先に 2 を確かめる方が、投資判断が早くできる。

---

## 先行事例: OpenDisplay（参照のみ）

`github.com/peetzweg/opendisplay` が同じ課題（Pencil の筆圧・傾きを
Mac アプリへ送る）を扱っている。詳細は `knowledge/0007` に記録。

### 設計方針（Issue #4）

1. iPad 側で `UITouch` の `force` `altitudeAngle` `azimuthAngle` +
   coalesced touches を取得
2. Mac 側で `CGEvent` の **tablet イベント**
   （proximity + pointer events with pressure/tilt fields）を発行
3. パーム・リジェクションは UIKit の Pencil/touch 区別をそのまま利用

OpenDisplay は `CGVirtualDisplay` + TCP で映像を転送する方式であり、
Virtualization.framework の VM とは異なるが、
**Mac 側の注入手法（CGEvent tablet events）は本プロジェクトの経路 A と共通**。
OpenDisplay でこの方式が動作しているなら、経路 A の実現可能性を裏付ける。

### ライセンス制約

| プロジェクト | ライセンス |
|---|---|
| OpenDisplay | **GPL-3.0** |
| VirtualMacOniPad | MIT |

GPL-3.0 のコードを MIT プロジェクトに取り込むと全体が GPL 化する。
VirtualMacOniPad へ MIT で PR を出す前提のため、
**OpenDisplay のコードは参照しない。設計方針の参照のみに留める。**

同じ公開 API（`CGEvent`、`UITouch`）を使うこと自体はライセンス問題にならない。
