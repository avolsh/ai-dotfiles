#!/usr/bin/env bash
# scripts/ai-doctor.sh
#
# Profile-invariant check (FR-3, IMP-20260610-mechanize-framework-guardrails).
# Verifies that the active profile's tool subdirs are correctly wired so
# breakage is self-announcing instead of silently failing path resolution.
#
# Checks, per tool (claude / copilot / codex) present in the profile dir:
#   1. instruction-file symlink resolves
#      (CLAUDE.md / copilot-instructions.md / AGENTS.md)
#   2. framework reference symlinks resolve:
#      spec-workflows prompts templates skills agents upstream boundaries.md
#   3. ~/.<tool>/.active-manifest (when present): `profile` matches the
#      requested profile and `target` resolves.
#
# Usage:
#   ai-doctor.sh [--fast] [<profile>]
#     --fast      manifest + instruction links only (SessionStart budget)
#     <profile>   defaults to $AI_PROFILE, then "personal"
#
# Env: AI_DOTFILES overrides the dotfiles root (tests use this).
# Exit: 0 all checks pass; 1 any failure (each failure printed with the
# expected target).
set -euo pipefail

FAST=0
PROFILE=""
for arg in "$@"; do
  case "$arg" in
    --fast) FAST=1 ;;
    -*) echo "ai-doctor: unknown option '$arg'" >&2; exit 2 ;;
    *) PROFILE="$arg" ;;
  esac
done
PROFILE="${PROFILE:-${AI_PROFILE:-personal}}"

AI_DOTFILES="${AI_DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
profile_dir="$AI_DOTFILES/profiles/$PROFILE"

fails=0
fail() { printf 'ai-doctor: FAIL %s\n' "$1" >&2; fails=$((fails + 1)); }
check_link() { # $1 = path that must exist and resolve
  local p="$1"
  if [ -L "$p" ]; then
    [ -e "$p" ] || fail "$p -> $(readlink "$p") (broken symlink)"
  elif [ ! -e "$p" ]; then
    fail "$p (missing — re-run: ai-profile-init $PROFILE)"
  fi
}

[ -d "$profile_dir" ] || { fail "$profile_dir (profile dir missing)"; echo "ai-doctor: $fails failure(s) ✗" >&2; exit 1; }

REFS="spec-workflows prompts templates skills agents upstream"

for tool in claude copilot codex; do
  tool_dir="$profile_dir/$tool"
  [ -d "$tool_dir" ] || continue

  case "$tool" in
    claude)  instruction="CLAUDE.md" ;;
    copilot) instruction="copilot-instructions.md" ;;
    codex)   instruction="AGENTS.md" ;;
  esac
  check_link "$tool_dir/$instruction"

  if [ "$FAST" -eq 0 ]; then
    check_link "$tool_dir/boundaries.md"
    for ref in $REFS; do
      # Only require refs that exist in the framework source tree.
      if [ -e "$AI_DOTFILES/framework/$ref" ]; then
        check_link "$tool_dir/$ref"
      fi
    done
  fi

  manifest="$HOME/.$tool/.active-manifest"
  if [ -f "$manifest" ]; then
    m_profile="$(sed -n 's/^profile=//p' "$manifest" | head -1)"
    m_target="$(sed -n 's/^target=//p' "$manifest" | head -1)"
    if [ -n "$m_profile" ] && [ "$m_profile" != "$PROFILE" ]; then
      fail "$manifest: profile='$m_profile' but active profile is '$PROFILE' (run: ai $PROFILE)"
    fi
    if [ -n "$m_target" ] && [ ! -e "$m_target" ]; then
      fail "$manifest: target='$m_target' does not resolve"
    fi
  fi
done

if [ "$fails" -gt 0 ]; then
  echo "ai-doctor: $fails failure(s) ✗" >&2
  exit 1
fi
echo "ai-doctor: profile '$PROFILE' OK ✓"
