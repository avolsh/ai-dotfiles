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
#   5. workspace root (both modes, once docs/workspace/ exists; always in the
#      cloud): each entry of docs/workspace/ is linked into the root, and in the
#      cloud docs, env/ai-dotfiles and src/<host>/<org>/<repo> resolve (FR-13).
#      A repo under src/ without the framework files, or a docs repo without
#      workspace/CLAUDE.md, is a NOTE on stdout, never a failure (FR-15).
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
# Not a failure: something the agent asks the owner about (stdout reaches the session at SessionStart).
note() { printf 'ai-doctor: NOTE %s\n' "$1"; }
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

# A cloud entry passes as a link into ai-dotfiles. A real directory where a framework directory belongs is one
# the harness or the CLI owns (skills/, agents/): the setup script links each framework entry inside it, so each
# is checked there. Any other real path standing in a link's place is one the setup script left alone ("real
# path in the way"), so the framework entry it should be is absent.
check_cloud_link() { # $1 = path in ~/.claude, $2 = the framework source it must resolve to, $3 = "inner" one level down
  local inner
  if [ -L "$1" ] && [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]; then
    return 0
  elif [ -z "${3:-}" ] && [ -d "$1" ] && [ ! -L "$1" ] && [ -d "$2" ]; then
    for inner in "$2"/* "$2"/.[!.]*; do
      [ -e "$inner" ] || continue
      check_cloud_link "$1/$(basename "$inner")" "$inner" inner
    done
  elif [ -e "$1" ] && [ ! -L "$1" ]; then
    fail "$1 (a real path stands where the framework link belongs — move it aside, re-run: ai-cloud-setup.sh $PROFILE)"
  else
    fail "$1 (missing — re-run: ai-cloud-setup.sh $PROFILE)"
  fi
}

if [ "$CLOUD" -eq 1 ]; then
  cfg="${AI_CLOUD_HOME:-$HOME/.claude}"
  for entry in CLAUDE.md boundaries.md docs $REFS; do
    case "$entry" in
      CLAUDE.md) src="$AI_DOTFILES/framework/templates/system/claude/CLAUDE.md" ;;
      docs) src="$AI_DOTFILES/docs" ;;
      *) src="$AI_DOTFILES/framework/$entry" ;;
    esac
    [ -e "$src" ] || continue
    check_cloud_link "$cfg/$entry" "$src"
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

# shellcheck source=lib/workspace-layout.sh
. "$(dirname "$0")/lib/workspace-layout.sh"
ws_root="$(ai_ws_root "$AI_DOTFILES")"
if [ "$CLOUD" -eq 1 ]; then
  # The setup script recorded its choice as the docs link; without one, say why none was made.
  docs_real="$(readlink -f "$ws_root/docs" 2>/dev/null || true)"
  if [ -L "$ws_root/docs" ] && [ -d "$docs_real/.git" ] && [ ! -f "$docs_real/workspace/CLAUDE.md" ]; then
    note "$docs_real: not initialised for the AI framework (no workspace/CLAUDE.md) — ask the owner, then: ai-workspace.sh --docs $docs_real"
  elif [ ! -L "$ws_root/docs" ] || [ ! -d "$docs_real/workspace" ]; then
    docs_real=""
    rc=0
    ai_ws_docs_clone "$ws_root" >/dev/null || rc=$?
    case "$rc" in
      1) fail "$ws_root: no clone holds workspace/CLAUDE.md (add the docs repo to the project, or commit its workspace/)" ;;
      2) fail "$ws_root: several clones hold workspace/CLAUDE.md (name one in the Setup script: --docs <repo>)" ;;
      *) fail "$ws_root/docs (not linked to the docs clone — re-run: ai-cloud-setup.sh)" ;;
    esac
  fi
  [ "$(readlink -f "$ws_root/env/ai-dotfiles" 2>/dev/null)" = "$(readlink -f "$AI_DOTFILES")" ] \
    || fail "$ws_root/env/ai-dotfiles (missing — re-run: ai-cloud-setup.sh $PROFILE)"
  for repo in "$ws_root"/*/; do
    repo="${repo%/}"
    { [ -L "$repo" ] || [ ! -d "$repo/.git" ]; } && continue
    [ "$(readlink -f "$repo")" = "$(readlink -f "$AI_DOTFILES")" ] && continue
    [ "$(readlink -f "$repo")" = "$docs_real" ] && continue
    src="$(ai_ws_src_path "$repo")" || continue
    [ "$(readlink -f "$ws_root/src/$src" 2>/dev/null)" = "$(readlink -f "$repo")" ] \
      || fail "$ws_root/src/$src (missing — re-run: ai-cloud-setup.sh $PROFILE)"
  done
fi
# Project repos without the framework: the owner decides whether to initialise each (FR-15).
for repo in "$ws_root"/src/*/*/*/; do
  repo="${repo%/}"
  [ -d "$repo/.git" ] || continue
  missing="$(ai_ws_missing_framework "$repo")"
  [ -z "$missing" ] \
    || note "$repo: not initialised for the AI framework (missing: $missing) — ask the owner, then: ai-project.sh $repo"
done
if [ -d "$ws_root/docs/workspace" ]; then
  while IFS= read -r entry; do
    name="$(basename "$entry")"
    [ -L "$ws_root/$name" ] && [ "$(readlink -f "$ws_root/$name")" = "$(readlink -f "$entry")" ] \
      || fail "$ws_root/$name (not linked to docs/workspace/$name — run: ai-workspace-link.sh)"
  done < <(find "$ws_root/docs/workspace" -mindepth 1 -maxdepth 1)
fi

if [ "$fails" -gt 0 ]; then
  echo "ai-doctor: $fails failure(s) ✗" >&2
  exit 1
fi
echo "ai-doctor: profile '$PROFILE' OK ✓"
