#!/usr/bin/env bash
# scripts/ai-profile-init.sh
#
# Initialize (or re-initialize) a profile's tool subdirs by rendering
# the system templates with the profile's identity and creating
# framework symlinks. Run once per profile before the first
# `ai <profile>` switch. Counterpart: scripts/ai-switch.sh.
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
preferences="$profile_dir/preferences.md"

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

if ! command -v envsubst >/dev/null 2>&1; then
  _err "envsubst not on PATH (install gettext)"
  exit 3
fi

# --- 2. Render each tool template into the profile's tool subdir ---
render_tool() {
  local tool="$1"
  local filename="$2"
  local template="$AI_DOTFILES/framework/templates/system/$tool/$filename"
  local target_dir="$profile_dir/$tool"
  local target_file="$target_dir/$filename"
  local tmp

  if [ ! -f "$template" ]; then
    _err "template missing: $template"
    return 3
  fi

  mkdir -p "$target_dir"

  tmp="$(mktemp "${TMPDIR:-/tmp}/ai-profile-init.$tool.XXXXXX")"

  # Allowlisted envsubst — only $AI_PROFILE is substituted.
  if ! envsubst '$AI_PROFILE' < "$template" > "$tmp"; then
    rm -f "$tmp"
    _err "envsubst failed for $template"
    return 3
  fi

  # Append preferences.md if present.
  if [ -f "$preferences" ]; then
    printf '\n' >> "$tmp"
    cat "$preferences" >> "$tmp"
  fi

  # Atomic write.
  if ! mv "$tmp" "$target_file"; then
    rm -f "$tmp"
    _err "could not write $target_file"
    return 3
  fi

  _log "rendered: $target_file"
}

render_tool claude  CLAUDE.md
render_tool copilot copilot-instructions.md
render_tool codex   AGENTS.md

# --- 3. Create framework symlinks inside each tool subdir ---
link_framework() {
  local tool="$1"
  local target_dir="$profile_dir/$tool"
  local ref

  for ref in spec-workflows prompts templates skills; do
    if [ -d "$AI_DOTFILES/framework/$ref" ]; then
      ln -sfn "$AI_DOTFILES/framework/$ref" "$target_dir/$ref"
    fi
  done
  if [ -f "$AI_DOTFILES/framework/boundaries.md" ]; then
    ln -sfn "$AI_DOTFILES/framework/boundaries.md" "$target_dir/boundaries.md"
  fi
}

link_framework claude
link_framework copilot
link_framework codex

printf '✓ profile=%s initialized at %s\n' "$profile" "$profile_dir"
