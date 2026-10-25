#!/usr/bin/env bash
# scripts/ai-workspace.sh
#
# Scaffold a workspace root — <dir>, or the current directory — by copying
# every template under framework/templates/workspace/ into it, preserving the
# relative directory structure. Existing files are skipped (never overwritten).
#
# --docs <clone> scaffolds the docs repo instead (IMP-20261025-cloud-sessions
# FR-16): the root files go to <clone>/workspace/, which ai-workspace-link.sh
# links into the root, and the template's docs/ content to <clone>/ itself,
# since that clone is the root's docs/.
#
# Does NOT run `make sync-agents` — fill in placeholders in _canonical.md
# first, then run it where the Makefile landed.
#
# Usage: ai-workspace [<dir> | --docs <clone>]

set -euo pipefail

_err() { printf 'ai-workspace: %s\n' "$*" >&2; }
_log() { printf '%s\n' "$*" >&2; }

if [ -z "${AI_DOTFILES:-}" ]; then
  _err "AI_DOTFILES is not set (define it in ~/.zshrc)"
  exit 2
fi
if [ ! -d "$AI_DOTFILES" ]; then
  _err "AI_DOTFILES does not point to a directory: $AI_DOTFILES"
  exit 2
fi

src_root="$AI_DOTFILES/framework/templates/workspace"
if [ ! -d "$src_root" ]; then
  _err "workspace templates not found: $src_root"
  exit 2
fi

docs_mode=0
case "${1:-}" in
  --docs) [ "$#" -ge 2 ] || { _err "--docs needs the docs clone"; exit 2; }; docs_mode=1; target_root="$2" ;;
  -*) _err "unknown option '$1'"; exit 2 ;;
  *) target_root="${1:-$PWD}" ;;
esac
[ -d "$target_root" ] || { _err "not a directory: $target_root"; exit 2; }
target_root="$(cd "$target_root" && pwd)"
copied=0
skipped=0

# Walk every file under src_root and copy preserving the relative path.
while IFS= read -r -d '' src; do
  rel="${src#$src_root/}"
  dst="$target_root/$rel"
  if [ "$docs_mode" -eq 1 ]; then
    case "$rel" in
      docs/*) dst="$target_root/${rel#docs/}" ;;
      *) dst="$target_root/workspace/$rel" ;;
    esac
  fi
  if [ -e "$dst" ]; then
    _log "skip: $rel (already exists)"
    skipped=$((skipped + 1))
    continue
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  copied=$((copied + 1))
  _log "copied: $rel"
done < <(find "$src_root" -type f -print0)

root_files="$target_root"
if [ "$docs_mode" -eq 1 ]; then
  root_files="$target_root/workspace"
else
  # Ensure docs/ exists even if every template was already present.
  mkdir -p "$target_root/docs"
fi

# Preserve executable bit on the workspace-local sync-agents script.
if [ -f "$root_files/.github/scripts/sync-agents.sh" ]; then
  chmod +x "$root_files/.github/scripts/sync-agents.sh"
fi

printf '✓ workspace scaffolded at %s (copied=%d, skipped=%d)\n' \
  "$target_root" "$copied" "$skipped"
printf '\nNext steps:\n'
printf '  1. Fill in <placeholder> markers in %s/_canonical.md\n' "$root_files"
printf '  2. Run: make -C %s sync-agents\n' "$root_files"
