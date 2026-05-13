#!/usr/bin/env bash
# scripts/ai-profile-init.sh
#
# Initialize (or re-initialize) a profile's tool subdirs by creating
# framework symlinks. Run once per profile before the first `ai <profile>`
# switch. Counterpart: scripts/ai-switch.sh.
#
# Usage:
#   ai-profile-init <profile>
#
# Example:
#   ai-profile-init personal

set -euo pipefail

_err() { printf 'ai-profile-init: %s\n' "$*" >&2; }
_log() { printf '%s\n' "$*" >&2; }

profile="${1:-}"
if [ -z "$profile" ]; then
  _err "usage: ai-profile-init <profile>"
  exit 2
fi

if [ -z "${AI_DOTFILES:-}" ]; then
  _err "AI_DOTFILES is not set (define it in ~/.zshrc)"
  exit 2
fi
if [ ! -d "$AI_DOTFILES" ]; then
  _err "AI_DOTFILES does not point to a directory: $AI_DOTFILES"
  exit 2
fi

profile_dir="$AI_DOTFILES/profiles/$profile"
profile_env="$profile_dir/profile.env"

if [ ! -d "$profile_dir" ]; then
  _err "profile directory not found: $profile_dir"
  exit 2
fi
if [ ! -f "$profile_env" ]; then
  _err "profile.env not found: $profile_env"
  exit 2
fi

# --- 1. Source profile.env to set $AI_PROFILE ---
# shellcheck disable=SC1090
. "$profile_env"

if [ -z "${AI_PROFILE:-}" ]; then
  _err "AI_PROFILE not set after sourcing $profile_env"
  exit 3
fi

# --- 2. Link each tool template into the profile's tool subdir ---
link_tool_template() {
  local tool="$1"
  local filename="$2"
  local template="$AI_DOTFILES/framework/templates/system/$tool/$filename"
  local target_dir="$profile_dir/$tool"
  local target_file="$target_dir/$filename"

  if [ ! -f "$template" ]; then
    _err "template missing: $template"
    return 3
  fi

  mkdir -p "$target_dir"

  if [ -e "$target_file" ] || [ -L "$target_file" ]; then
    rm -rf "$target_file"
  fi
  ln -sfn "$template" "$target_file"

  _log "linked: $target_file"
}

link_tool_template claude  CLAUDE.md
link_tool_template copilot copilot-instructions.md
link_tool_template codex   AGENTS.md

# --- 3. Create framework symlinks inside each tool subdir ---
link_framework() {
  local tool="$1"
  local target_dir="$profile_dir/$tool"
  local ref

  for ref in spec-workflows prompts templates skills agents; do
    if [ -d "$AI_DOTFILES/framework/$ref" ]; then
      if [ -L "$target_dir/$ref" ]; then
        rm -f "$target_dir/$ref"
      fi
      ln -sfn "$AI_DOTFILES/framework/$ref" "$target_dir/$ref"
    fi
  done
  if [ -f "$AI_DOTFILES/framework/boundaries.md" ]; then
    if [ -L "$target_dir/boundaries.md" ]; then
      rm -f "$target_dir/boundaries.md"
    fi
    ln -sfn "$AI_DOTFILES/framework/boundaries.md" "$target_dir/boundaries.md"
  fi
}

link_framework claude
link_framework copilot
link_framework codex

printf '✓ profile=%s initialized at %s\n' "$profile" "$profile_dir"
