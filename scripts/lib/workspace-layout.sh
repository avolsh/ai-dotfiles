#!/usr/bin/env bash
# scripts/lib/workspace-layout.sh
#
# The workspace layout, in one place for ai-workspace-link.sh (which builds it)
# and ai-doctor.sh (which checks it) — IMP-20261025-cloud-sessions FR-13.
#
#   <root>/env/ai-dotfiles             this dotfiles clone
#   <root>/docs                        the clone holding workspace/ (tobevisit-docs)
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

# The clone beside the dotfiles that holds workspace/; empty when none does.
ai_ws_docs_clone() { # $1 directory holding the clones
  local repo
  for repo in "$1"/*/; do
    repo="${repo%/}"
    [ -L "$repo" ] && continue
    [ -d "$repo/.git" ] && [ -d "$repo/workspace" ] && { printf '%s\n' "$repo"; return 0; }
  done
  return 0
}

# <host>/<org>/<repo> of a clone's origin (https://host/org/repo[.git] or
# git@host:org/repo[.git]); empty when it has none.
ai_ws_src_path() { # $1 clone
  local url
  url="$(git -C "$1" remote get-url origin 2>/dev/null || true)"
  url="${url%.git}"
  case "$url" in
    https://*|http://*) url="${url#*://}"; url="${url#*@}" ;;
    git@*:*) url="${url#git@}"; url="${url/://}" ;;
    *) return 0 ;;
  esac
  case "$url" in */*/*) printf '%s\n' "$url" ;; esac
}
