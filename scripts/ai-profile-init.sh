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

# --- 2. Wire the profile via the shared library (FR-1) ---
# All linking and rendering semantics live in scripts/lib/profile-links.sh —
# the single source of truth shared with ai-switch.sh.
# shellcheck source=lib/profile-links.sh
. "$(dirname "$0")/lib/profile-links.sh"

if ! ai_links_wire_profile "$AI_DOTFILES" "$profile_dir"; then
  _err "profile wiring failed for $profile_dir"
  exit 4
fi

printf '✓ profile=%s initialized at %s\n' "$profile" "$profile_dir"
