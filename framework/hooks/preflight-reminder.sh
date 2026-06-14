#!/usr/bin/env bash
# framework/hooks/preflight-reminder.sh
#
# PreToolUse advisory (FR-7c, IMP-20260610-stabilize-profile-switching):
# on the FIRST code edit of a session with no preflight proof posted in
# the transcript, print a reminder (boundaries.md § Always do #4 — post
# Task #, precedent files read, loaded skills before the first edit).
#
# ADVISORY ONLY: always exits 0, never blocks the edit. Fires at most
# once per session (state marker). Fails open without transcript_path.
set -euo pipefail

STATE_ROOT="${AI_HOOKS_STATE_DIR:-$HOME/.cache/ai-hooks}/preflight"

payload="$(cat || true)"
[ -n "$payload" ] || exit 0

read -r session file transcript < <(printf '%s' "$payload" | python3 -c '
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
print(d.get("session_id") or d.get("sessionId") or "nosession",
      ti.get("file_path") or ti.get("path") or ti.get("filePath") or "-",
      d.get("transcript_path") or d.get("transcriptPath") or "-")
') || exit 0

[ -n "${file:-}" ] && [ "$file" != "-" ] || exit 0
case "$file" in
  *.md) exit 0 ;;            # docs/specs are not code edits
esac
[ "$transcript" != "-" ] && [ -f "$transcript" ] || exit 0

marker="$STATE_ROOT/$session"
[ -f "$marker" ] && exit 0   # at most once per session
mkdir -p "$STATE_ROOT" && touch "$marker"

if ! grep -i -q "preflight" "$transcript" 2>/dev/null; then
  echo "preflight-reminder (advisory): first code edit of this session and no preflight proof found in the transcript — post Task #, precedent files read, and loaded skill paths before editing (boundaries § Always #4)." >&2
fi
exit 0
