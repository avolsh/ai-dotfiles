#!/usr/bin/env bash
# framework/hooks/test-rerun-guard.sh
#
# PreToolUse guard (FR-7a, IMP-20260610-stabilize-profile-switching):
# denies re-running a build/test command when the worktree is unchanged
# since the last run in this session (boundaries.md § Never do #7 —
# "analyze the existing output first; flaky-test retries don't count").
#
# Contract (framework/hooks/README.md): JSON on stdin; exit 0 allow,
# exit 2 deny with reason on stderr. Fails open on malformed payload,
# non-git cwd, or non-test commands.
#
# Override: prefix the command with FORCE_TEST_RERUN=1 — visible in the
# transcript, so the retry is a deliberate, reviewable act.
set -euo pipefail

STATE_ROOT="${AI_HOOKS_STATE_DIR:-$HOME/.cache/ai-hooks}/test-rerun"

payload="$(cat || true)"
[ -n "$payload" ] || exit 0

read -r session cwd cmd_b64 < <(printf '%s' "$payload" | python3 -c '
import base64, json, sys
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
cmd = ti.get("command") or ""
print(d.get("session_id") or d.get("sessionId") or "nosession",
      d.get("cwd") or ".",
      base64.b64encode(cmd.encode()).decode() or "-")
') || exit 0
[ -n "${cmd_b64:-}" ] && [ "$cmd_b64" != "-" ] || exit 0
cmd="$(printf '%s' "$cmd_b64" | base64 -d 2>/dev/null || true)"
[ -n "$cmd" ] || exit 0

# Only guard recognizable build/test invocations.
printf '%s' "$cmd" | grep -q -E \
  '(^|[;&|[:space:]])(make[[:space:]]+(test|tests|check)|npm[[:space:]]+(test|run[[:space:]]+test)|pnpm[[:space:]]+test|yarn[[:space:]]+test|pytest|go[[:space:]]+test|cargo[[:space:]]+test|mvn[[:space:]]+(test|verify)|gradle(w)?[[:space:]]+(test|check))([[:space:]]|$)|\.test\.sh' \
  || exit 0

# Deliberate override re-arms the guard.
case "$cmd" in
  *FORCE_TEST_RERUN=1*) force=1 ;;
  *) force=0 ;;
esac

root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$root" ] || exit 0

tree_hash="$( (git -C "$root" rev-parse HEAD 2>/dev/null; git -C "$root" status --porcelain 2>/dev/null) | shasum -a 256 | cut -d' ' -f1)"
key="$(printf '%s|%s|%s' "$session" "$root" "$cmd" | shasum -a 256 | cut -d' ' -f1)"
state="$STATE_ROOT/$key"

if [ "$force" -eq 0 ] && [ -f "$state" ] && [ "$(cat "$state")" = "$tree_hash" ]; then
  echo "Blocked by test-rerun-guard: this command already ran with an identical worktree (no code changes since)." >&2
  echo "Analyze the previous output instead of re-running (boundaries § Never #7). Deliberate retry: prefix with FORCE_TEST_RERUN=1." >&2
  exit 2
fi

mkdir -p "$STATE_ROOT"
printf '%s' "$tree_hash" > "$state"
exit 0
