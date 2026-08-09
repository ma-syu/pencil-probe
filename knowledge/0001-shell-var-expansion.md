---
id: 0001
title: シェル変数展開と全角文字の衝突
created: 2026-08-08
verified: 2026-08-08
constraint: constraints/check-var-expansion.sh
relates: []
---

## 事実

bash は変数名の終端を ASCII の英数字・アンダースコア以外で判定するが、
マルチバイト文字の先頭バイトを変数名の一部として拾ってしまう。

```bash
LABEL="Nix Store"
echo "ボリューム「$LABEL」は存在しません"
# → LABEL」 という変数名として解釈される
# → set -u 環境では: unbound variable
```

## 遭遇した経緯

2026-08-08、`uninstall-upstream-nix-macos.sh` の dry-run 実行中に発生。

```
./uninstall-upstream-nix-macos.sh: line 300: NIX_VOLUME_LABEL?: unbound variable
```

`cat -vet` でバイト列を確認したところ、`$NIX_VOLUME_LABEL` の直後が
全角の `」`（`M-^@M-^M`）であることが判明した。

## 対処

文字列内の変数展開は常に `${VAR}` の形で囲む。

```bash
echo "ボリューム「${LABEL}」は存在しません"   # 正
```

## 派生的な教訓

`set -u` が無ければ、このエラーは発生せず空文字列として静かに通過していた。
その場合 `diskutil info -plist ""` のような不正な呼び出しが行われ、
発見はさらに遅れていた。**「静かに間違う」より「大声で止まる」方が安全。**

`constraints/check-shell-hygiene.sh` が `set -u` の有無を検査するのは
この理由による。
