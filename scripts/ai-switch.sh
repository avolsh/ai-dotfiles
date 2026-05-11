#!/usr/bin/env bash
# scripts/ai-switch.sh
#
# Switch the active <profile, backend> pair for Claude Code, Copilot CLI,
# and Codex CLI. Renders framework templates + identity body fragments into
# each tool's home, lays per-entry symlinks for skills/agents, installs
# tool-agnostic reference symlinks, and writes a manifest per tool.
#
# FR-9, FR-10. Counterpart: scripts/sync-agents.sh (single-profile fork).
#
# Usage (sourced via the `ai` alias from ~/.zshrc):
#   ai <profile> <backend>          # e.g., ai personal local
#   ai-local                         # alias for `ai personal local`
#   ai-cloud                         # alias for `ai personal cloud-claude`
#
# This script is designed to be SOURCED (so the env vars from
# profile.env / backends/<backend>.env persist in the user's shell).
# It must NOT use `set -e` at the top level — that would terminate the
# user's shell when sourced. All error handling is explicit.

# --- Sourced-mode detection (FR-10) ---
_ai_sourced=0
if [ -n "${ZSH_VERSION:-}" ]; then
  case "${ZSH_EVAL_CONTEXT:-}" in
    *:file|*:file:*) _ai_sourced=1 ;;
  esac
elif [ -n "${BASH_VERSION:-}" ]; then
  [ "${BASH_SOURCE[0]}" != "$0" ] && _ai_sourced=1
fi

_ai_log()  { printf '%s\n' "$*" >&2; }
_ai_err()  { printf 'ai-switch: %s\n' "$*" >&2; }

# --- Main routine returns an integer; the bottom of the file converts
#     it to `return` (sourced) or `exit` (executed). ---
ai_switch_main() {
  local profile="${1:-}"
  local backend="${2:-}"

  if [ -z "$profile" ] || [ -z "$backend" ]; then
    _ai_err "usage: ai-switch <profile> <backend>"
    return 2
  fi

  if [ -z "${AI_DOTFILES:-}" ]; then
    _ai_err "AI_DOTFILES is not set (define it in ~/.zshrc per FR-21)"
    return 2
  fi
  if [ ! -d "$AI_DOTFILES" ]; then
    _ai_err "AI_DOTFILES does not point to a directory: $AI_DOTFILES"
    return 2
  fi

  local profile_env="$AI_DOTFILES/profiles/$profile/profile.env"
  local backend_env="$AI_DOTFILES/backends/$backend.env"

  if [ ! -f "$profile_env" ]; then
    _ai_err "profile env not found: $profile_env"
    return 2
  fi
  if [ ! -f "$backend_env" ]; then
    _ai_err "backend env not found: $backend_env"
    return 2
  fi

  if ! command -v envsubst >/dev/null 2>&1; then
    _ai_err "envsubst not on PATH (install gettext)"
    return 3
  fi

  # --- 1. Source profile.env ---
  # shellcheck disable=SC1090
  . "$profile_env" || { _ai_err "failed to source $profile_env"; return 3; }

  # --- 2. Source backend.env ---
  # shellcheck disable=SC1090
  . "$backend_env" || { _ai_err "failed to source $backend_env"; return 3; }

  # --- 3. Render template + append profile body + append preferences,
  #         atomic mv to target. Tool-target map (FR-9 step 3). ---
  local prefs="$AI_DOTFILES/profiles/$profile/preferences.md"
  local profile_dir="$AI_DOTFILES/profiles/$profile"

  local tool template profile_body target_dir target_file tmp
  for tool in claude copilot codex; do
    case "$tool" in
      claude)
        template="$AI_DOTFILES/framework/tools/claude/CLAUDE.md.template"
        profile_body="$profile_dir/CLAUDE.md"
        target_dir="$HOME/.claude"
        target_file="$target_dir/CLAUDE.md"
        ;;
      copilot)
        template="$AI_DOTFILES/framework/tools/copilot/AGENTS.md.template"
        profile_body="$profile_dir/AGENTS.md"
        target_dir="$HOME/.copilot"
        target_file="$target_dir/AGENTS.md"
        ;;
      codex)
        template="$AI_DOTFILES/framework/tools/codex/AGENTS.md.template"
        profile_body="$profile_dir/AGENTS.md"
        target_dir="$HOME/.codex"
        target_file="$target_dir/AGENTS.md"
        ;;
    esac

    if [ ! -f "$template" ]; then
      _ai_err "template missing: $template"
      return 3
    fi

    # Validate / create target home dir
    if [ -e "$target_dir" ] && [ ! -d "$target_dir" ]; then
      _ai_err "target home is not a directory: $target_dir"
      return 4
    fi
    if ! mkdir -p "$target_dir"; then
      _ai_err "cannot create target dir: $target_dir"
      return 4
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/ai-switch.$tool.XXXXXX")"
    if [ -z "$tmp" ] || [ ! -f "$tmp" ]; then
      _ai_err "mktemp failed for $tool"
      return 3
    fi

    # 3a. Allowlisted envsubst — only the explicit non-secret vars are
    # substituted; any other $VAR in the template stays literal. Auth
    # variables (ANTHROPIC_AUTH_TOKEN, ANTHROPIC_API_KEY) are not in the
    # allowlist and never reach the rendered file.
    if ! envsubst '$AI_PROFILE $ANTHROPIC_BASE_URL $ANTHROPIC_MODEL' \
         < "$template" > "$tmp"; then
      rm -f "$tmp"
      _ai_err "envsubst failed for $template"
      return 3
    fi

    # 3b. Append profile body fragment if present.
    if [ -f "$profile_body" ]; then
      printf '\n' >> "$tmp"
      cat "$profile_body" >> "$tmp"
    fi

    # 3c. Append identity preferences if present.
    if [ -f "$prefs" ]; then
      printf '\n' >> "$tmp"
      cat "$prefs" >> "$tmp"
    fi

    # 3d. Atomic write.
    if ! mv "$tmp" "$target_file"; then
      rm -f "$tmp"
      _ai_err "could not write $target_file"
      return 3
    fi
  done

  # --- 4. Per-entry symlink overlay for skills (claude+copilot+codex)
  #         and agents (claude+copilot only — Codex does not consume
  #         agents). Profile entries are processed AFTER framework
  #         entries so `ln -sfn` lets them win on name collision. ---
  _ai_overlay() {
    # $1 subdir (skills|agents)
    # $2..  list of tool home dirs
    local subdir="$1"; shift
    local tool_home src_root entry name
    # zsh: unmatched globs abort by default; nullglob makes them expand to nothing.
    [ -n "${ZSH_VERSION:-}" ] && setopt local_options nullglob 2>/dev/null || true
    for tool_home in "$@"; do
      mkdir -p "$tool_home/$subdir" || {
        _ai_err "cannot create $tool_home/$subdir"
        return 4
      }
      for src_root in "$AI_DOTFILES/framework/$subdir" \
                      "$AI_DOTFILES/profiles/$profile/$subdir"; do
        [ -d "$src_root" ] || continue
        for entry in "$src_root"/*; do
          [ -e "$entry" ] || continue
          name="$(basename "$entry")"
          ln -sfn "$entry" "$tool_home/$subdir/$name" || {
            _ai_err "ln failed: $tool_home/$subdir/$name -> $entry"
            return 4
          }
        done
      done
    done
  }

  _ai_overlay skills "$HOME/.claude" "$HOME/.copilot" "$HOME/.codex" || return $?
  _ai_overlay agents "$HOME/.claude" "$HOME/.copilot" || return $?

  # --- 4a. Tool-agnostic reference symlinks: one symlink per tool home
  #         per subdir. Resolves <system>/{spec-workflows,prompts,
  #         templates,boundaries.md} references inside framework skills. ---
  local ref tool_home
  for tool_home in "$HOME/.claude" "$HOME/.copilot" "$HOME/.codex"; do
    for ref in spec-workflows prompts templates; do
      if [ -d "$AI_DOTFILES/framework/$ref" ]; then
        ln -sfn "$AI_DOTFILES/framework/$ref" "$tool_home/$ref" || {
          _ai_err "ln failed: $tool_home/$ref"
          return 4
        }
      fi
    done
    if [ -f "$AI_DOTFILES/framework/boundaries.md" ]; then
      ln -sfn "$AI_DOTFILES/framework/boundaries.md" "$tool_home/boundaries.md" || {
        _ai_err "ln failed: $tool_home/boundaries.md"
        return 4
      }
    fi
  done

  # --- 5. Stale-link cleanup. Remove managed symlinks whose source no
  #         longer exists OR no longer lives under framework/<subdir> or
  #         profile/<subdir>. Plain (non-symlink) files are left alone. ---
  _ai_cleanup_overlay() {
    # $1 subdir
    # $2..  tool home dirs
    local subdir="$1"; shift
    local tool_home entry target prefix_fw prefix_pf
    # zsh: unmatched globs abort by default; nullglob makes them expand to nothing.
    [ -n "${ZSH_VERSION:-}" ] && setopt local_options nullglob 2>/dev/null || true
    prefix_fw="$AI_DOTFILES/framework/$subdir/"
    prefix_pf="$AI_DOTFILES/profiles/$profile/$subdir/"
    for tool_home in "$@"; do
      [ -d "$tool_home/$subdir" ] || continue
      for entry in "$tool_home/$subdir"/*; do
        [ -L "$entry" ] || continue
        target="$(readlink "$entry")"
        case "$target" in
          "$prefix_fw"*|"$prefix_pf"*)
            # source still listed; keep only if path actually exists
            [ -e "$target" ] || rm -f "$entry"
            ;;
          *)
            # source neither in framework nor in active profile
            rm -f "$entry"
            ;;
        esac
      done
    done
  }
  _ai_cleanup_overlay skills "$HOME/.claude" "$HOME/.copilot" "$HOME/.codex"
  _ai_cleanup_overlay agents "$HOME/.claude" "$HOME/.copilot"

  # Cleanup stale ref symlinks (step 4a): remove only when the source
  # under framework/ no longer exists. Otherwise leave in place.
  for tool_home in "$HOME/.claude" "$HOME/.copilot" "$HOME/.codex"; do
    for ref in spec-workflows prompts templates boundaries.md; do
      if [ -L "$tool_home/$ref" ] && [ ! -e "$tool_home/$ref" ]; then
        rm -f "$tool_home/$ref"
      fi
    done
  done

  # --- 6. Write per-tool .active-manifest. NO auth values. ---
  local skill_count agent_count timestamp
  skill_count="$({ \
      [ -d "$AI_DOTFILES/framework/skills" ] && ls -1 "$AI_DOTFILES/framework/skills"; \
      [ -d "$AI_DOTFILES/profiles/$profile/skills" ] && ls -1 "$AI_DOTFILES/profiles/$profile/skills"; \
    } 2>/dev/null | sort -u | grep -c . || true)"
  agent_count="$({ \
      [ -d "$AI_DOTFILES/framework/agents" ] && ls -1 "$AI_DOTFILES/framework/agents"; \
      [ -d "$AI_DOTFILES/profiles/$profile/agents" ] && ls -1 "$AI_DOTFILES/profiles/$profile/agents"; \
    } 2>/dev/null | sort -u | grep -c . || true)"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local manifest_for
  for tool in claude copilot codex; do
    case "$tool" in
      claude)  manifest_for="$HOME/.claude/.active-manifest";  target_file="$HOME/.claude/CLAUDE.md" ;;
      copilot) manifest_for="$HOME/.copilot/.active-manifest"; target_file="$HOME/.copilot/AGENTS.md" ;;
      codex)   manifest_for="$HOME/.codex/.active-manifest";   target_file="$HOME/.codex/AGENTS.md" ;;
    esac
    {
      printf 'profile=%s\n'   "$profile"
      printf 'backend=%s\n'   "$backend"
      printf 'base_url=%s\n'  "${ANTHROPIC_BASE_URL:-}"
      printf 'model=%s\n'     "${ANTHROPIC_MODEL:-}"
      printf 'target=%s\n'    "$target_file"
      printf 'skills=%s\n'    "$skill_count"
      printf 'agents=%s\n'    "$agent_count"
      printf 'timestamp=%s\n' "$timestamp"
    } > "$manifest_for"
  done

  # --- 7. Summary ---
  printf '✓ profile=%s backend=%s model=%s skills=%s agents=%s\n' \
    "$profile" "$backend" "${ANTHROPIC_MODEL:-}" "$skill_count" "$agent_count"
}

ai_switch_main "$@"
_ai_rc=$?
unset -f ai_switch_main _ai_overlay _ai_cleanup_overlay _ai_log _ai_err 2>/dev/null
if [ "$_ai_sourced" = "1" ]; then
  unset _ai_sourced
  return $_ai_rc 2>/dev/null
else
  unset _ai_sourced
  exit $_ai_rc
fi
