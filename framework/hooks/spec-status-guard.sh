#!/usr/bin/env bash
# framework/hooks/spec-status-guard.sh
#
# PreToolUse guard (FR-1a, IMP-20260610-mechanize-framework-guardrails):
# denies a code edit while the governing spec is still at status
# `specify` or `plan` (boundaries.md § Always do #3).
#
# Contract (see framework/hooks/README.md):
#   stdin  — JSON payload; the edited file is read from
#            .tool_input.file_path | .tool_input.path | .file_path,
#            the working directory from .cwd (optional).
#   exit 0 — allow: non-code path, no governing spec, an active spec at
#            `in-progress` lists the path, or every blocker's `depends-on:`
#            names an active `in-progress` spec (IMP-20260826 FR-1…FR-4).
#   exit 2 — deny; reason on stderr names the earliest blocker by `date:`
#            and states both allow conditions.
set -euo pipefail

payload="$(cat || true)"
[ -n "$payload" ] || exit 0

read -r file cwd < <(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(" ", " "); raise SystemExit
ti = d.get("tool_input") or d.get("toolInput") or {}
if not ti and isinstance(d.get("toolArgs"), str):
    # Copilot CLI: toolArgs is a JSON-encoded string
    try:
        ti = json.loads(d["toolArgs"]) or {}
    except Exception:
        ti = {}
f = (ti.get("file_path") or ti.get("path") or ti.get("filePath")
     or d.get("file_path") or "")
print(f or " ", d.get("cwd") or " ")
')
[ "$file" != " " ] && [ -n "$file" ] || exit 0
[ "$cwd" = " " ] && cwd="$PWD"

# Absolutize against the payload cwd.
case "$file" in
  /*) abs="$file" ;;
  *)  abs="$cwd/$file" ;;
esac

# The lease decision itself lives in the shared library, so this door and the Bash door cannot drift
# (IMP-20260929-guarded-writes-through-bash D3).
. "$(dirname "$0")/lib/spec-lease.sh"

if spec_lease_decide "$abs"; then
  exit 0
fi

echo "Blocked by spec-status-guard: '$SPEC_LEASE_REL' is governed by $(basename "$SPEC_LEASE_SPEC") at status '$SPEC_LEASE_STATUS' (spec tree: $SPEC_LEASE_ROOT/docs/specs/active)." >&2
spec_lease_allow_conditions >&2
exit 2
