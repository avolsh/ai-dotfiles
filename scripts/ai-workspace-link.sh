#!/usr/bin/env bash
# scripts/ai-workspace-link.sh
#
# Link the workspace root files, kept in the docs repo under workspace/, into
# the workspace root (IMP-20261025-cloud-sessions FR-13). The same relative
# links on a laptop and in a cloud session:
#
#   <root>/CLAUDE.md -> docs/workspace/CLAUDE.md   (and every other entry there)
#
# --cloud first builds the layout a laptop already has, from the clones the
# session put side by side in <root> (scripts/lib/workspace-layout.sh):
# docs, env/ai-dotfiles and src/<host>/<org>/<repo>. `docs` is the clone named
# with --docs; without it, the one clone holding workspace/CLAUDE.md, and none
# when several do. A clone whose origin makes no plain <host>/<org>/<repo> path
# is left out of src/.
#
# A symlink is repaired, a missing entry created, and a real file identical to
# its source replaced by the link. A real entry that differs is kept and
# reported: it is the human's to merge into docs/workspace/. Idempotent;
# `ai-doctor.sh` reports anything left unlinked.
#
# Usage: ai-workspace-link.sh [--cloud [--docs <repo>]] [<root>]
#   <root> defaults to the directory above env/ (laptop) or the one holding
#   this dotfiles clone (cloud).
# Env:   AI_DOTFILES overrides the dotfiles root (tests use this).
set -euo pipefail

_err() { printf 'ai-workspace-link: %s\n' "$*" >&2; }

cloud=0
docs=""
root=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --cloud) cloud=1 ;;
    --docs) [ "$#" -ge 2 ] || { _err "--docs needs a repo name"; exit 2; }; docs="$2"; shift ;;
    --docs=*) docs="${1#--docs=}" ;;
    -*) _err "unknown option '$1'"; exit 2 ;;
    *) root="$1" ;;
  esac
  shift
done
[ -z "$docs" ] || [ "$cloud" -eq 1 ] || { _err "--docs is for --cloud; a laptop's docs/ is already in place"; exit 2; }

DF="${AI_DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=lib/workspace-layout.sh
. "$(dirname "$0")/lib/workspace-layout.sh"
root="${root:-$(ai_ws_root "$DF")}"
[ -d "$root" ] || { _err "workspace root not found: $root"; exit 2; }

# Link $1 (path relative to the link's own directory) at $2, never over a real entry.
place() { # $1 relative target, $2 link
  if [ -L "$2" ] || [ ! -e "$2" ]; then
    mkdir -p "$(dirname "$2")"
    ln -sfn "$1" "$2"
  else
    _err "WARN real path in the way; kept: $2"
  fi
}

# Relative path from directory $1 to path $2.
relpath() { python3 -c 'import os,sys; print(os.path.relpath(sys.argv[2], sys.argv[1]))' "$1" "$2"; }

if [ "$cloud" -eq 1 ]; then
  rc=0
  docs_clone="$(ai_ws_docs_clone "$root" "$docs")" || rc=$?
  case "$rc:$docs" in
    0:*) place "$(basename "$docs_clone")" "$root/docs" ;;
    1:) _err "WARN no clone in $root holds workspace/CLAUDE.md; docs not linked" ;;
    2:) _err "WARN several clones in $root hold workspace/CLAUDE.md; docs not linked — name one: --docs <repo>" ;;
    1:*|2:*) _err "--docs '$docs' is not a clone in $root"; exit 2 ;;
    *) # a docs repo not initialised yet: linked, so ai-workspace.sh --docs can fill it
      docs_clone="$root/$docs"
      place "$docs" "$root/docs"
      _err "WARN $docs_clone holds no workspace/CLAUDE.md yet; docs linked — initialise it: ai-workspace.sh --docs $docs_clone" ;;
  esac
  place "$(relpath "$root/env" "$DF")" "$root/env/ai-dotfiles"
  for repo in "$root"/*/; do
    repo="${repo%/}"
    [ -L "$repo" ] || [ ! -d "$repo/.git" ] && continue
    [ "$(cd "$repo" && pwd -P)" = "$(cd "$DF" && pwd -P)" ] && continue
    [ "$repo" = "$docs_clone" ] && continue
    rc=0
    src="$(ai_ws_src_path "$repo")" || rc=$?
    case "$rc" in
      0) ;;
      1) _err "WARN $repo has no origin URL; not placed under src/"; continue ;;
      *) _err "WARN $repo: origin makes no plain <host>/<org>/<repo> path; not placed under src/"; continue ;;
    esac
    place "$(relpath "$(dirname "$root/src/$src")" "$repo")" "$root/src/$src"
  done
fi

ws="$root/docs/workspace"
if [ ! -d "$ws" ]; then
  _err "WARN $ws not found; no root files linked"
  exit 0
fi
while IFS= read -r entry; do
  name="$(basename "$entry")"
  dst="$root/$name"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if diff -rq "$dst" "$entry" >/dev/null 2>&1; then
      rm -rf -- "$dst"
    else
      _err "WARN $dst differs from docs/workspace/$name; kept — merge it there, then re-run"
      continue
    fi
  fi
  place "docs/workspace/$name" "$dst"
done < <(find "$ws" -mindepth 1 -maxdepth 1 | sort)

printf '✓ workspace root linked: %s\n' "$root"
