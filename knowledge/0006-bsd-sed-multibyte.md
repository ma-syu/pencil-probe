---
id: 0006
title: macOS の BSD sed はマルチバイト文字で illegal byte sequence を起こす
created: 2026-08-10
verified: 2026-08-10
constraint:
relates: [0001]
---

## 事実

macOS の BSD sed は、ロケールが `C` や未設定のとき、
マルチバイト文字を含む行を処理すると失敗する。

```
sed: RE error: illegal byte sequence
```

GNU sed（Linux）では起きないため、Linux で書いたスクリプトが
macOS で静かに壊れる。

## 遭遇した経緯

2026-08-10、フックの動作確認中。
`post-edit-check.sh` が `check-all.sh` の出力から `[FAIL]` 行を
`sed -n 's/^\[FAIL\]...//p'` で抜き出していた。

検査の出力には日本語のエラーメッセージが含まれるため、
そこで sed が停止。**2 件 FAIL したのに 1 件しか記録されなかった。**

```
FAIL したもの: check-shell-hygiene, check-var-expansion
記録されたもの: check-shell-hygiene のみ
```

`check-all.sh` の出力インデント（`sed 's/^/       /'`）と
`check-shell-hygiene.sh` の構文エラー表示にも同じ問題があった。

## 対処

**sed を使わず bash の文字列操作に置き換えた。**
bash はバイト列として扱うため、この問題が起きない。

```bash
# 悪い
printf '%s\n' "${output}" | sed -n 's/^\[FAIL\][[:space:]]*//p'

# 良い
while IFS= read -r line; do
    [[ "${line}" == '[FAIL]'* ]] || continue
    name="${line#'[FAIL]'}"
    name="${name#"${name%%[![:space:]]*}"}"   # 先頭の空白を落とす
done <<< "${output}"
```

`export LC_ALL=en_US.UTF-8` でも回避できるが、
そのロケールが存在する保証がない環境（最小構成のコンテナ等）では
別の問題を生むため、bash で完結させる方を選んだ。

## 派生的な教訓

**この不具合は「静かに一部だけ失敗する」形で現れた。**
エラーは出ていたが、記録は 1 件だけ残っており、
ログを見ただけでは「そもそも 1 件しか FAIL しなかった」のか
「記録漏れ」なのかが区別できなかった。

実際に 2 件 FAIL する状況を意図的に作って初めて判明した。
**観測系そのものを検証しないと、観測結果を信用できない。**

なお、この不具合は皮肉な構造を持っていた。
全角文字と変数展開の問題（knowledge/0001）を検出する仕組みが、
全角文字を含む出力を処理できずに壊れていた。
