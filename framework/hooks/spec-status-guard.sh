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

# Front-matter readers (first `---` block only).
fm_scalar() { # $1 spec, $2 key
  awk -v k="$2:" 'f==2{exit} /^---$/{f++;next} f==1 && $1==k{print $2; exit}' "$1"
}
fm_list() { # $1 spec, $2 key — emits one normalized entry per line
  awk -v k="$2:" 'f==2{exit} /^---$/{f++;next}
                  f==1 && $1==k && NF==1 {flag=1; next}
                  f==1 && flag && /^[[:space:]]+- /{sub(/^[[:space:]]+- /,""); print; next}
                  f==1 && flag && !/^[[:space:]]/{flag=0}' "$1"
}

spec_id() { # $1 spec — front-matter `id:`, else the filename stem
  local i; i="$(fm_scalar "$1" id)"; [ -n "$i" ] || i="$(basename "$1" .md)"
  printf '%s' "$i"
}

# Does this spec lease `rel` through its affected-code inventory?
leases_path() { # $1 spec
  local p
  while IFS= read -r p; do
    p="${p%% (*}"          # strip annotations: "src/foo (new)"
    p="${p%/...}"          # strip ellipsis: "src/..."
    p="${p%/}"             # strip trailing slash
    [ -n "$p" ] || continue
    case "$rel" in
      "$p"|"$p"/*) return 0 ;;
    esac
  done < <(fm_list "$1" affected-code)
  return 1
}

# Pass 1 — collect every blocker instead of exiting on the first match (FR-1).
# An active spec at `in-progress` leasing the path allows outright (FR-2).
blockers=""
in_progress=""
for spec in "$root"/docs/specs/active/*.md; do
  [ -e "$spec" ] || continue
  status="$(fm_scalar "$spec" status)"
  case "$status" in
    specify|plan|in-progress) ;;
    *) continue ;;
  esac
  if [ "$status" = "in-progress" ]; then
    in_progress="${in_progress}$(spec_id "$spec")"$'\n'
    leases_path "$spec" && exit 0
    continue
  fi
  leases_path "$spec" || continue
  blockers="${blockers}$(fm_scalar "$spec" date)	${spec}"$'\n'
done

[ -n "$blockers" ] || exit 0

# Pass 2 — a blocker whose `depends-on:` names an active `in-progress` spec is
# waiting on that work, and Rule #10 keeps it at `specify` until the dependency
# is done, so it cannot hold a lease against it (FR-3).
remaining=""
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  waiting=0
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    if printf '%s' "$in_progress" | grep -qxF -- "$dep"; then waiting=1; break; fi
  done < <(fm_list "${entry#*	}" depends-on)
  [ "$waiting" -eq 0 ] && remaining="${remaining}${entry}"$'\n'
done <<< "$blockers"

[ -n "$remaining" ] || exit 0

earliest="$(printf '%s' "$remaining" | sort | head -1 | cut -f2-)"
echo "Blocked by spec-status-guard: '$rel' is governed by $(basename "$earliest") at status '$(fm_scalar "$earliest" status)'." >&2
echo "Allowed when either: an active spec at 'in-progress' lists this path in affected-code; or that blocker's 'depends-on:' names an active spec at 'in-progress' (spec-lifecycle.md § Status transitions)." >&2
exit 2
