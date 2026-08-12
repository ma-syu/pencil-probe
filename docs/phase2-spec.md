# Phase 2 仕様: iPadOS 側の筆圧取得とゲストへの転送

## 目的

Apple Pencil の筆圧（`touch.force`）を iPadOS ホスト側で取得し、
ゲスト macOS VM に転送して、Phase 1 で実証した CGEventPost 経路で
ペイントアプリに届ける。

### なぜこの順序か

Phase 1 で「CGEventPost の合成 tablet イベントをクリスタが筆圧として
認識する」ことが確定した（`knowledge/P0010`）。
残る未確認前提は 1 つ:

> iPadOS 側で `touch.force` が実際に取得できるか（P0001）

これが確認できれば、値を運ぶだけで筆圧が通る。

---

## Phase 1 からの経緯

| Phase | 成果 |
|---|---|
| 0 | ゲストには mouse イベントのみ。筆圧・傾きは届かない（P0003） |
| 1 | CGEventPost で kCGEventTabletPointer を注入するとクリスタが筆圧を認識（P0010） |
| **2** | **ホスト側で touch.force を読み、ゲストへ転送する** |

---

## 成功条件

Apple Pencil でクリスタのキャンバスに描画したとき、
**筆圧に応じて線の太さが変わる**こと。

### 判定結果ごとの次の行動

| 観測結果 | 次の行動 |
|---|---|
| 筆圧に応じて線の太さが変化 | 完成。最適化・安定化へ |
| touch.force が常に 0 | Apple Pencil の force が iPadOS UIKit で取れない環境固有の制限 |
| force は取れるがゲストに届かない | TCP 転送またはイベント注入のデバッグ |
| レイテンシが大きすぎて実用に耐えない | バッファリング・補間の最適化 |

---

## アーキテクチャ

```
iPad Pro M2 (ホスト)                      macOS VM (ゲスト)
┌────────────────────────┐    TCP       ┌────────────────────────┐
│ VirtualMacApp.m        │  (bridge)   │ pencil-probe           │
│                        │   LAN       │                        │
│ touchesBegan/Moved:    │────────────▶│ TCP 受信               │
│   touch.type == .pencil│  127.0.0.1  │ TabletInjector         │
│   touch.force          │  or LAN IP  │   CGEventPost          │
│   touch.azimuthAngle   │             │   kCGEventTabletPointer│
│   touch.altitudeAngle  │             │                        │
│   座標                  │             │ → クリスタ等に配送      │
└────────────────────────┘             └────────────────────────┘
```

### ネットワーク経路

ゲストはブリッジ接続で LAN 直結（192.168.1.2）。
ホスト（iPad）も同じ LAN にいる。

**セキュリティ制約**（CLAUDE.md）:
- ゲスト側リスナーは `127.0.0.1` にバインドする
- ホスト側から接続する場合は SSH ポートフォワードを使うか、
  ゲストの特定 IP のみ許可する
- `0.0.0.0` でのリッスンは禁止

**推奨構成**: ホスト → ゲストへの接続（push 型）。
ゲスト側は `127.0.0.1:指定ポート` でリッスンし、
ホストは SSH ポートフォワード経由で接続する。

---

## 非目標（Phase 2 では扱わない）

- 傾き（azimuth/altitude）の転送（筆圧が通ってから追加）
- レイテンシ最適化（まず動くことを優先）
- 複数ペンの同時サポート
- UI の整備（コマンドラインで動けばよい）

---

## 実装計画

### 段階 0: touch.force の取得確認

VirtualMacOniPad を改造し、Apple Pencil のタッチで
`touch.force` をログ出力する。

```objc
if (touch.type == UITouchTypePencil) {
    printf("[Pencil] force=%.4f azimuth=%.4f altitude=%.4f\n",
           touch.force,
           [touch azimuthAngleInView:self],
           touch.altitudeAngle);
}
```

現在の上流コード（1.1.1）では:
```objc
if (touch.type != UITouchTypeDirect) continue;  // Pencil を除外
```

この行を変更して Pencil も処理する。

**成功条件**: force が 0.0–最大値の連続値として出力される。

### 段階 1: プロトコル設計と TCP 送信

ホスト側に TCP クライアントを追加し、筆圧データをゲストに送信する。

**プロトコル**（最小限、バイナリ）:

| フィールド | 型 | バイト | 説明 |
|---|---|---|---|
| type | uint8 | 1 | 0=point, 1=proximity_enter, 2=proximity_leave |
| pressure | float32 LE | 4 | 0.0–1.0（UITouch.force / UITouch.maximumPossibleForce） |
| x | float32 LE | 4 | 正規化座標 0.0–1.0 |
| y | float32 LE | 4 | 正規化座標 0.0–1.0 |

合計 13 バイト/イベント。240Hz で 3.1KB/s。帯域の問題はない。

### 段階 2: ゲスト側の TCP 受信と注入

pencil-probe に `relay` サブコマンドを追加。

```
.build/debug/pencil-probe relay --port 9923
```

- `127.0.0.1:9923` でリッスン
- 接続を受けたらイベントを読み取り、TabletInjector で注入
- Phase 1 で実証した kCGEventTabletPointer + mouse+subtype の両方を post

### 段階 3: 結合テスト

1. ゲストで `pencil-probe relay` を起動
2. SSH ポートフォワード: ホスト → ゲスト 9923
3. ホスト側 Virtual Mac で Pencil タッチ → TCP 送信
4. クリスタで筆圧に応じた線の太さを確認

---

## ホスト側の改造方針

### 対象ファイル

`VirtualMac/vz/host/VirtualMacApp.m` の `VZInputView`

### 変更の範囲

1. `beginDeferredDirectTouches:` / `moveDeferredDirectTouches:` の
   `if (touch.type != UITouchTypeDirect) continue;` を変更し、
   `UITouchTypePencil`（= `UITouchTypeStylus`）も処理する

2. Pencil タッチの場合:
   - `touch.force / touch.maximumPossibleForce` で正規化した筆圧を取得
   - 座標と筆圧を TCP で送信
   - 既存の `sendPointer()` も呼ぶ（カーソル移動は維持）

3. TCP 接続の管理:
   - 接続先はコンパイル時定数またはユーザーデフォルトで指定
   - 接続が無い場合は筆圧データを捨てる（通常のマウス動作は維持）
   - 再接続は最小限（アプリ起動時 + 手動）

### PR の考慮事項

- 上流（nfzerox/VirtualMacOniPad）へ PR を出す前提
- 機能はオプショナルにする（TCP 未接続時は現在の動作と同一）
- コミット・PR は英語
- Pencil の「意図的な除外」が設計判断の可能性がある（P0001 再検証）。
  PR の説明でこの点に触れ、上流メンテナの意見を求める

---

## 想定される障害

| 障害 | 対処 |
|---|---|
| touch.force が常に 0 | iPad Pro M2 + Apple Pencil の組み合わせで force が取れるか確認。取れなければ Phase 2 断念 |
| UITouchTypePencil のイベントが来ない | Pencil がペアリングされているか確認。Virtual Mac のジェスチャ認識が Pencil を消費している可能性 |
| TCP 接続がブリッジで通らない | SSH ポートフォワードで迂回 |
| レイテンシが大きい | まず計測。TCP_NODELAY 設定。改善不十分なら Unix domain socket 経由（virtiofs 上）を検討 |
| sendPointer と筆圧注入のタイミングずれ | 座標は sendPointer に任せ、筆圧注入は座標を追従させる |

---

## ビルド環境

Xcode 26.3 が macbox に導入済み（P0007）。
`xcrun --sdk iphoneos clang` / `ibtool` が使える。
上流の `scripts/build-ipad-app.sh` でビルド可能。
