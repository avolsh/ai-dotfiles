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

_ai_link_shared_state_source() {
  local src="$1"
  local dst="$2"

  # A real (non-symlink) entry sits where the profile symlink belongs — the
  # CLI recreated it (e.g. launched with a stale CLAUDE_CONFIG_DIR after a
  # --reset tore the symlink down) and wrote into it. Fold its contents back
  # into the shared source instead of skipping, so sessions / sqlite / config
  # written there are never stranded. This is the same merge logic the
  # --reset restore path uses, just applied at switch time.
  if { [ -e "$dst" ] || [ -L "$dst" ]; } && [ ! -L "$dst" ]; then
    if [ "${dst##*/}" = ".claude.json" ]; then
      # JSON config: merge profile copy into home (home keys preserved,
      # profile keys win), then drop the consumed profile copy.
      if _ai_merge_json_into "$dst" "$src"; then
        rm -f "$dst"
      fi
    else
      _ai_restore_path "$dst" "$src"
    fi

    # If the merge declined to consume it (type mismatch, unparseable JSON),
    # keep the old skip-and-warn safety rather than clobbering real data.
    if { [ -e "$dst" ] || [ -L "$dst" ]; } && [ ! -L "$dst" ]; then
      _ai_err "shared state target still real after restore; skipping to avoid data loss: $dst"
      return 0
    fi
  fi

  if [ -L "$dst" ]; then
    rm -f "$dst"
  fi
  ln -sfn "$src" "$dst"
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
    _ai_link_shared_state_source "$src" "$dst"
  done < <(find "$home_tool_dir" -mindepth 1 -maxdepth 1 -print)

  if [ "$tool" = "claude" ] && [ -e "$HOME/.claude.json" ]; then
    _ai_link_shared_state_source "$HOME/.claude.json" "$profile_tool_dir/.claude.json"
  fi
}

_ai_link_shared_state() {
  local profile_dir="$1"

  _ai_link_shared_state_for_tool claude "$profile_dir/claude"
  _ai_link_shared_state_for_tool copilot "$profile_dir/copilot"
  _ai_link_shared_state_for_tool codex "$profile_dir/codex"
}

# Claude Code derives its macOS Keychain service name from CLAUDE_CONFIG_DIR:
#   unset     -> "Claude Code-credentials"
#   set       -> "Claude Code-credentials-<sha256(CLAUDE_CONFIG_DIR-NFC)[0:8]>"
# Without a matching entry the CLI prompts for /login on every profile
# switch. Replicate the user's existing OAuth token into the profile-specific
# service so the CLI stays authenticated. The Claude Desktop App is
# unaffected because it injects the token directly into its CLI subprocess.
_ai_sync_claude_keychain() {
  local config_dir="$1"
  local default_service="Claude Code-credentials"
  local hash profile_service token existing

  command -v security >/dev/null 2>&1 || return 0
  command -v shasum   >/dev/null 2>&1 || return 0

  hash="$(printf '%s' "$config_dir" | shasum -a 256 | cut -c1-8)"
  profile_service="${default_service}-${hash}"

  existing="$(security find-generic-password -s "$profile_service" -a "$USER" -w 2>/dev/null || true)"
  token="$(security find-generic-password -s "$default_service" -a "$USER" -w 2>/dev/null || true)"

  if [ -z "$token" ]; then
    if [ -z "$existing" ]; then
      _ai_err "no Claude OAuth token in Keychain (service '$default_service'); run 'claude /login' once to authenticate"
    fi
    return 0
  fi

  if [ "$existing" = "$token" ]; then
    return 0
  fi

  if ! security add-generic-password -U -a "$USER" -s "$profile_service" -w "$token" >/dev/null 2>&1; then
    _ai_err "failed to write Keychain entry '$profile_service'"
  fi
}

# Detach exactly one profile: remove its symlinks only (FR-2 of
# IMP-20260610-stabilize-profile-switching). Replaces the legacy
# _ai_remove_profile_symlinks, which deleted symlinks across ALL profiles.
_ai_detach_profile_links() {
  local profile_dir="$1"
  [ -n "$profile_dir" ] || return 0
  [ -d "$profile_dir" ] || return 0
  find "$profile_dir" -type l -exec rm -f {} +
}

# Manifest lifecycle (FR-4): written on every switch, removed on --reset.
# ai-doctor.sh validates exactly these fields (profile, target).
_ai_write_manifests() {
  local profile="$1" profile_dir="$2" tool iname
  for tool in claude copilot codex; do
    case "$tool" in
      claude)  iname="CLAUDE.md" ;;
      copilot) iname="copilot-instructions.md" ;;
      codex)   iname="AGENTS.md" ;;
    esac
    mkdir -p "$HOME/.$tool"
    {
      printf 'profile=%s\n' "$profile"
      printf 'target=%s\n' "$profile_dir/$tool/$iname"
      printf 'timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$HOME/.$tool/.active-manifest"
  done
}

_ai_remove_manifests() {
  local tool
  for tool in claude copilot codex; do
    rm -f "$HOME/.$tool/.active-manifest"
  done
}

# Move a real file/dir from a profile back into $HOME/.<tool>/. Atomic-rename
# writes by Claude/Copilot/Codex CLIs replace the symlinks we create at switch
# time with real files; without this, that fresh state would be stranded in
# the profile dir after --reset and the user would re-authenticate.
_ai_restore_path() {
  local src="$1"
  local dst="$2"
  local child

  [ -e "$src" ] || return 0

  # Stale symlink at destination — clear it so mv lands a real file.
  if [ -L "$dst" ]; then
    rm -f "$dst"
  fi

  if [ ! -e "$dst" ]; then
    mv "$src" "$dst"
    return 0
  fi

  # File overwrites file (profile copy is newer).
  if [ ! -d "$src" ] && [ ! -d "$dst" ]; then
    mv -f "$src" "$dst"
    return 0
  fi

  # Dir-merges-dir — recurse so individual files inside still overwrite.
  if [ -d "$src" ] && [ -d "$dst" ]; then
    while IFS= read -r child; do
      [ -e "$child" ] || continue
      _ai_restore_path "$child" "$dst/${child##*/}"
    done < <(find "$src" -mindepth 1 -maxdepth 1 -print)
    rmdir "$src" 2>/dev/null || true
    return 0
  fi

  # Type mismatch — keep the profile copy intact and warn.
  _ai_err "restore: type mismatch, leaving in place: $src vs $dst"
}

_ai_restore_shared_state_for_tool() {
  local tool="$1"
  local profile_tool_dir="$2"
  local home_tool_dir="$HOME/.$tool"
  local entry name

  [ -d "$profile_tool_dir" ] || return 0
  mkdir -p "$home_tool_dir"

  while IFS= read -r entry; do
    [ -e "$entry" ] || continue
    [ -L "$entry" ] && continue            # symlinks handled by _ai_remove_profile_symlinks
    name="${entry##*/}"

    # Framework-managed entries belong to the profile, not ~/.tool/.
    if _ai_is_profile_managed "$tool" "$name"; then
      continue
    fi
    if _ai_should_skip_shared_name "$name"; then
      continue
    fi

    # The Claude CLI's per-user config sits at ~/.claude.json, not inside ~/.claude/.
    # IMPORTANT: never fall back to mv-f over ~/.claude.json. The profile copy
    # can be a tiny "firstStartTime"-only stub the CLI seeded after the symlink
    # was replaced by an atomic-rename write, and mv-f silently nukes the real
    # 29 KB config (project history, MCP setup, onboarding state). Instead, on
    # merge failure, stash the profile copy beside the home file and warn so
    # the user can inspect and merge manually.
    if [ "$tool" = "claude" ] && [ "$name" = ".claude.json" ]; then
      if _ai_merge_json_into "$entry" "$HOME/.claude.json"; then
        rm -f "$entry"
      else
        local stash="$HOME/.claude.json.unmerged.$(date +%s)"
        if mv "$entry" "$stash" 2>/dev/null; then
          _ai_err "merge into $HOME/.claude.json failed; profile copy stashed at $stash"
        else
          _ai_err "merge into $HOME/.claude.json failed; profile copy left at $entry"
        fi
      fi
      continue
    fi

    _ai_restore_path "$entry" "$home_tool_dir/$name"
  done < <(find "$profile_tool_dir" -mindepth 1 -maxdepth 1 -print)
}

# Merge src JSON into dst JSON; src keys win on conflict. Avoids dropping
# cache/UI state that lives only in the home copy.
_ai_merge_json_into() {
  local src="$1"
  local dst="$2"
  [ -f "$src" ] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$src" "$dst" <<'PY' || return 1
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    s = json.load(f)
d = {}
if os.path.exists(dst):
    try:
        with open(dst) as f:
            d = json.load(f)
    except Exception:
        d = {}
if not isinstance(d, dict) or not isinstance(s, dict):
    sys.exit(2)
d.update(s)
tmp = dst + ".ai-restore.tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2)
os.replace(tmp, dst)
PY
}

_ai_restore_shared_state() {
  local profile_dir="$1"
  [ -d "$profile_dir" ] || return 0
  _ai_restore_shared_state_for_tool claude  "$profile_dir/claude"
  _ai_restore_shared_state_for_tool copilot "$profile_dir/copilot"
  _ai_restore_shared_state_for_tool codex   "$profile_dir/codex"
}

# OAuth tokens may have rotated while the profile-specific Keychain entry
# was the active one. Copy the latest token back to the default service so
# the CLI authenticates after --reset.
_ai_sync_claude_keychain_back() {
  local config_dir="$1"
  local default_service="Claude Code-credentials"
  local hash profile_service profile_token default_token

  command -v security >/dev/null 2>&1 || return 0
  command -v shasum   >/dev/null 2>&1 || return 0

  hash="$(printf '%s' "$config_dir" | shasum -a 256 | cut -c1-8)"
  profile_service="${default_service}-${hash}"

  profile_token="$(security find-generic-password -s "$profile_service" -a "$USER" -w 2>/dev/null || true)"
  [ -z "$profile_token" ] && return 0

  default_token="$(security find-generic-password -s "$default_service" -a "$USER" -w 2>/dev/null || true)"
  [ "$profile_token" = "$default_token" ] && return 0

  security add-generic-password -U -a "$USER" -s "$default_service" -w "$profile_token" >/dev/null 2>&1 \
    || _ai_err "failed to refresh Keychain entry '$default_service' from '$profile_service'"
}

# --- Running-app guard ---------------------------------------------------
# Switching or resetting while a Claude/Codex app still holds the OLD
# CLAUDE_CONFIG_DIR/CODEX_HOME is the trigger for both failure modes we hit:
# stranded/lost session files, and the Desktop app losing its transcript
# links (cliSessionId). Detect such processes and stop, unless --force.
#
# Only flag a process whose environment actually points at a managed profile
# dir — a Claude/Codex window using the default ~/.claude is unaffected by a
# switch and must not block it. Emits "pid<TAB>name" per at-risk process.
_ai_at_risk_processes() {
  command -v pgrep >/dev/null 2>&1 || return 0
  command -v ps    >/dev/null 2>&1 || return 0

  local pids pid envline name
  pids="$( { pgrep -x claude; pgrep -x codex; pgrep -x Claude; pgrep -x Codex; } 2>/dev/null | sort -u )"
  [ -n "$pids" ] || return 0

  printf '%s\n' "$pids" | while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    [ "$pid" = "$$" ] && continue
    envline="$(ps eww -o command= -p "$pid" 2>/dev/null)"
    case "$envline" in
      *"CLAUDE_CONFIG_DIR=$AI_DOTFILES/profiles/"*|*"CODEX_HOME=$AI_DOTFILES/profiles/"*)
        name="$(ps -o comm= -p "$pid" 2>/dev/null)"
        printf '%s\t%s\n' "$pid" "${name##*/}"
        ;;
    esac
  done
}

_ai_guard_running() {
  local op="$1" force="$2"
  local procs line
  procs="$(_ai_at_risk_processes)"
  [ -n "$procs" ] || return 0

  _ai_err "$op: Claude/Codex is running with a managed-profile config:"
  printf '%s\n' "$procs" | while IFS= read -r line; do
    _ai_err "  $line"
  done
  _ai_err "That app keeps the old config and can lose its session links."
  _ai_err "Quit those apps first, then re-run; relaunch them to pick up the switch."
  if [ "$force" = "1" ]; then
    _ai_err "--force given: proceeding anyway."
    return 0
  fi
  _ai_err "Re-run with --force to override."
  return 1
}

ai_switch_main() {
  local rc_file="${AI_SWITCH_RC_FILE:-$HOME/.zshrc}"
  local marker_start='# >>> ai-dotfiles active profile >>>'
  local marker_end='# <<< ai-dotfiles active profile <<<'
  local profile=""
  local force=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --force)
        force=1
        shift
        ;;
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
        printf 'usage: ai-switch [--rc-file <path>] [--force] [<profile>|--reset]\n'
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
    _ai_guard_running "refusing to reset" "$force" || return $?

    # Identify the currently active profile before we rewrite the rc block —
    # its tool dirs may hold real files written by the CLIs (atomic rename
    # replaces our symlinks with regular files) that must be restored to
    # ~/.<tool>/ before symlinks are torn down.
    local active_profile=""
    active_profile="$(_ai_active_profile_from_rc "$rc_file" "$marker_start" "$marker_end" 2>/dev/null)"
    if [ -z "$active_profile" ] && [ -n "${AI_PROFILE:-}" ]; then
      active_profile="$AI_PROFILE"
    fi

    if [ -n "$active_profile" ] && [ -d "$AI_DOTFILES/profiles/$active_profile" ]; then
      _ai_restore_shared_state "$AI_DOTFILES/profiles/$active_profile"
      _ai_sync_claude_keychain_back "$AI_DOTFILES/profiles/$active_profile/claude"
    fi

    _ai_remove_active_block "$rc_file" "$marker_start" "$marker_end" || return $?
    # Scoped detach (FR-2): only the active profile's links are removed;
    # other profiles stay wired. No active profile known -> nothing to detach.
    if [ -n "$active_profile" ]; then
      _ai_detach_profile_links "$AI_DOTFILES/profiles/$active_profile"
    fi
    _ai_remove_manifests

    # Harden against stray CLI launches: a shell or GUI app that still holds a
    # stale CLAUDE_CONFIG_DIR/CODEX_HOME/COPILOT_HOME for the just-detached
    # profile would otherwise recreate real session/sqlite dirs inside it —
    # the cause of the recurring "shared state ... is not a symlink; skipping"
    # warnings and lost sessions on the next switch. Re-point the profile's
    # shared-state slots at ~/.<tool> so any such write passes through to the
    # shared location instead of diverging. Framework links and the rc-block /
    # launchctl env stay removed, so the profile remains inactive.
    if [ -n "$active_profile" ] && [ -d "$AI_DOTFILES/profiles/$active_profile" ]; then
      _ai_link_shared_state "$AI_DOTFILES/profiles/$active_profile"
    fi

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

  _ai_guard_running "refusing to switch" "$force" || return $?

  # Wire the profile via the shared library (FR-1) — the same single source
  # of truth ai-profile-init.sh uses; the switch can no longer drift from it.
  # shellcheck source=lib/profile-links.sh
  . "$AI_DOTFILES/scripts/lib/profile-links.sh" || {
    _ai_err "failed to load $AI_DOTFILES/scripts/lib/profile-links.sh"
    return 3
  }
  ai_links_wire_profile "$AI_DOTFILES" "$profile_dir" || {
    _ai_err "profile wiring failed for $profile_dir"
    return 3
  }

  _ai_link_shared_state "$profile_dir"

  # --- Source profile.env (sets AI_PROFILE — the only variable; FR-6) ---
  # shellcheck disable=SC1090
  . "$profile_env" || { _ai_err "failed to source $profile_env"; return 3; }

  # --- Export tool config dirs ---
  export CLAUDE_CONFIG_DIR="$profile_dir/claude"
  export COPILOT_HOME="$profile_dir/copilot"
  export CODEX_HOME="$profile_dir/codex"

  _ai_sync_claude_keychain "$CLAUDE_CONFIG_DIR"

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

  _ai_write_manifests "$profile" "$profile_dir"

  printf '✓ profile=%s CLAUDE_CONFIG_DIR=%s COPILOT_HOME=%s CODEX_HOME=%s\n' \
    "$profile" "$CLAUDE_CONFIG_DIR" "$COPILOT_HOME" "$CODEX_HOME"
}

ai_switch_main "$@"
_ai_rc=$?
unset -f ai_switch_main _ai_err _ai_launchctl_setenv _ai_launchctl_unsetenv \
  _ai_var_value _ai_print_var _ai_active_profile_from_rc _ai_write_active_block \
  _ai_remove_active_block _ai_available_profiles _ai_report_state \
  _ai_is_profile_managed _ai_should_skip_shared_name _ai_link_shared_state_source \
  _ai_link_shared_state_for_tool _ai_link_shared_state _ai_sync_claude_keychain \
  _ai_sync_claude_keychain_back _ai_restore_path _ai_restore_shared_state \
  _ai_restore_shared_state_for_tool _ai_merge_json_into \
  _ai_detach_profile_links _ai_write_manifests _ai_remove_manifests \
  ai_links_wire_profile ai_links_wire_tool ai_links_render_hooks \
  _ai_links_place _ai_links_instruction_name _ai_links_log \
  _ai_at_risk_processes _ai_guard_running 2>/dev/null
unset AI_LINKS_REFS AI_LINKS_TOOLS 2>/dev/null
if [ "$_ai_sourced" = "1" ]; then
  unset _ai_sourced
  return $_ai_rc 2>/dev/null
else
  unset _ai_sourced
  exit $_ai_rc
fi
