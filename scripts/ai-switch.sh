#!/usr/bin/env bash
# scripts/ai-switch.sh
#
# Switch the active profile by exporting CLAUDE_CONFIG_DIR,
# COPILOT_HOME, and CODEX_HOME at the named profile's pre-built tool
# subdirs. Persists the active profile for new shells via a managed
# ~/.zshrc block and for new GUI apps via launchctl setenv.
#
# Usage (sourced via the `ai` alias from ~/.zshrc):
#   ai                    # report current state
#   ai <profile>          # e.g., ai personal
#   ai --reset            # remove active-profile env
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

_ai_launchctl_setenv() {
  if command -v launchctl >/dev/null 2>&1; then
    launchctl setenv "$1" "$2" >/dev/null 2>&1 || true
  fi
}

_ai_launchctl_unsetenv() {
  if command -v launchctl >/dev/null 2>&1; then
    launchctl unsetenv "$1" >/dev/null 2>&1 || true
  fi
}

_ai_var_value() {
  eval "printf '%s' \"\${$1:-}\""
}

_ai_print_var() {
  local name="$1"
  local value
  value="$(_ai_var_value "$name")"
  if [ -n "$value" ]; then
    printf '%s=%s\n' "$name" "$value"
  else
    printf '%s=(unset)\n' "$name"
  fi
}

_ai_active_profile_from_rc() {
  local rc_file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local start_line end_line

  [ -f "$rc_file" ] || return 1
  grep -qF "$start_marker" "$rc_file" || return 1

  start_line="$(grep -nF "$start_marker" "$rc_file" | head -1 | cut -d: -f1)"
  end_line="$(grep -nF "$end_marker" "$rc_file" | head -1 | cut -d: -f1)"
  if [ -z "$end_line" ] || [ "$end_line" -lt "$start_line" ]; then
    return 1
  fi

  sed -n "$((start_line + 1)),$((end_line - 1))p" "$rc_file" \
    | sed -n 's/^export AI_PROFILE="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' \
    | head -1
}

_ai_write_active_block() {
  local rc_file="$1"
  local block_content="$2"
  local start_marker="$3"
  local end_marker="$4"
  local tmp start_line end_line

  tmp="$(mktemp)"

  if [ -f "$rc_file" ] && grep -qF "$start_marker" "$rc_file"; then
    start_line="$(grep -nF "$start_marker" "$rc_file" | head -1 | cut -d: -f1)"
    end_line="$(grep -nF "$end_marker" "$rc_file" | head -1 | cut -d: -f1)"
    if [ -z "$end_line" ] || [ "$end_line" -lt "$start_line" ]; then
      _ai_err "$rc_file has start marker without matching end marker; refusing to edit"
      rm -f "$tmp"
      return 3
    fi
    : > "$tmp"
    if [ "$start_line" -gt 1 ]; then
      head -n "$((start_line - 1))" "$rc_file" >> "$tmp"
    fi
    printf '%s\n' "$block_content" >> "$tmp"
    tail -n "+$((end_line + 1))" "$rc_file" >> "$tmp"
  else
    if [ -s "$rc_file" ]; then
      cat "$rc_file" > "$tmp"
      printf '\n' >> "$tmp"
    fi
    printf '%s\n' "$block_content" >> "$tmp"
  fi

  if [ -f "$rc_file" ] && cmp -s "$tmp" "$rc_file"; then
    rm -f "$tmp"
    return 0
  fi

  mv "$tmp" "$rc_file"
}

_ai_remove_active_block() {
  local rc_file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp start_line end_line

  [ -f "$rc_file" ] || return 0
  grep -qF "$start_marker" "$rc_file" || return 0

  start_line="$(grep -nF "$start_marker" "$rc_file" | head -1 | cut -d: -f1)"
  end_line="$(grep -nF "$end_marker" "$rc_file" | head -1 | cut -d: -f1)"
  if [ -z "$end_line" ] || [ "$end_line" -lt "$start_line" ]; then
    _ai_err "$rc_file has start marker without matching end marker; refusing to edit"
    return 3
  fi

  tmp="$(mktemp)"
  : > "$tmp"
  if [ "$start_line" -gt 1 ]; then
    head -n "$((start_line - 1))" "$rc_file" >> "$tmp"
  fi
  tail -n "+$((end_line + 1))" "$rc_file" >> "$tmp"

  if cmp -s "$tmp" "$rc_file"; then
    rm -f "$tmp"
    return 0
  fi

  mv "$tmp" "$rc_file"
}

_ai_available_profiles() {
  local profiles_dir="$1"
  local found=0
  local profile_dir name

  if [ ! -d "$profiles_dir" ]; then
    printf '(none)\n'
    return 0
  fi

  for profile_dir in "$profiles_dir"/*; do
    [ -d "$profile_dir" ] || continue
    name="${profile_dir##*/}"
    case "$name" in
      *.example) continue ;;
    esac
    printf '%s\n' "$name"
    found=1
  done

  if [ "$found" -eq 0 ]; then
    printf '(none)\n'
  fi
}

_ai_report_state() {
  local rc_file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local profile=""

  if [ -n "${AI_PROFILE:-}" ]; then
    profile="$AI_PROFILE"
  else
    profile="$(_ai_active_profile_from_rc "$rc_file" "$start_marker" "$end_marker")"
  fi

  if [ -n "$profile" ]; then
    printf 'Active profile: %s\n' "$profile"
  else
    printf 'Active profile: no profile active\n'
  fi

  _ai_print_var CLAUDE_CONFIG_DIR
  _ai_print_var COPILOT_HOME
  _ai_print_var CODEX_HOME

  printf '\nUsage:\n'
  printf '  ai <profile>\n'
  printf '  ai --reset\n'
  printf '\nAvailable profiles:\n'
  _ai_available_profiles "${AI_DOTFILES:-}/profiles"

  if [ -z "$profile" ]; then
    printf "\nRun 'ai-profile-init <profile>' before first switch.\n"
  fi
}

_ai_is_profile_managed() {
  local tool="$1"
  local name="$2"

  case "$name" in
    agents|boundaries.md|skills|prompts|spec-workflows|templates)
      return 0
      ;;
  esac

  case "$tool:$name" in
    claude:CLAUDE.md|copilot:copilot-instructions.md|codex:AGENTS.md)
      return 0
      ;;
  esac

  return 1
}

_ai_should_skip_shared_name() {
  local name="$1"

  case "$name" in
    *.tmp*|*.bak|..*)
      return 0
      ;;
  esac

  return 1
}

_ai_link_shared_state_for_tool() {
  local tool="$1"
  local profile_tool_dir="$2"
  local home_tool_dir="$HOME/.$tool"
  local src name dst

  mkdir -p "$home_tool_dir"

  while IFS= read -r src; do
    name="${src##*/}"

    if _ai_is_profile_managed "$tool" "$name"; then
      continue
    fi
    if _ai_should_skip_shared_name "$name"; then
      continue
    fi

    dst="$profile_tool_dir/$name"
    if { [ -e "$dst" ] || [ -L "$dst" ]; } && [ ! -L "$dst" ]; then
      _ai_err "shared state target exists and is not a symlink; skipping: $dst"
      continue
    fi

    if [ -L "$dst" ]; then
      rm -f "$dst"
    fi
    ln -sfn "$src" "$dst"
  done < <(find "$home_tool_dir" -mindepth 1 -maxdepth 1 -print)
}

_ai_link_shared_state() {
  local profile_dir="$1"

  _ai_link_shared_state_for_tool claude "$profile_dir/claude"
  _ai_link_shared_state_for_tool copilot "$profile_dir/copilot"
  _ai_link_shared_state_for_tool codex "$profile_dir/codex"
}

_ai_reset_framework_links_for_tool() {
  local profile_dir="$1"
  local tool="$2"
  local target_dir="$profile_dir/$tool"
  local ref

  mkdir -p "$target_dir"

  for ref in spec-workflows prompts templates skills agents; do
    if [ -d "$AI_DOTFILES/framework/$ref" ]; then
      if [ -e "$target_dir/$ref" ] || [ -L "$target_dir/$ref" ]; then
        rm -rf "$target_dir/$ref"
      fi
      ln -sfn "$AI_DOTFILES/framework/$ref" "$target_dir/$ref"
    fi
  done

  if [ -f "$AI_DOTFILES/framework/boundaries.md" ]; then
    if [ -e "$target_dir/boundaries.md" ] || [ -L "$target_dir/boundaries.md" ]; then
      rm -rf "$target_dir/boundaries.md"
    fi
    ln -sfn "$AI_DOTFILES/framework/boundaries.md" "$target_dir/boundaries.md"
  fi
}

_ai_remove_profile_symlinks() {
  if [ -d "$AI_DOTFILES/profiles" ]; then
    find "$AI_DOTFILES/profiles" -type l -exec rm -f {} +
  fi
}

ai_switch_main() {
  local rc_file="${AI_SWITCH_RC_FILE:-$HOME/.zshrc}"
  local marker_start='# >>> ai-dotfiles active profile >>>'
  local marker_end='# <<< ai-dotfiles active profile <<<'
  local profile=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --rc-file)
        if [ -z "${2:-}" ]; then
          _ai_err "--rc-file requires a path argument"
          return 2
        fi
        rc_file="$2"
        shift 2
        ;;
      --reset)
        if [ -n "$profile" ]; then
          _ai_err "--reset does not accept a profile argument"
          return 2
        fi
        profile="__RESET__"
        shift
        ;;
      -h|--help)
        printf 'usage: ai-switch [--rc-file <path>] [<profile>|--reset]\n'
        return 0
        ;;
      *)
        if [ -n "$profile" ]; then
          if [ "$profile" = "__RESET__" ]; then
            _ai_err "--reset does not accept a profile argument"
          else
            _ai_err "unexpected argument: $1 (signature is 'ai <profile>')"
          fi
          return 2
        fi
        profile="$1"
        shift
        ;;
    esac
  done

  if [ -z "${AI_DOTFILES:-}" ]; then
    _ai_err "AI_DOTFILES is not set (define it in ~/.zshrc)"
    return 2
  fi
  if [ ! -d "$AI_DOTFILES" ]; then
    _ai_err "AI_DOTFILES does not point to a directory: $AI_DOTFILES"
    return 2
  fi

  if [ -z "$profile" ]; then
    _ai_report_state "$rc_file" "$marker_start" "$marker_end"
    return 0
  fi

  if [ "$profile" = "__RESET__" ]; then
    _ai_remove_active_block "$rc_file" "$marker_start" "$marker_end" || return $?
    _ai_remove_profile_symlinks
    _ai_launchctl_unsetenv CLAUDE_CONFIG_DIR
    _ai_launchctl_unsetenv COPILOT_HOME
    _ai_launchctl_unsetenv CODEX_HOME
    unset CLAUDE_CONFIG_DIR
    unset COPILOT_HOME
    unset CODEX_HOME
    unset AI_PROFILE
    printf '✓ ai-dotfiles active profile reset\n'
    return 0
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
    _ai_reset_framework_links_for_tool "$profile_dir" "$tool"
  done

  _ai_link_shared_state "$profile_dir"

  # --- Source profile.env (sets AI_PROFILE; may also set ANTHROPIC_MODEL) ---
  # shellcheck disable=SC1090
  . "$profile_env" || { _ai_err "failed to source $profile_env"; return 3; }

  # --- Export tool config dirs ---
  export CLAUDE_CONFIG_DIR="$profile_dir/claude"
  export COPILOT_HOME="$profile_dir/copilot"
  export CODEX_HOME="$profile_dir/codex"

  local block_content
  block_content=$(cat <<EOF
$marker_start
# Managed by env/ai-dotfiles. Edit by re-running scripts/ai-switch.sh.
export AI_PROFILE="$AI_PROFILE"
export CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR"
export COPILOT_HOME="$COPILOT_HOME"
export CODEX_HOME="$CODEX_HOME"
$marker_end
EOF
)

  _ai_write_active_block "$rc_file" "$block_content" "$marker_start" "$marker_end" || return $?

  _ai_launchctl_setenv CLAUDE_CONFIG_DIR "$CLAUDE_CONFIG_DIR"
  _ai_launchctl_setenv COPILOT_HOME "$COPILOT_HOME"
  _ai_launchctl_setenv CODEX_HOME "$CODEX_HOME"

  printf '✓ profile=%s CLAUDE_CONFIG_DIR=%s COPILOT_HOME=%s CODEX_HOME=%s\n' \
    "$profile" "$CLAUDE_CONFIG_DIR" "$COPILOT_HOME" "$CODEX_HOME"
}

ai_switch_main "$@"
_ai_rc=$?
unset -f ai_switch_main _ai_err _ai_launchctl_setenv _ai_launchctl_unsetenv \
  _ai_var_value _ai_print_var _ai_active_profile_from_rc _ai_write_active_block \
  _ai_remove_active_block _ai_available_profiles _ai_report_state \
  _ai_is_profile_managed _ai_should_skip_shared_name _ai_link_shared_state_for_tool \
  _ai_link_shared_state _ai_reset_framework_links_for_tool _ai_remove_profile_symlinks 2>/dev/null
if [ "$_ai_sourced" = "1" ]; then
  unset _ai_sourced
  return $_ai_rc 2>/dev/null
else
  unset _ai_sourced
  exit $_ai_rc
fi
