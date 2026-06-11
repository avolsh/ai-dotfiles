#!/usr/bin/env bash
# framework/hooks/adapters/copilot-pretooluse.sh
#
# Copilot CLI response adapter (T7 finding, FR-9 of
# IMP-20260610-stabilize-profile-switching). Canonical PreToolUse guards
# speak the exit-2 + stderr contract (Claude Code and Codex honor it);
# Copilot CLI 1.0.x ignores exit codes and expects
#   {"permissionDecision":"deny","permissionDecisionReason":"..."}
# as JSON on stdout. This wrapper runs each canonical guard given as an
# argument against the same payload and translates the first denial.
#
# Usage (in copilot-cli-policy.json):
#   "bash": ".../adapters/copilot-pretooluse.sh .../guard1.sh .../guard2.sh"
set -euo pipefail

payload="$(cat || true)"
[ -n "$payload" ] || exit 0

for guard in "$@"; do
  [ -x "$guard" ] || continue
  set +e
  reason="$(printf '%s' "$payload" | "$guard" 2>&1 >/dev/null)"
  rc=$?
  set -e
  if [ "$rc" -eq 2 ]; then
    REASON="$reason" python3 -c '
import json, os
print(json.dumps({
    "permissionDecision": "deny",
    "permissionDecisionReason": os.environ.get("REASON", "blocked by framework guard"),
}))'
    exit 0
  fi
done
exit 0
