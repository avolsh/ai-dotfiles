#!/usr/bin/env bash
# scripts/lib/workspace-layout.sh
#
# The workspace layout, in one place for ai-workspace-link.sh (which builds it)
# and ai-doctor.sh (which checks it) — IMP-20261025-cloud-sessions FR-13.
#
#   <root>/env/ai-dotfiles             this dotfiles clone
#   <root>/docs                        the docs clone (tobevisit-docs): named with --docs
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

# <host>/<org>/<repo> of a clone's origin (https://host/org/repo[.git],
# ssh://[user@]host/org/repo or git@host:org/repo). Every component must be a
# plain name: an origin is anyone's text, and it becomes a path under src/.
# Returns 1 when there is no origin of those forms, 2 when it does not make a
# safe path.
ai_ws_src_path() { # $1 clone
  local url part
  url="$(git -C "$1" remote get-url origin 2>/dev/null || true)"
  url="${url%.git}"
  case "$url" in
    https://*|http://*|ssh://*) url="${url#*://}"; case "${url%%/*}" in *@*) url="${url#*@}" ;; esac ;;
    git@*:*) url="${url#git@}"; url="${url/://}" ;;
    *) return 1 ;;
  esac
  case "$url" in */*/*) ;; *) return 2 ;; esac
  case "$url" in */) return 2 ;; esac
  local parts
  IFS=/ read -ra parts <<< "$url"
  for part in "${parts[@]}"; do ai_ws_safe_name "$part" || return 2; done
  printf '%s\n' "$url"
}
