#!/usr/bin/env bash
# framework/hooks/stamp-refresh.sh
#
# PostToolUse helper (FR-1c, IMP-20260610-mechanize-framework-guardrails):
# refreshes the `*Last updated: YYYY-MM-DD*` stamp on an edited Markdown
# doc (boundaries.md § Always do #10), making the rule self-executing.
#
# Contract (see framework/hooks/README.md):
#   stdin  — JSON payload; edited file read like spec-status-guard.sh.
#   exit 0 — always (a PostToolUse helper must never block).
set -euo pipefail

payload="$(cat || true)"
[ -n "$payload" ] || exit 0

file="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
ti = d.get("tool_input") or d.get("toolInput") or {}
if not ti and isinstance(d.get("toolArgs"), str):
    # Copilot CLI: toolArgs is a JSON-encoded string
    try:
        ti = json.loads(d["toolArgs"]) or {}
    except Exception:
        ti = {}
print(ti.get("file_path") or ti.get("path") or ti.get("filePath")
      or d.get("file_path") or "")
')" || exit 0
[ -n "$file" ] || exit 0

case "$file" in
  *.md) ;;
  *) exit 0 ;;
esac
# History and vendored trees keep their original stamps.
case "$file" in
  *_legacy/*|*/upstream/*|*docs/specs/archived/*) exit 0 ;;
esac
[ -f "$file" ] || exit 0

python3 - "$file" <<'PY' || true
import re, sys, datetime
path = sys.argv[1]
today = datetime.date.today().isoformat()
with open(path, encoding="utf-8") as fh:
    text = fh.read()
new, n = re.subn(r"^\*Last updated: \d{4}-\d{2}-\d{2}\*$",
                 f"*Last updated: {today}*", text, count=1, flags=re.M)
if n and new != text:
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new)
PY
exit 0
