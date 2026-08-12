---
id: H0008
title: "zellij 0.43.1 の操作方法とバグ回避"
created: 2026-08-12
verified: 2026-08-12
constraint:
relates: []
---

## 環境

macbox: zellij 0.43.1（ゲスト隔離 VM と同一バージョン）

## セッション外からの操作

`zellij action --session` は存在しない（0.43.1 で確認済み）。
対象セッションは環境変数で指定する。

ゲスト隔離 VM の `_zj_action` ラッパーを参考にした抽象化:

```bash
# _zj_run: ユーザー切り替えの抽象化層
# 単一ユーザーなら直接実行、アカウント分離時は sudo -i -u に差し替える
_zj_run() { "$@"; }

_zj_action() {
  local session="${1:?}"; shift
  _zj_run env "ZELLIJ_SESSION_NAME=${session}" zellij action "$@"
}
```

macbox でアカウント分離を導入する場合は `_zj_run` だけを差し替える:

```bash
_zj_run() { sudo -i -u "${TARGET_USER}" -- "$@"; }
```

### XDG_RUNTIME_DIR の扱い

Linux（ゲスト隔離 VM）では `sudo -i` で `XDG_RUNTIME_DIR` が消え、
zellij が `/tmp/zellij-<uid>/` の stale データを見にいく。
呼び出し時に注入して回避する:

```bash
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  env_prefix=(env "XDG_RUNTIME_DIR=/run/user/$(id -u)")
fi
```

macOS では `/run/user/` が存在しない。macOS での zellij の
セッションデータパスを確認してから調整すること（未確認）。

## 0.43.1 のバグ 2 つと回避

### (a) `new-pane --floating` の `--name` が無視される

```bash
zellij action new-pane --floating ...   # --name は効かない
zellij action rename-pane "NAME"        # 事後に付け直す
```

名前が `dump-layout` に出ないと、名前でペインを探す機構が壊れる。

### (b) floating の resize と dump-layout が不正確

既存ペインのリサイズが正確に効かない。
回避策: リサイズせず、正確な座標で新ペインを作り直して覆い隠す
（「自己置換」パターン）。

旧ペインが Exited で残っても新ペインが覆うので見た目に影響しないが、
旧ペインを生かしたまま放置すると z-order 問題が出る。
旧ペインは自分自身に HUP を送って落とす。

## floating ペインの配置

### 位置指定はパーセントを使う

zellij はパーセントをその時点の端末サイズから動的に解釈する。
固定値に依存せず端末リサイズに追従するため、
リサイズ監視は不要。

### レイアウト遷移パターン

2→3 枚: 左列を上下分割（新ペインは左下 x=0, y=50%）
3→4 枚: 田字型（新ペインは右下 x=50%, y=50%）

```bash
floating_count=$(_count_floating)
if (( floating_count >= 4 )); then
  echo "[ERROR] floating 4 ペイン以上は未対応"; exit 1
fi
if (( floating_count <= 2 )); then
  new_x="0";   new_y="50%"; new_h="50%"
else
  new_x="50%"; new_y="50%"; new_h="50%"
fi
_zj_action "${SESSION}" new-pane --floating \
  --x "${new_x}" --y "${new_y}" --width "50%" --height "${new_h}" \
  -- <コマンド>
_zj_action "${SESSION}" rename-pane "${ROLE}"
```

2→3 遷移時は旧ペイン（上半分を占有）を自己置換で縮小する。

### レイアウト KDL での注意

`y=0` にすると floating がタブバーを隠す。`y=1` にすること。

### floating ペインの枚数取得

`zj_list_panes` では tiled と floating を区別できないため、
`dump-layout` の KDL を波括弧の深さで解析する必要がある:

```bash
zellij action dump-layout | awk '
  !done && /floating_panes/ { fp=1; d=0 }
  fp {
    for(i=1;i<=length($0);i++){
      c=substr($0,i,1)
      if(c=="{")d++
      if(c=="}")d--
    }
    if(d<=0){ fp=0; done=1 }
  }
  fp && /^\s*pane / { n++ }
  END { print n+0 }
'
```

## floating ペインへのフォーカス

ID や名前で直接 focus できない。方向巡回で寄せる:

```bash
dirs=(right down left up)
for ((i=0; i<12; i++)); do
  # focused pane name を確認して目的のペインなら break
  zellij action move-focus "${dirs[$((i % 4))]}"
  sleep 0.1
done
```

## macbox での現状と将来

- 現在は単一ユーザー。`_zj_run` は直接実行で足りる
- アカウント分離を導入する場合は `_zj_run` のみ差し替え
- ペイン操作のキーバインド: `Ctrl-o n` で新ペイン
- XDG_RUNTIME_DIR の macOS 側パスは未確認（導入時に調査）

## 構造の概要（macbox に持ち込む場合の設計）

ゲスト隔離 VM の実装を参考にしたもの。ファイル名は
zellij の用語に合わせてリネームしている（元の `add_window.sh` は
zellij の pane を追加するスクリプトだが、zellij では window と
pane は別概念であり名称が不正確だった）。

| ファイル | 元の名称 | 役割 |
|---|---|---|
| レイアウト KDL | monitor_layout.kdl | 起動時の floating pane を静的に定義 |
| zellij-session.sh | zj_lib.sh | セッション操作・ユーザー切り替えの抽象化 |
| add-floating-pane.sh | add_window.sh | floating pane の追加と再配置 |

### zellij の用語

| zellij | tmux での対応 | 説明 |
|---|---|---|
| pane | pane | タブ内の分割領域 |
| tab | window | pane のグループ。タブバーに表示 |
| session | session | tab のグループ |

`window` は zellij の用語には無い。
tmux からの移行で混同しやすいので注意。

### 外部化すべき箇所

| 項目 | 現状 | 方針 |
|---|---|---|
| ユーザー切り替え | `_zj_run` で抽象化済み | 差し替えのみ |
| コマンドパス | 一部ハードコード | 引数またはファイルで外部化 |
| セッション名・ロール名 | 引数で受け取る設計 | そのまま |
