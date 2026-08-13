---
id: P0001
title: Virtual Mac の入力転送経路には筆圧のフィールドが無い
created: 2026-08-09
verified: 2026-08-09
constraint:
relates: [P0003]
validity: current
source_class: observation
verified_at: 
verified_against: 
---

## 事実

`VirtualMacOniPad` のホスト側（iPadOS）は、タッチイベントから
**座標とボタンマスクしか読んでいない**。

`vz/host/VirtualMacApp.m` の `VZInputView`:

```objc
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    sendPointer(point, self.bounds, activePointerButtons());
}
```

`touch.force` `touch.altitudeAngle` `touch.azimuthAngle` は参照されていない。

## ゲストへの転送経路

`sendPointer()` は Virtualization.framework の非公開クラスを使う。

```objc
_VZScreenCoordinatePointerEvent
    initWithLocation:pressedButtons:
```

**引数は座標とボタンマスクのみ。** 筆圧・傾き・回転を運ぶ枠がない。

同じデバイスに `sendMagnifyEvents:` `sendRotationEvents:`
`sendSmartMagnifyEvents:` もあるが、いずれもジェスチャ用。

## 既に取れている情報

`touchesBegan:` は touch.type をログ出力している。

```objc
printf("[VirtualMac] touch began type=%ld buttons=0x%lx\n",
       (long)touch.type, (unsigned long)gTouchButtons);
```

`UITouchType`: `.direct`(0) `.indirect`(1) `.pencil`(2) `.indirectPointer`(3)。
**Pencil で画面に触れて `type=2` が出れば、iPadOS 側では Pencil として
認識されている**ことが確認できる。改造なしで分かる唯一の手掛かり。

## この事実から導かれること

ホスト側が読まず、転送にも枠が無いので、
**ゲストに筆圧が届いている可能性は低い**。

Phase 0 の観測はこの見通しの確認であり、
「届いていない」と判明することも成功とみなす。

## 実装経路の候補

| 経路 | 概要 | VM 本体の改造 |
|---|---|---|
| A | ゲスト内アプリ + `CGEventPost` で合成イベント注入 | 不要 |
| B | 仮想 HID タブレットデバイス | 必要。枠が無く困難 |
| C | ホスト側フレームワークにフック | 必要。非公開 ABI |

A を第一候補とする理由は、VM を触らず独立して検証でき、
失敗しても環境を壊さないため。ブリッジネットワークが使えるので
ホスト⇔ゲスト通信は TCP で足りる。

A の未確認の前提は 2 つ。

1. iPadOS 側で `touch.force` が実際に取得できるか
2. クリスタが `CGEventPost` の合成タブレットイベントを受け付けるか

**2 は Virtual Mac を一切触らずに検証できる**（固定値の筆圧を注入して
線の太さが変わるか見るだけ）。1 より先に 2 を確かめる方が、
投資判断が早い。

## 再検証: 上流 1.1.1（df4f50c）（2026-08-12）

上流を 1.1.1（df4f50c）まで更新した。18,449 行追加、
VirtualMacApp.m も 1,286 行変わったが、P0001 の結論は変わらない。

- タッチ処理が書き直された（`directTouchKey` /
  `beginDeferredDirectTouches` / `moveDeferredDirectTouches`）
- ただし `if (touch.type != UITouchTypeDirect) continue;` で
  **Apple Pencil は明示的に除外**されている
- `touch.force` は依然として読まれていない
- `_VZScreenCoordinatePointerEvent` の引数は座標とボタンのみ
- Info.plist に `UIBackgroundModes` は無い（変更はバージョン番号のみ）

Pencil の筆圧は「未実装」ではなく「意図的に扱っていない」可能性がある。
上流に issue を立てる際はこの点を踏まえる。

## 参照

調査対象は `github.com/nfzerox/VirtualMacOniPad`。
上流へ PR を出す場合、既存コメントの文体に合わせること
（`docs/comment-style.md` に手本を引用してある）。
