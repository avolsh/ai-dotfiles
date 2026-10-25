#!/usr/bin/env bash
# scripts/lib/workspace-layout.sh
#
# The workspace layout, in one place for ai-workspace-link.sh (which builds it)
# and ai-doctor.sh (which checks it) — IMP-20261025-cloud-sessions FR-13.
#
#   <root>/env/ai-dotfiles             this dotfiles clone
#   <root>/docs                        the docs clone (tobevisit-docs): named with --docs
#   <root>/<section>                   a clone docs/workspace/.mrconfig names by its URL
#   <root>/src/<host>/<org>/<repo>     every other clone, from its origin URL
#   <root>/<entry>                     -> docs/workspace/<entry>, for each entry there
#
# Sourced: no work on load, no `set -e`, functions only.

# The workspace root: the directory above env/ on a laptop, the one holding the
# clones in a cloud session.
ai_ws_root() { # $1 dotfiles root
  local parent
  parent="$(dirname "$1")"
  if [ "$(basename "$parent")" = "env" ]; then dirname "$parent"; else printf '%s\n' "$parent"; fi
}

# One path component a link may be built from: no separator, no `.` or `..`.
ai_ws_safe_name() { # $1 name
  case "$1" in ""|.|..) return 1 ;; esac
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

# The docs clone in directory $1: one holding workspace/CLAUDE.md. Named ($2):
# that clone. Unnamed: the only such clone — never a guess between several,
# since its files become the root's rules.
# Prints the path; returns 1 when there is none, 2 when several qualify (or the
# name is not a plain clone name), 3 when the named clone holds no
# workspace/CLAUDE.md.
ai_ws_docs_clone() { # $1 directory holding the clones, $2 optional clone name
  local repo found=()
  if [ -n "${2:-}" ]; then
    ai_ws_safe_name "$2" || return 2
    repo="$1/$2"
    { [ -L "$repo" ] || [ ! -d "$repo/.git" ]; } && return 1
    [ -f "$repo/workspace/CLAUDE.md" ] || return 3
    printf '%s\n' "$repo"
    return 0
  fi
  for repo in "$1"/*/; do
    repo="${repo%/}"
    [ -L "$repo" ] && continue
    [ -d "$repo/.git" ] && [ -f "$repo/workspace/CLAUDE.md" ] && found+=("$repo")
  done
  [ "${#found[@]}" -eq 0 ] && return 1
  [ "${#found[@]}" -gt 1 ] && return 2
  printf '%s\n' "${found[0]}"
}

# The framework files a project repo carries once `ai-project.sh` scaffolded it
# and `make sync-agents` rendered it.
AI_WS_PROJECT_FILES="_canonical.md CLAUDE.md AGENTS.md .github/copilot-instructions.md"

# Those of them missing from repo $1, space-separated; empty when it is initialised.
ai_ws_missing_framework() { # $1 repo
  local f out=""
  for f in $AI_WS_PROJECT_FILES; do [ -e "$1/$f" ] || out="$out $f"; done
  printf '%s\n' "${out# }"
}

# A relative path of plain names only (FR-13): no leading /, no empty, . or .. part.
ai_ws_safe_relpath() { # $1 path
  local part parts
  case "$1" in ""|/*|*/) return 1 ;; esac
  IFS=/ read -ra parts <<< "$1"
  for part in "${parts[@]}"; do ai_ws_safe_name "$part" || return 1; done
}

# <host>/<org>/<repo> of a clone's origin; see ai_ws_url_path.
ai_ws_src_path() { # $1 clone
  ai_ws_url_path "$(git -C "$1" remote get-url origin 2>/dev/null || true)"
}

# <host>/<org>/<repo> of a git URL (https://host/org/repo[.git],
# ssh://[user@]host/org/repo or git@host:org/repo). Every component must be a
# plain name: a URL is anyone's text, and it becomes a path in the root.
# Returns 1 when it is none of those forms, 2 when it does not make a safe path.
ai_ws_url_path() { # $1 url
  local url="${1%.git}"
  case "$url" in
    https://*|http://*|ssh://*) url="${url#*://}"; case "${url%%/*}" in *@*) url="${url#*@}" ;; esac ;;
    git@*:*) url="${url#git@}"; url="${url/://}" ;;
    *) return 1 ;;
  esac
  case "$url" in */*/*) ;; *) return 2 ;; esac
  ai_ws_safe_relpath "$url" || return 2
  printf '%s\n' "$url"
}

# The repos docs/workspace/.mrconfig lists, as "<host>/<org>/<repo><TAB><section>" lines: each
# section whose checkout is `git clone '<url>' …` with a URL of a known form. A section whose path is
# not plain is left out and named on stderr (FR-17); `chain` and other URL-less sections are skipped.
ai_ws_mr_repos() { # $1 .mrconfig
  local sec url key
  [ -f "$1" ] || return 0
  while IFS=$'\t' read -r sec url; do
    [ -n "$url" ] || continue
    if ! ai_ws_safe_relpath "$sec"; then
      printf 'workspace-layout: .mrconfig section [%s] is not a plain path; ignored\n' "$sec" >&2
      continue
    fi
    key="$(ai_ws_url_path "$url")" || continue
    printf '%s\t%s\n' "$key" "$sec"
  done < <(awk '
    /^[ \t]*\[.*\][ \t]*$/ { if (s != "") print s "\t" u; s = $0; sub(/^[ \t]*\[/, "", s); sub(/\][ \t]*$/, "", s); u = ""; next }
    s != "" && /^[ \t]*checkout[ \t]*=/ && match($0, /git clone +\047[^\047]+\047/) {
      u = substr($0, RSTART, RLENGTH); sub(/^git clone +\047/, "", u); sub(/\047$/, "", u) }
    END { if (s != "") print s "\t" u }' "$1")
}

# The section a "<key><TAB><section>" list ($2) gives repo key $1; empty when none.
ai_ws_section_of() { # $1 key, $2 list from ai_ws_mr_repos
  awk -F'\t' -v k="$1" '$1 == k { print $2; exit }' <<< "$2"
}
