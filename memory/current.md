# 現在の状態

updated: 2026-08-13T16:25+09:00

## フェーズ

Phase 2 段階 3（結合テスト）。段階 0-2 は完了。

## 次の一手

1. iPad に新ビルドをデプロイ（VirtualMac.app は macbox でビルド済み）
2. ゲストで `pencil-probe relay --listen 192.168.1.2 --port 9923 --allow 192.168.1.15`
3. クリスタで Pencil 描画 → 筆圧で線の太さが変わること + Pencil を離したとき余計な線が引かれないこと

## デプロイ状態

| 場所 | バージョン | 状態 |
|---|---|---|
| macbox VirtualMac.app | パッチ v2（early return） | ビルド済み。未デプロイ |
| iPad VirtualMac | パッチ v1（sendPointer 削除のみ） | 動作中。筆圧は通るが Pencil リフト時に余計な線 |
| macbox pencil-probe relay | 最新 | ビルド済み |

## 未解決

- Pencil リフト時の余計な線 → パッチ v2 で修正済み（テスト待ち）

## 意図ログ

- 2026-08-13T15:40 記憶システムの constraint + knowledge/ フィールド追加（完了）
- 2026-08-13T15:40 CLAUDE.md にブートストラップ記述追加（完了）
- 2026-08-13T15:40 memory/current.md 作成（完了）
- 2026-08-13T16:25 session-start hook に記憶システム統合（完了）
- 2026-08-13T16:25 iPad に VirtualMac.app v2 デプロイ → 結合テスト（次の一手）
