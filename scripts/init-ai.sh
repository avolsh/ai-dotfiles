#!/usr/bin/env bash
# scripts/init-ai.sh
#
# Provision an existing project repo with sync-agents.sh and Makefile
# targets. Idempotent — re-running on a provisioned project is a no-op.
#
# Usage: init-ai.sh <project-path>

set -euo pipefail

_err() { printf 'init-ai: %s\n' "$*" >&2; }

project="${1:-}"
if [ -z "$project" ]; then
  _err "usage: init-ai.sh <project-path>"
  exit 2
fi

if [ ! -d "$project" ]; then
  _err "not a directory: $project"
  exit 2
fi

if [ -z "${AI_DOTFILES:-}" ]; then
  _err "AI_DOTFILES is not set"
  exit 2
fi

template="$AI_DOTFILES/framework/templates/scripts/sync-agents.sh"
if [ ! -f "$template" ]; then
  _err "template not found: $template"
  exit 2
fi

changed=0

# --- 1. Copy sync-agents.sh ---
dst="$project/scripts/sync-agents.sh"
mkdir -p "$project/scripts"
if [ -f "$dst" ] && cmp -s "$template" "$dst"; then
  : # already matches
else
  cp "$template" "$dst"
  chmod +x "$dst"
  changed=1
  echo "copied: $dst"
fi

# --- 2. Append Makefile targets if missing ---
makefile="$project/Makefile"
if [ ! -f "$makefile" ]; then
  _err "no Makefile found at $makefile — skipping target injection"
else
  if ! grep -q '^sync-agents:' "$makefile"; then
    printf '\nsync-agents:\n\t./scripts/sync-agents.sh\n' >> "$makefile"
    changed=1
    echo "added: sync-agents target to $makefile"
  fi
  if ! grep -q '^sync-agents-check:' "$makefile"; then
    printf '\nsync-agents-check:\n\t./scripts/sync-agents.sh --check\n' >> "$makefile"
    changed=1
    echo "added: sync-agents-check target to $makefile"
  fi
fi

# --- 3. Run sync-agents ---
if [ -f "$project/.github/copilot-instructions.md" ]; then
  "$dst" && echo "ran: sync-agents.sh"
else
  echo "skip: no .github/copilot-instructions.md — sync-agents not run"
fi

if [ "$changed" -eq 0 ]; then
  echo "no changes — project already provisioned"
fi
