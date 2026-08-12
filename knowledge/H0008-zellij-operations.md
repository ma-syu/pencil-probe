---
id: H0008
title: "zellij 0.43.1 の操作方法とバグ回避"
created: 2026-08-12
verified: 2026-08-12
constraint:
relates: []
---

## 実装の所在

スクリプトは `nixos-config` の Nix パッケージとして管理:
- `~/nixos-config/packages/zellij-tools/` — パッケージ本体
- `zj-add-floating-pane` コマンドとして PATH に入る
- `writeShellApplication` で shellcheck 自動適用

アカウント分離は `ZJ_RUN_PREFIX` 環境変数で制御:
```bash
export ZJ_RUN_PREFIX="sudo -i -u ai --"
```

## 0.43.1 のバグ（スクリプト内で回避済み）

| バグ | 回避策 |
|---|---|
| `new-pane --floating` の `--name` が無視される | `rename-pane` で事後付与 |
| floating の resize / dump-layout が不正確 | リサイズせず作り直して覆い隠す |

## 知っておくべきこと

- **セッション外操作**: `ZELLIJ_SESSION_NAME` 環境変数で指定（`--session` フラグは存在しない）
- **位置指定はパーセント**: 端末リサイズに自動追従
- **KDL レイアウト**: `y=0` にすると floating がタブバーを隠す。`y=1` にする
- **floating pane の枚数**: `dump-layout` の KDL を波括弧深さで解析（list-panes では区別不可）
- **floating pane へのフォーカス**: ID/名前で直接指定不可。方向巡回で寄せる
- **XDG_RUNTIME_DIR**: macOS では `/run/user/` が無い。macOS 側パスは未確認

### zellij の用語（tmux との対応）

| zellij | tmux | 説明 |
|---|---|---|
| pane | pane | タブ内の分割領域 |
| tab | window | pane のグループ |
| session | session | tab のグループ |

`window` は zellij の用語には無い（tmux からの移行で混同しやすい）。
