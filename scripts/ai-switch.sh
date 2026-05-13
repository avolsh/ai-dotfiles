#!/usr/bin/env bash
# scripts/ai-switch.sh
#
# Switch the active profile by exporting CLAUDE_CONFIG_DIR,
# COPILOT_HOME, and CODEX_HOME at the named profile's pre-built tool
# subdirs. Does NOT render, write, or symlink — those are done once
# per profile by scripts/ai-profile-init.sh.
#
# Usage (sourced via the `ai` alias from ~/.zshrc):
#   ai <profile>          # e.g., ai personal
#
# This script is designed to be SOURCED (so the env-var exports persist
# in the user's shell). It MUST NOT use `set -e` at the top level —
# that would terminate the user's shell when sourced. All error
# handling is explicit.

# --- Sourced-mode detection ---
_ai_sourced=0
if [ -n "${ZSH_VERSION:-}" ]; then
  case "${ZSH_EVAL_CONTEXT:-}" in
    *:file|*:file:*) _ai_sourced=1 ;;
  esac
elif [ -n "${BASH_VERSION:-}" ]; then
  [ "${BASH_SOURCE[0]}" != "$0" ] && _ai_sourced=1
fi

_ai_err() { printf 'ai-switch: %s\n' "$*" >&2; }

ai_switch_main() {
  local profile="${1:-}"

  if [ -z "$profile" ]; then
    _ai_err "usage: ai-switch <profile>"
    return 2
  fi

  # Reject extra args. The legacy <backend> argument is no longer accepted.
  if [ -n "${2:-}" ]; then
    _ai_err "unexpected argument: $2 (backends/ has been removed; signature is 'ai <profile>')"
    return 2
  fi

  if [ -z "${AI_DOTFILES:-}" ]; then
    _ai_err "AI_DOTFILES is not set (define it in ~/.zshrc)"
    return 2
  fi
  if [ ! -d "$AI_DOTFILES" ]; then
    _ai_err "AI_DOTFILES does not point to a directory: $AI_DOTFILES"
    return 2
  fi

  local profile_dir="$AI_DOTFILES/profiles/$profile"
  local profile_env="$profile_dir/profile.env"

  if [ ! -d "$profile_dir" ]; then
    _ai_err "profile not found: $profile_dir"
    return 2
  fi
  if [ ! -f "$profile_env" ]; then
    _ai_err "profile.env not found: $profile_env"
    return 2
  fi

  # Verify each tool subdir is initialized.
  local tool
  for tool in claude copilot codex; do
    if [ ! -d "$profile_dir/$tool" ]; then
      _ai_err "tool subdir missing: $profile_dir/$tool"
      _ai_err "run: ai-profile-init $profile"
      return 4
    fi
  done

  # --- Source profile.env (sets AI_PROFILE; may also set ANTHROPIC_MODEL) ---
  # shellcheck disable=SC1090
  . "$profile_env" || { _ai_err "failed to source $profile_env"; return 3; }

  # --- Export tool config dirs ---
  export CLAUDE_CONFIG_DIR="$profile_dir/claude"
  export COPILOT_HOME="$profile_dir/copilot"
  export CODEX_HOME="$profile_dir/codex"

  printf '✓ profile=%s CLAUDE_CONFIG_DIR=%s COPILOT_HOME=%s CODEX_HOME=%s\n' \
    "$profile" "$CLAUDE_CONFIG_DIR" "$COPILOT_HOME" "$CODEX_HOME"
}

ai_switch_main "$@"
_ai_rc=$?
unset -f ai_switch_main _ai_err 2>/dev/null
if [ "$_ai_sourced" = "1" ]; then
  unset _ai_sourced
  return $_ai_rc 2>/dev/null
else
  unset _ai_sourced
  exit $_ai_rc
fi
