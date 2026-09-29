# framework/hooks/lib/spec-lease.sh
#
# The lease decision, shared by every guard that has to answer "may this path be written now?"
# (IMP-20260929-guarded-writes-through-bash D3). Sourced, never executed: a path must not be governed at one
# door and free at another, which is what a second implementation would eventually produce.
#
# Usage:
#   . "$(dirname "$0")/lib/spec-lease.sh"
#   spec_lease_decide "/abs/path/to/file"
#     exit status 0 — allowed; nothing is set
#     exit status 1 — blocked; SPEC_LEASE_SPEC, SPEC_LEASE_ROOT, SPEC_LEASE_STATUS and SPEC_LEASE_REL hold
#                     the earliest blocker by `date:`, its spec tree, its status and the path as the
#                     nearest root spells it
#
# The rules it implements are documented in framework/hooks/README.md:
#   - every ancestor owning docs/specs/active is a spec tree, nearest first (IMP-20260929 FR-1)
#   - each spec matches the path as its own tree spells it (FR-2)
#   - an `in-progress` spec leasing the path in any tree allows outright (IMP-20260826 FR-2)
#   - a blocker whose `depends-on:` names such a spec cannot hold a lease against it (FR-3)
#   - `docs/` and Markdown are never governed

# Front-matter readers (first `---` block only).
spec_lease_fm_scalar() { # $1 spec, $2 key
  awk -v k="$2:" 'f==2{exit} /^---$/{f++;next} f==1 && $1==k{print $2; exit}' "$1"
}

spec_lease_fm_list() { # $1 spec, $2 key — emits one normalized entry per line
  awk -v k="$2:" 'f==2{exit} /^---$/{f++;next}
                  f==1 && $1==k && NF==1 {flag=1; next}
                  f==1 && flag && /^[[:space:]]+- /{sub(/^[[:space:]]+- /,""); print; next}
                  f==1 && flag && !/^[[:space:]]/{flag=0}' "$1"
}

spec_lease_id() { # $1 spec — front-matter `id:`, else the filename stem
  local i; i="$(spec_lease_fm_scalar "$1" id)"; [ -n "$i" ] || i="$(basename "$1" .md)"
  printf '%s' "$i"
}

# Does this spec lease the edited path through its affected-code inventory? The path is spelled relative to
# the spec's own root, so a workspace spec leasing `src/<host>/<org>/<repo>/_cms` and a project spec leasing
# `_cms` both match the same edit.
spec_lease_leases_path() { # $1 spec, $2 path relative to that spec's root
  local p
  while IFS= read -r p; do
    p="${p%% (*}"          # strip annotations: "src/foo (new)"
    p="${p%/...}"          # strip ellipsis: "src/..."
    p="${p%/}"             # strip trailing slash
    [ -n "$p" ] || continue
    case "$2" in
      "$p"|"$p"/*) return 0 ;;
    esac
  done < <(spec_lease_fm_list "$1" affected-code)
  return 1
}

# Every ancestor owning docs/specs/active, nearest first. Empty when the path is in no spec tree.
spec_lease_roots() { # $1 absolute path
  local dir; dir="$(dirname "$1")"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    [ -d "$dir/docs/specs/active" ] && printf '%s\n' "$dir"
    dir="$(dirname "$dir")"
  done
}

spec_lease_decide() { # $1 absolute path
  SPEC_LEASE_SPEC=""; SPEC_LEASE_ROOT=""; SPEC_LEASE_STATUS=""; SPEC_LEASE_REL=""
  local abs="$1" roots nearest rel root root_rel spec status blockers in_progress
  roots="$(spec_lease_roots "$abs")"
  [ -n "$roots" ] || return 0

  nearest="$(printf '%s' "$roots" | head -1)"
  rel="${abs#"$nearest"/}"
  # Docs, specs and Markdown are never governed — they must stay editable during Specify and Plan.
  case "$rel" in
    docs/*|*.md) return 0 ;;
  esac

  blockers=""
  in_progress=""
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    root_rel="${abs#"$root"/}"
    for spec in "$root"/docs/specs/active/*.md; do
      [ -e "$spec" ] || continue
      status="$(spec_lease_fm_scalar "$spec" status)"
      case "$status" in
        specify|plan|in-progress) ;;
        *) continue ;;
      esac
      if [ "$status" = "in-progress" ]; then
        in_progress="${in_progress}$(spec_lease_id "$spec")"$'\n'
        spec_lease_leases_path "$spec" "$root_rel" && return 0
        continue
      fi
      spec_lease_leases_path "$spec" "$root_rel" || continue
      blockers="${blockers}$(spec_lease_fm_scalar "$spec" date)	${spec}	${root}"$'\n'
    done
    # A here-string, not `printf '%s'`: command substitution stripped the trailing newline from `$roots`, and
    # `read` would then drop the outermost root — the enclosing workspace tree, or the only tree there is.
  done <<< "$roots"

  [ -n "$blockers" ] || return 0

  # A blocker whose `depends-on:` names an active `in-progress` spec is waiting on that work, and Rule #10
  # keeps it at `specify` until the dependency is done, so it cannot hold a lease against it.
  local remaining="" entry entry_spec dep waiting
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    # Fields are cut with parameter expansion, never `read -r` under `IFS=$'\t'`: a tab is IFS whitespace, so
    # `read` would collapse the empty `date:` of a spec that has none and shift every field left.
    entry_spec="${entry#*	}"; entry_spec="${entry_spec%%	*}"
    waiting=0
    while IFS= read -r dep; do
      [ -n "$dep" ] || continue
      if printf '%s' "$in_progress" | grep -qxF -- "$dep"; then waiting=1; break; fi
    done < <(spec_lease_fm_list "$entry_spec" depends-on)
    [ "$waiting" -eq 0 ] && remaining="${remaining}${entry}"$'\n'
  done <<< "$blockers"

  [ -n "$remaining" ] || return 0

  local earliest
  earliest="$(printf '%s' "$remaining" | sort | head -1)"
  SPEC_LEASE_SPEC="$(printf '%s' "$earliest" | cut -f2)"
  SPEC_LEASE_ROOT="$(printf '%s' "$earliest" | cut -f3)"
  SPEC_LEASE_STATUS="$(spec_lease_fm_scalar "$SPEC_LEASE_SPEC" status)"
  SPEC_LEASE_REL="$rel"
  return 1
}

# The second line every guard prints under its own first line, so both doors state the same way out.
spec_lease_allow_conditions() {
  printf '%s\n' "Allowed when either: an active spec at 'in-progress' lists this path in affected-code; or that blocker's 'depends-on:' names an active spec at 'in-progress' (spec-lifecycle.md § Status transitions)."
}
