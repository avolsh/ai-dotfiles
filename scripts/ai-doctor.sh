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
#      spec-workflows prompts templates skills agents upstream boundaries.md docs
#   3. ~/.<tool>/.active-manifest (when present): `profile` matches the
#      requested profile and `target` resolves.
#   4. cloud session (--cloud, or CLAUDE_CODE_REMOTE=true): ~/.claude carries
#      the system layer and every framework skill, settings.json every
#      framework hook, each repo beside the dotfiles core.hooksPath, and the
#      Docker daemon answers (IMP-20261025-cloud-sessions FR-4).
#
# Usage:
#   ai-doctor.sh [--fast] [--cloud] [<profile>]
#     --fast      manifest + instruction links only (SessionStart budget)
#     --cloud     add the cloud-session checks (implied by CLAUDE_CODE_REMOTE=true)
#     <profile>   defaults to $AI_PROFILE, then "personal"
#
# Env: AI_DOTFILES overrides the dotfiles root (tests use this);
#      AI_CLOUD_HOME overrides ~/.claude, AI_DOCTOR_DOCKER the docker binary.
# Exit: 0 all checks pass; 1 any failure (each failure printed with the
# expected target).
set -euo pipefail

FAST=0
CLOUD=0
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] && CLOUD=1
PROFILE=""
for arg in "$@"; do
  case "$arg" in
    --fast) FAST=1 ;;
    --cloud) CLOUD=1 ;;
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
    [ -e "$AI_DOTFILES/docs" ] && check_link "$tool_dir/docs"
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

if [ "$CLOUD" -eq 1 ]; then
  cfg="${AI_CLOUD_HOME:-$HOME/.claude}"
  for entry in CLAUDE.md boundaries.md docs $REFS; do
    case "$entry" in
      skills) continue ;;   # a harness-owned real dir; checked per skill below
      CLAUDE.md) src="$AI_DOTFILES/framework/templates/system/claude/CLAUDE.md" ;;
      docs) src="$AI_DOTFILES/docs" ;;
      *) src="$AI_DOTFILES/framework/$entry" ;;
    esac
    [ -e "$src" ] || continue
    [ -e "$cfg/$entry" ] || fail "$cfg/$entry (missing — re-run: ai-cloud-setup.sh $PROFILE)"
  done
  for skill in "$AI_DOTFILES"/framework/skills/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    [ -e "$cfg/skills/$name" ] || fail "$cfg/skills/$name (framework skill not linked)"
  done
  template="$AI_DOTFILES/framework/templates/system/claude/hooks.json"
  if [ -f "$template" ]; then
    while IFS= read -r cmd; do
      [ -n "$cmd" ] && fail "$cfg/settings.json: hook missing: $cmd"
    done < <(AI_DF="$AI_DOTFILES" python3 - "$template" "$cfg/settings.json" <<'PY'
import json, os, sys
want = json.loads(open(sys.argv[1]).read().replace("@AI_DOTFILES@", os.environ["AI_DF"]))
have = {}
if os.path.exists(sys.argv[2]):
    try:
        have = json.load(open(sys.argv[2]))
    except ValueError:
        pass
def commands(doc):
    return {h.get("command") for groups in doc.get("hooks", {}).values()
            for g in groups for h in g.get("hooks", [])}
for cmd in sorted(commands(want) - commands(have)):
    print(cmd)
PY
)
  fi
  for repo in "$(dirname "$AI_DOTFILES")"/*/; do
    [ -d "$repo/.git" ] || continue
    hp="$(git -C "$repo" config core.hooksPath || true)"
    [ "$hp" = "$AI_DOTFILES/scripts/git-hooks" ] \
      || fail "${repo%/}: core.hooksPath='$hp' (expected $AI_DOTFILES/scripts/git-hooks)"
  done
  "${AI_DOCTOR_DOCKER:-docker}" info >/dev/null 2>&1 \
    || fail "docker daemon not reachable (ai-cloud-setup.sh starts it)"
fi

if [ "$fails" -gt 0 ]; then
  echo "ai-doctor: $fails failure(s) ✗" >&2
  exit 1
fi
echo "ai-doctor: profile '$PROFILE' OK ✓"
