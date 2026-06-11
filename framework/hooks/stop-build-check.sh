#!/usr/bin/env bash
# framework/hooks/stop-build-check.sh
#
# Stop/agentStop advisory (FR-7b, IMP-20260610-stabilize-profile-switching):
# when the session edited code but no build/test command ran afterwards,
# print a reminder (boundaries.md § Always do #7 — run build and test
# before posting "The Bottom Line").
#
# ADVISORY ONLY: always exits 0, never blocks the stop. Reads the
# transcript when the payload provides transcript_path (Claude Code);
# fails open silently elsewhere.
set -euo pipefail

payload="$(cat || true)"
[ -n "$payload" ] || exit 0

AI_HOOK_PAYLOAD="$payload" python3 - <<'PY' >&2 || true
import json, os, re

try:
    d = json.loads(os.environ.get("AI_HOOK_PAYLOAD", ""))
except Exception:
    raise SystemExit
path = d.get("transcript_path") or d.get("transcriptPath")
if not path:
    raise SystemExit

TEST_RE = re.compile(
    r"(make\s+(test|tests|check|build)|npm\s+(test|run\s+(test|build))|pnpm\s+(test|build)"
    r"|yarn\s+(test|build)|pytest|go\s+(test|build)|cargo\s+(test|build)"
    r"|mvn\s+(test|verify|package)|gradlew?\s+(test|check|build)|\.test\.sh)")
CODE_EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

last_edit = last_check = -1
try:
    with open(path, encoding="utf-8") as fh:
        for i, line in enumerate(fh):
            try:
                entry = json.loads(line)
            except Exception:
                continue
            msg = entry.get("message") or {}
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                name = block.get("name", "")
                inp = block.get("input") or {}
                if name in CODE_EDIT_TOOLS:
                    fp = inp.get("file_path") or inp.get("path") or ""
                    if fp and not fp.endswith(".md"):
                        last_edit = i
                elif name == "Bash" and TEST_RE.search(inp.get("command", "")):
                    last_check = i
except OSError:
    raise SystemExit

if last_edit >= 0 and last_check < last_edit:
    print("stop-build-check (advisory): code was edited in this session but no "
          "build/test command ran afterwards — run the project's build/tests "
          "before posting The Bottom Line (boundaries § Always #7).")
PY
exit 0
