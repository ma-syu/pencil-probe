---
id: H0007
title: "SSH 経由で GUI 認証が必要になった場合の対処"
created: 2026-08-10
verified: 2026-08-10
constraint:
relates: []
---

## 状況

subbox から macbox に SSH 接続し、zellij 内で Claude Code を起動すると
`/login` を促される場合がある。認証 URL は macbox のブラウザで開く必要があるが、
SSH 端末に表示された URL を macbox の GUI へ渡す手段が自明でない。

## 原因

SSH 経由ではクリップボードがサーバ側（macbox）とクライアント側（subbox）で分離する。
zellij の Ctrl-o s → Ctrl-c でコピーしても、操作した側のクリップボードにしか入らない。

## 有効な手段（簡単な順）

### 1. macbox 側でブラウザを直接開く

```sh
ssh wahoo@<host> 'open "<URL>"'
```

コピペ不要。`open` は macOS の既定ブラウザで URL を開く。

### 2. macbox のクリップボードへ直接入れる

```sh
echo "<URL>" | ssh wahoo@<host> pbcopy
```

その後 macbox の GUI で Cmd+V。
`pbcopy` を SSH 越しに実行することで、クリップボードの非対称性を回避できる。

### 3. LocalSend 等のファイル転送

追加のアプリが必要で、手数が多い。最終手段。
