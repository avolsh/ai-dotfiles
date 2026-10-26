#!/usr/bin/env bash
# scripts/ai-cloud-setup.sh
#
# Wire the AI Framework into a Claude Code cloud session
# (IMP-20261025-cloud-sessions FR-1..FR-3). Run from the cloud environment's
# Setup script, which starts in the directory holding the cloned repos:
#
#   [ ! -f ai-dotfiles/scripts/ai-cloud-setup.sh ] || bash ai-dotfiles/scripts/ai-cloud-setup.sh <profile>
#
# A session may clone any subset of the project's repos: a missing clone,
# the docs one included, is a warning, never a failed setup
# (IMP-20261026-cloud-setup-partial-sessions FR-2).
#
# `<system>/` is ~/.claude here: the harness keeps its own files in it, so
# CLAUDE_CONFIG_DIR is never repointed and nothing it owns is replaced.
# Idempotent: a second run changes nothing.
#
# Usage: ai-cloud-setup.sh [--no-docker] [--docs <repo>] <profile>
#        --docs names the clone whose workspace/ becomes the root files, needed
#        only when several clones hold workspace/CLAUDE.md; see
#        ai-workspace-link.sh for what happens without it.
# Env:   AI_CLOUD_HOME overrides ~/.claude; ai-cloud-docker.sh reads the
#        AI_CLOUD_DOCKER_* variables (tests use these).
set -euo pipefail

_err() { printf 'ai-cloud-setup: %s\n' "$*" >&2; }

docker=1
docs=()
profile=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-docker) docker=0 ;;
    --docs) [ "$#" -ge 2 ] || { _err "--docs needs a repo name"; exit 2; }; docs=(--docs "$2"); shift ;;
    --docs=*) docs=(--docs "${1#--docs=}") ;;
    -*) _err "unknown option '$1'"; exit 2 ;;
    *) profile="$1" ;;
  esac
  shift
done
[ -n "$profile" ] || { _err "usage: ai-cloud-setup.sh [--no-docker] [--docs <repo>] <profile>"; exit 2; }

DF="$(cd "$(dirname "$0")/.." && pwd)"
WS="$(dirname "$DF")"
CFG="${AI_CLOUD_HOME:-$HOME/.claude}"

# 1. The profile itself, so ai-doctor's profile checks hold here too.
AI_DOTFILES="$DF" "$DF/scripts/ai-profile-init.sh" "$profile"

# shellcheck source=lib/profile-links.sh
. "$DF/scripts/lib/profile-links.sh"

# 2. The system layer and every framework skill into ~/.claude; a real entry
#    the harness owns (its skills/ dir, its synced skills) is kept.
ai_links_wire_dir "$DF" "$CFG" claude

# 3. Framework hooks and env, merged beside whatever the CLI keeps there.
ai_links_merge_claude_settings "$DF" "$CFG/settings.json" "$profile"

# 4. The git backstop in every cloned repo.
for repo in "$WS"/*/; do
  [ -d "$repo/.git" ] || continue
  git -C "$repo" config core.hooksPath "$DF/scripts/git-hooks"
done

# 5. The workspace root as on a laptop: docs, env/ai-dotfiles, src/<host>/<org>/<repo>
#    and the root files from docs/workspace/ (FR-13).
AI_DOTFILES="$DF" "$DF/scripts/ai-workspace-link.sh" --cloud "${docs[@]}" "$WS"

# 6. Docker for the contract and integration suites, as the SessionStart hook
#    starts it again after a resume (ai-cloud-docker.sh).
[ "$docker" -eq 0 ] || "$DF/scripts/ai-cloud-docker.sh" --force

printf '✓ cloud session wired: profile=%s system=%s\n' "$profile" "$CFG"
