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

  for ref in spec-workflows prompts templates skills agents upstream; do
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

# --- 4. Render hook adapter configs (IMP-20260610-mechanize-framework-guardrails T3) ---
# Canonical templates carry @AI_DOTFILES@ placeholders; rendered copies are
# real files (not symlinks) so each harness reads absolute script paths.
render_hook_template() { # $1 tool, $2 template filename, $3 rendered relative path
  local template="$AI_DOTFILES/framework/templates/system/$1/$2"
  local out="$profile_dir/$1/$3"
  [ -f "$template" ] || return 0
  mkdir -p "$(dirname "$out")"
  sed "s|@AI_DOTFILES@|$AI_DOTFILES|g" "$template" > "$out"
  _log "rendered: $out"
}

render_hook_template codex   hooks.json              hooks.json
render_hook_template copilot copilot-cli-policy.json hooks/framework-policy.json

# Claude Code reads hooks from settings.json — merge the rendered 'hooks'
# key into the profile's claude/settings.json, preserving every other key.
merge_claude_hooks() {
  local template="$AI_DOTFILES/framework/templates/system/claude/hooks.json"
  local settings="$profile_dir/claude/settings.json"
  [ -f "$template" ] || return 0
  AI_DOTFILES="$AI_DOTFILES" python3 - "$template" "$settings" <<'PY'
import json, os, sys
template_path, settings_path = sys.argv[1], sys.argv[2]
with open(template_path, encoding="utf-8") as fh:
    rendered = fh.read().replace("@AI_DOTFILES@", os.environ["AI_DOTFILES"])
hooks = json.loads(rendered)["hooks"]
settings = {}
if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as fh:
        settings = json.load(fh)
settings["hooks"] = hooks
with open(settings_path, "w", encoding="utf-8") as fh:
    json.dump(settings, fh, indent=2)
    fh.write("\n")
print(f"merged hooks into: {settings_path}", file=sys.stderr)
PY
}
merge_claude_hooks

printf '✓ profile=%s initialized at %s\n' "$profile" "$profile_dir"
