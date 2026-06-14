#!/usr/bin/env bash
# scripts/lib/profile-links.sh
#
# Single source of truth for profile wiring (FR-1, FR-3 of
# IMP-20260610-stabilize-profile-switching). Both entry points —
# ai-profile-init.sh (executed) and ai-switch.sh (sourced into the user's
# interactive shell) — call these functions; neither carries its own copy
# of the ref list or rendering logic.
#
# Sourced-context contract: no `set -e` / `set -u` at file scope, no work
# on load, no globals beyond the AI_LINKS_* constants and ai_links_* /
# _ai_links_* functions. Callers may `unset -f` the function set after use.
#
# Linking semantics (FR-3):
#   * existing symlink           -> replaced (repair path)
#   * missing path               -> created
#   * existing REAL directory    -> per-entry symlinks created inside it;
#     CLI-owned entries (e.g. codex/skills/.system) are preserved; a real
#     entry shadowing a framework entry is left in place and reported
#   * existing REAL file         -> reported and skipped, never clobbered

AI_LINKS_REFS="spec-workflows prompts templates skills agents upstream"
AI_LINKS_TOOLS="claude copilot codex"

_ai_links_log() { printf 'profile-links: %s\n' "$*" >&2; }

# Emit a space-separated token list one-per-line. Used instead of
# `for x in $VAR`: zsh does NOT word-split unquoted parameter expansions
# (no SH_WORD_SPLIT by default), so the bare loop runs once with the whole
# string — this library is sourced into the user's zsh, so the bash-only
# idiom silently collapsed and broke `ai <profile>`.
_ai_links_words() { printf '%s\n' "$1" | tr ' ' '\n'; }

_ai_links_instruction_name() {
  case "$1" in
    claude)  printf 'CLAUDE.md' ;;
    copilot) printf 'copilot-instructions.md' ;;
    codex)   printf 'AGENTS.md' ;;
    *) return 1 ;;
  esac
}

# Link a single source path to a destination, honoring the FR-3 semantics.
_ai_links_place() { # $1 src, $2 dst
  local src="$1" dst="$2" entry name
  [ -e "$src" ] || return 0

  if [ -L "$dst" ]; then
    ln -sfn "$src" "$dst"
    return 0
  fi
  if [ ! -e "$dst" ]; then
    ln -sfn "$src" "$dst"
    return 0
  fi
  if [ -d "$dst" ] && [ -d "$src" ]; then
    # CLI-owned real directory: per-entry links inside, never nest the
    # whole-dir link (the historical skills/skills defect). Enumerate via
    # `find` rather than a shell glob — globs differ across bash/zsh
    # (zsh's default `nomatch` aborts on an empty `.[!.]*`), and this
    # library is sourced into the user's interactive shell.
    while IFS= read -r entry; do
      [ -n "$entry" ] || continue
      name="${entry##*/}"
      if [ -L "$dst/$name" ] || [ ! -e "$dst/$name" ]; then
        ln -sfn "$entry" "$dst/$name"
      else
        _ai_links_log "kept CLI-owned entry (shadows framework): $dst/$name"
      fi
    done < <(find "$src" -mindepth 1 -maxdepth 1)
    return 0
  fi
  _ai_links_log "WARN real path in the way; skipped (never clobbered): $dst"
  return 0
}

# Wire one tool subdir of a profile: instruction file, boundaries, refs.
ai_links_wire_tool() { # $1 dotfiles root, $2 profile_dir, $3 tool
  local df="$1" pdir="$2" tool="$3" tdir iname ref
  tdir="$pdir/$tool"
  mkdir -p "$tdir" || return 1

  iname="$(_ai_links_instruction_name "$tool")" || return 1
  _ai_links_place "$df/framework/templates/system/$tool/$iname" "$tdir/$iname"
  _ai_links_place "$df/framework/boundaries.md" "$tdir/boundaries.md"
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    _ai_links_place "$df/framework/$ref" "$tdir/$ref"
  done < <(_ai_links_words "$AI_LINKS_REFS")
  return 0
}

# Render hook adapter configs (real files, placeholder substituted).
ai_links_render_hooks() { # $1 dotfiles root, $2 profile_dir
  local df="$1" pdir="$2" template out

  template="$df/framework/templates/system/codex/hooks.json"
  if [ -f "$template" ]; then
    out="$pdir/codex/hooks.json"
    mkdir -p "${out%/*}" \
      && sed "s|@AI_DOTFILES@|$df|g" "$template" > "$out" \
      && _ai_links_log "rendered: $out"
  fi

  template="$df/framework/templates/system/copilot/copilot-cli-policy.json"
  if [ -f "$template" ]; then
    out="$pdir/copilot/hooks/framework-policy.json"
    mkdir -p "${out%/*}" \
      && sed "s|@AI_DOTFILES@|$df|g" "$template" > "$out" \
      && _ai_links_log "rendered: $out"
  fi

  # Claude reads hooks from settings.json — merge the rendered 'hooks' key,
  # preserving every other key. settings.json may be a symlink into
  # ~/.claude/settings.json; the merge intentionally writes through it.
  template="$df/framework/templates/system/claude/hooks.json"
  if [ -f "$template" ]; then
    AI_LINKS_DF="$df" python3 - "$template" "$pdir/claude/settings.json" <<'PY'
import json, os, sys
template_path, settings_path = sys.argv[1], sys.argv[2]
with open(template_path, encoding="utf-8") as fh:
    rendered = fh.read().replace("@AI_DOTFILES@", os.environ["AI_LINKS_DF"])
hooks = json.loads(rendered)["hooks"]
settings = {}
if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as fh:
        settings = json.load(fh)
if settings.get("hooks") != hooks:
    settings["hooks"] = hooks
    with open(settings_path, "w", encoding="utf-8") as fh:
        json.dump(settings, fh, indent=2)
        fh.write("\n")
    print(f"profile-links: merged hooks into: {settings_path}", file=sys.stderr)
PY
  fi
  return 0
}

# Wire a whole profile: every tool subdir + hook adapters.
ai_links_wire_profile() { # $1 dotfiles root, $2 profile_dir
  local df="$1" pdir="$2" tool rc=0
  while IFS= read -r tool; do
    [ -n "$tool" ] || continue
    ai_links_wire_tool "$df" "$pdir" "$tool" || rc=1
  done < <(_ai_links_words "$AI_LINKS_TOOLS")
  ai_links_render_hooks "$df" "$pdir" || rc=1
  return "$rc"
}
