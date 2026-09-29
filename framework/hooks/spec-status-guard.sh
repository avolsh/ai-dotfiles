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

# Walk up from the edited file collecting every root (dir owning docs/specs/active), nearest first
# (IMP-20260929 FR-1): the project root, and any workspace root enclosing it whose spec tree governs
# cross-repo work. A single-project repository collects exactly one, as before (FR-5).
dir="$(dirname "$abs")"
roots=""
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
  [ -d "$dir/docs/specs/active" ] && roots="${roots}${dir}"$'\n'
  dir="$(dirname "$dir")"
done
[ -n "$roots" ] || exit 0

nearest="$(printf '%s' "$roots" | head -1)"
rel="${abs#"$nearest"/}"

# Docs, specs, and Markdown are never blocked — only code paths are governed. Decided against the
# nearest root, as before; a path outside it is still Markdown-exempt by its own suffix.
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

# Does this spec lease the edited path through its affected-code inventory? The path is spelled
# relative to the spec's own root (FR-2), so a workspace spec leasing `src/<host>/<org>/<repo>/_cms`
# and a project spec leasing `_cms` both match the same edit.
leases_path() { # $1 spec, $2 path relative to that spec's root
  local p
  while IFS= read -r p; do
    p="${p%% (*}"          # strip annotations: "src/foo (new)"
    p="${p%/...}"          # strip ellipsis: "src/..."
    p="${p%/}"             # strip trailing slash
    [ -n "$p" ] || continue
    case "$2" in
      "$p"|"$p"/*) return 0 ;;
    esac
  done < <(fm_list "$1" affected-code)
  return 1
}

# Pass 1 — collect every blocker instead of exiting on the first match (IMP-20260826 FR-1), across
# every root (IMP-20260929 FR-3). An active spec at `in-progress` leasing the path allows outright,
# whichever root holds it (IMP-20260826 FR-2).
blockers=""
in_progress=""
while IFS= read -r root; do
  [ -n "$root" ] || continue
  root_rel="${abs#"$root"/}"
  for spec in "$root"/docs/specs/active/*.md; do
    [ -e "$spec" ] || continue
    status="$(fm_scalar "$spec" status)"
    case "$status" in
      specify|plan|in-progress) ;;
      *) continue ;;
    esac
    if [ "$status" = "in-progress" ]; then
      in_progress="${in_progress}$(spec_id "$spec")"$'\n'
      leases_path "$spec" "$root_rel" && exit 0
      continue
    fi
    leases_path "$spec" "$root_rel" || continue
    blockers="${blockers}$(fm_scalar "$spec" date)	${spec}	${root}"$'\n'
  done
done < <(printf '%s' "$roots")

[ -n "$blockers" ] || exit 0

# Pass 2 — a blocker whose `depends-on:` names an active `in-progress` spec is
# waiting on that work, and Rule #10 keeps it at `specify` until the dependency
# is done, so it cannot hold a lease against it (FR-3).
remaining=""
# Fields are cut with parameter expansion, never `read -r` under `IFS=$'\t'`: a tab is IFS whitespace,
# so `read` would collapse the empty `date:` of a spec that has none and shift every field left.
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  rest="${entry#*	}"                 # drop the date
  entry_spec="${rest%%	*}"
  waiting=0
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    if printf '%s' "$in_progress" | grep -qxF -- "$dep"; then waiting=1; break; fi
  done < <(fm_list "$entry_spec" depends-on)
  [ "$waiting" -eq 0 ] && remaining="${remaining}${entry}"$'\n'
done <<< "$blockers"

[ -n "$remaining" ] || exit 0

earliest="$(printf '%s' "$remaining" | sort | head -1)"
earliest_spec="$(printf '%s' "$earliest" | cut -f2)"
earliest_root="$(printf '%s' "$earliest" | cut -f3)"
# The tree is named because blockers can now come from more than one of them (FR-4).
echo "Blocked by spec-status-guard: '$rel' is governed by $(basename "$earliest_spec") at status '$(fm_scalar "$earliest_spec" status)' (spec tree: $earliest_root/docs/specs/active)." >&2
echo "Allowed when either: an active spec at 'in-progress' lists this path in affected-code; or that blocker's 'depends-on:' names an active spec at 'in-progress' (spec-lifecycle.md § Status transitions)." >&2
exit 2
