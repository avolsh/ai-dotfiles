#!/usr/bin/env bash
# scripts/ai-project.sh
#
# Scaffold the current directory as a new project repo by copying every
# template under framework/templates/project/ into the current working
# directory, preserving the relative directory structure. Existing files
# are skipped (never overwritten).
#
# Does NOT run `make sync-agents` — fill in placeholders in
# .github/copilot-instructions.md first, then run it manually.
#
# Usage (from the target project root):
#   ai-project

set -euo pipefail

_err() { printf 'ai-project: %s\n' "$*" >&2; }
_log() { printf '%s\n' "$*" >&2; }

if [ -z "${AI_DOTFILES:-}" ]; then
  _err "AI_DOTFILES is not set (define it in ~/.zshrc)"
  exit 2
fi
if [ ! -d "$AI_DOTFILES" ]; then
  _err "AI_DOTFILES does not point to a directory: $AI_DOTFILES"
  exit 2
fi

src_root="$AI_DOTFILES/framework/templates/project"
if [ ! -d "$src_root" ]; then
  _err "project templates not found: $src_root"
  exit 2
fi

target_root="$PWD"
copied=0
skipped=0

# Walk every file under src_root and copy preserving the relative path.
while IFS= read -r -d '' src; do
  rel="${src#$src_root/}"
  dst="$target_root/$rel"
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

# Ensure docs/ exists even if every template was already present.
mkdir -p "$target_root/docs"

# Preserve executable bit on the project-local sync-agents script.
if [ -f "$target_root/.github/scripts/sync-agents.sh" ]; then
  chmod +x "$target_root/.github/scripts/sync-agents.sh"
fi

printf '✓ project scaffolded at %s (copied=%d, skipped=%d)\n' \
  "$target_root" "$copied" "$skipped"
printf '\nNext steps:\n'
printf '  1. Fill in <placeholder> markers in .github/copilot-instructions.md\n'
printf '  2. Run: make sync-agents\n'
