---
id: P0013
title: "SSH 経由の CGEventPost は sshd-keygen-wrapper に Accessibility 権限が必要"
created: 2026-08-13
verified: 2026-08-13
constraint:
relates: [P0008, P0010]
validity: current
source_class: observation
verified_at: 2026-08-13T22:35+09:00
verified_against: "SSH 経由・ローカル Terminal 経由の両方で責任プロセスの切り替えを実機確認"
---

## 観測

pencil-probe を SSH 経由で実行した場合、pencil-probe 自体に
Accessibility 権限を付与しても CGEventPost は無視される。

macOS の TCC (Transparency, Consent, and Control) は、SSH 経由の
プロセスの「責任プロセス (responsible process)」を
`/usr/libexec/sshd-keygen-wrapper` と判定する。
これは launchd が sshd を起動する際のラッパーバイナリ。

## 正しい設定

System Settings > Privacy & Security > Accessibility で
**sshd-keygen-wrapper** を ON にする。
pencil-probe のエントリではなく、こちらが実際の権限を制御する。

## 再現手順

1. sshd-keygen-wrapper を OFF にする
2. pencil-probe を SSH 経由で起動 → `AXIsProcessTrusted()` が false
3. sshd-keygen-wrapper を ON にする
4. pencil-probe を再起動 → `AXIsProcessTrusted()` が true

## プロセスツリー

```
launchd → sshd-keygen-wrapper → sshd-session → zsh → pencil-probe
```

TCC はこの木の根に近い sshd-keygen-wrapper を責任プロセスとして
権限チェックに使う。

## ローカル Terminal からの起動（実機検証済み）

iPad GUI → macbox Terminal.app → pencil-probe の経路では、
sshd-keygen-wrapper は不要。代わりに Terminal.app（自動でエントリに
追加される）に Accessibility 権限を付与すれば筆圧が正常に動作する。

```
SSH経由:    launchd → sshd-keygen-wrapper → sshd → zsh → pencil-probe
ローカル:   launchd → Terminal.app → zsh → pencil-probe
```

## リリース時の注意

README やヘルプ出力に以下を記載すること：
- Accessibility 権限はこのバイナリ自体ではなく「責任プロセス」に付与する
- Terminal.app から起動 → Terminal.app を ON にする（通常の利用経路）
- SSH 経由で起動 → sshd-keygen-wrapper を ON にする（開発・リモート管理）
