#!/usr/bin/env bash
# =============================================================================
# scripts/extract-reads.sh
#
#   Claude Code の JSONL セッションログから knowledge/ への Read ツール呼び出しを
#   抽出し、memory/events.tsv に追記する。
#
#   冪等: (timestamp, id) の組で重複排除する。何度実行しても結果は同じ。
#
#   壊れ方の設計:
#     - JSONL の形式が解釈不能なら落ちる（空を返して続行しない）
#     - 新規イベントが 0 件の場合は件数 0 を出力する（silent zero 禁止）
#     - 抽出できた件数を毎回出力する
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

readonly -a REQUIRED_COMMANDS=(python3)
if [[ -f "${PROJECT_ROOT}/scripts/lib/require.sh" ]]; then
    source "${PROJECT_ROOT}/scripts/lib/require.sh"
    require_commands "${REQUIRED_COMMANDS[@]}" || exit 1
fi

readonly EVENTS_FILE="${PROJECT_ROOT}/memory/events.tsv"
readonly JSONL_DIR="${HOME}/.claude/projects/-Users-wahoo-projects-pencil-probe"
readonly KNOWLEDGE_DIR="${PROJECT_ROOT}/knowledge"

if [[ ! -d "${JSONL_DIR}" ]]; then
    printf 'WARNING: JSONL directory not found: %s\n' "${JSONL_DIR}" >&2
    printf 'read extraction: 0 new events (JSONL dir missing)\n'
    exit 0
fi

# JSONL が 1 つもなければ警告
jsonl_count=$(find "${JSONL_DIR}" -maxdepth 1 -name '*.jsonl' 2>/dev/null | wc -l)
if (( jsonl_count == 0 )); then
    printf 'WARNING: no JSONL files found in %s\n' "${JSONL_DIR}" >&2
    printf 'read extraction: 0 new events (no JSONL files)\n'
    exit 0
fi

python3 << 'PYEOF'
import json, os, sys, glob

jsonl_dir = os.environ.get("JSONL_DIR", "")
events_file = os.environ.get("EVENTS_FILE", "")
knowledge_dir = os.environ.get("KNOWLEDGE_DIR", "")

# 既存イベントを読み込み、重複排除用のセットを作る
existing = set()
if os.path.exists(events_file):
    with open(events_file) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) >= 3:
                existing.add((parts[0], parts[2]))  # (timestamp, id)

# knowledge/ のファイル名から ID を抽出するマッピング
knowledge_files = {}
if os.path.isdir(knowledge_dir):
    for name in os.listdir(knowledge_dir):
        if name.endswith(".md"):
            # H0006-harness-distribution-contamination.md → knowledge/H0006-...
            knowledge_files[os.path.join(knowledge_dir, name)] = name

# JSONL からRead ツール呼び出しを抽出
new_events = []
parse_errors = 0

for jsonl_path in sorted(glob.glob(os.path.join(jsonl_dir, "*.jsonl"))):
    try:
        with open(jsonl_path) as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    parse_errors += 1
                    continue

                msg = obj.get("message", {})
                if not isinstance(msg, dict):
                    continue
                for content in msg.get("content", []):
                    if not isinstance(content, dict):
                        continue
                    if content.get("type") != "tool_use":
                        continue
                    if content.get("name") != "Read":
                        continue
                    file_path = content.get("input", {}).get("file_path", "")
                    ts = obj.get("timestamp", "")
                    if not ts or not file_path:
                        continue
                    # knowledge/ ファイルへの Read のみ対象
                    basename = os.path.basename(file_path)
                    if not basename.endswith(".md"):
                        continue
                    full = os.path.join(knowledge_dir, basename)
                    if full not in knowledge_files:
                        continue
                    event_id = basename.replace(".md", "")
                    if (ts, event_id) not in existing:
                        new_events.append((ts, "ai", event_id, "read", ""))
                        existing.add((ts, event_id))
    except Exception as e:
        print(f"ERROR: failed to parse {jsonl_path}: {e}", file=sys.stderr)
        sys.exit(1)

if parse_errors > 10:
    print(f"WARNING: {parse_errors} JSON parse errors in JSONL files", file=sys.stderr)

# 追記
if new_events:
    with open(events_file, "a") as f:
        for ts, actor, eid, kind, note in sorted(new_events):
            f.write(f"{ts}\t{actor}\t{eid}\t{kind}\t{note}\n")

print(f"read extraction: {len(new_events)} new events")
PYEOF
