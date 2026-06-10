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
#   exit 0 — allow (no governing spec, spec in-progress, or non-code path)
#   exit 2 — deny; reason on stderr names the spec and required status.
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

# Walk up from the edited file to find the project root (dir owning docs/specs/active).
dir="$(dirname "$abs")"
root=""
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
  if [ -d "$dir/docs/specs/active" ]; then root="$dir"; break; fi
  dir="$(dirname "$dir")"
done
[ -n "$root" ] || exit 0

rel="${abs#"$root"/}"

# Docs, specs, and Markdown are never blocked — only code paths are governed.
case "$rel" in
  docs/*|*.md) exit 0 ;;
esac

for spec in "$root"/docs/specs/active/*.md; do
  [ -e "$spec" ] || continue
  status="$(awk 'f==2{exit} /^---$/{f++;next} f==1 && $1=="status:"{print $2; exit}' "$spec")"
  case "$status" in
    specify|plan) ;;
    *) continue ;;
  esac
  while IFS= read -r p; do
    p="${p%% (*}"          # strip annotations: "src/foo (new)"
    p="${p%/...}"          # strip ellipsis: "src/..."
    p="${p%/}"             # strip trailing slash
    [ -n "$p" ] || continue
    case "$rel" in
      "$p"|"$p"/*)
        echo "Blocked by spec-status-guard: '$rel' is governed by $(basename "$spec") at status '$status'." >&2
        echo "Code edits require status 'in-progress' (flip only after the plan gate — spec-lifecycle.md § Status transitions)." >&2
        exit 2
        ;;
    esac
  done < <(awk 'f==2{exit} /^---$/{f++;next}
                f==1 && /^affected-code:/{flag=1; next}
                f==1 && flag && /^[[:space:]]+- /{sub(/^[[:space:]]+- /,""); print; next}
                f==1 && flag && !/^[[:space:]]/{flag=0}' "$spec")
done
exit 0
