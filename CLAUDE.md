# CLAUDE.md（pencil-probe 固有）

全プロジェクト共通の規約は `~/.claude/CLAUDE.md` にあり、自動で読まれる。
ここには**この環境・この作業に固有**のことだけを書く。

> **共通側との分割は仮説である。**
> 2 つ目のプロジェクトを始めた時点で見直すこと。
> 判断材料は `./scripts/rule-audit.sh` の実測。

## 参照先

- `docs/phase0-spec.md` — **今の作業内容と成功条件**
- `docs/constraints.md` — 検査の一覧（ハーネス由来。編集しない）
- `docs/rationale.md` — この環境固有の規約の理由、検査一覧
- `MEMORY.md` — 過去に観測した事実の索引

汎用的な規約とその理由は `~/.claude/CLAUDE.md` と `~/.claude/docs/` にある。

---

## 上流リポジトリ

`~/projects/VirtualMacOniPad/` にフォークをクローン済み（MIT License）。
入力処理は `VirtualMac/vz/host/VirtualMacApp.m` の `VZInputView`。

**読むだけにすること。このディレクトリのファイルを変更しない。**
上流への PR は手順が別にあり、勝手に編集すると PR に不要な差分が混入する。
Phase 0/1 は Virtual Mac を触らずに完結する設計になっている。

## 実行環境

macOS 15 / aarch64-darwin。実体は **iPad Pro M2 上の Virtual Mac**
（Virtualization.framework の非公式移植）。メモリ 8GB 程度。
ネットワークは**ブリッジで LAN 直結**（後述のセキュリティ制約に直結）。

## この環境でできないこと

推測で試行すると時間を浪費するので、先に列挙する。

| 不可 | 理由 |
|---|---|
| Mac App Store / 実機署名 / TestFlight | Apple Account にサインインできない |
| Docker / Podman / Android Emulator | ネスト仮想化なし（M3 以降のみ） |
| Xcode GUI | 未導入。`swiftc` `swift` `xcrun` `clang` は可 |
| `brew` / `npm -g` / `pip install` | パッケージは Nix で管理 |

パッケージ追加は `~/nixos-config/hosts/macbox/default.nix` に追記して
`sudo darwin-rebuild switch --flake ~/nixos-config#macbox`。
一時利用は `nix run nixpkgs#<名前>`（何も残らないので自由に使ってよい）。

## セキュリティ制約

ブリッジ接続のため、以下は**実際に到達可能な攻撃経路**になる。
入力注入（マウス・キーボードイベント生成）を扱うプログラムを書くため、
`0.0.0.0` でリッスンすると LAN 上の任意の機器からゲストを操作できる。

禁止: `0.0.0.0` / `INADDR_ANY` でのリッスン、`system()` `popen()`、
`strcpy` `sprintf` `gets`、受信データの長さ未検証、認証情報のハードコード。

ソケットは `127.0.0.1` か、明示的に許可した単一 IP のみにバインドする。

## コードの配置

```
Sources/Core/   純粋。入出力・時刻・乱数・可変状態なし。テスト必須
Sources/IO/     副作用はここだけ
```

閾値と原則は `~/.claude/CLAUDE.md` を参照。
`constraints/check-purity-boundary.sh` と
`constraints/check-dependency-graph.sh` が機械的に検査する。

## 言語の使い分け

上流（`github.com/nfzerox/VirtualMacOniPad`）へ PR を出す前提のため、
**PR に含めるコード・コミット・issue は英語**。
自分用のスクリプト・`knowledge/`・作業メモは日本語。訳文を二重に持たない。

## 既知の落とし穴（実測で遭遇したもの）

- **シェル変数展開**: 日本語文字列内で `"$VAR」"` と書くと、bash が全角文字を
  変数名の一部と解釈し `unbound variable` になる。必ず `${VAR}` で囲む。
  → `constraints/check-var-expansion.sh` が検出（`knowledge/H0001`）

- **正規表現を含むルールの区切り**: `パターン|理由` 形式を `${rule%%|*}` で
  分解すると、パターン内の `|` で切れる。区切りには `@@` を使う
  （`knowledge/H0002`）

- **`plutil -extract` の失敗**: 失敗時にエラー文を**標準出力**へ吐く。
  戻り値を空判定すると、エラー文が値として通過する。
  元コマンドの終了コードで先に判定し、値の形式も正規表現で検証すること。

- **`/tmp` は消える**: macOS は定期的に掃除する。作業ファイルはホーム配下に置く。
