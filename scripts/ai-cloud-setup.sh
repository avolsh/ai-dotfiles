#!/usr/bin/env bash
# scripts/ai-cloud-setup.sh
#
# Wire the AI Framework into a Claude Code cloud session
# (IMP-20261025-cloud-sessions FR-1..FR-3). Run from the cloud environment's
# Setup script, which starts in the directory holding the cloned repos:
#
#   bash ai-dotfiles/scripts/ai-cloud-setup.sh <profile>
#
# `<system>/` is ~/.claude here: the harness keeps its own files in it, so
# CLAUDE_CONFIG_DIR is never repointed and nothing it owns is replaced.
# Idempotent: a second run changes nothing.
#
# Usage: ai-cloud-setup.sh [--no-docker] <profile>
# Env:   AI_CLOUD_HOME overrides ~/.claude (tests use this).
set -euo pipefail

_err() { printf 'ai-cloud-setup: %s\n' "$*" >&2; }

docker=1
profile=""
for arg in "$@"; do
  case "$arg" in
    --no-docker) docker=0 ;;
    -*) _err "unknown option '$arg'"; exit 2 ;;
    *) profile="$arg" ;;
  esac
done
[ -n "$profile" ] || { _err "usage: ai-cloud-setup.sh [--no-docker] <profile>"; exit 2; }

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

# 5. Docker for the contract and integration suites. Anonymous Docker Hub
#    pulls from the shared egress address return 429; mirror.gcr.io serves
#    the library images.
if [ "$docker" -eq 1 ] && command -v dockerd >/dev/null 2>&1 && ! docker info >/dev/null 2>&1; then
  mkdir -p /etc/docker
  [ -f /etc/docker/daemon.json ] \
    || printf '{"registry-mirrors":["https://mirror.gcr.io"]}\n' > /etc/docker/daemon.json
  nohup dockerd > /var/log/dockerd.log 2>&1 &
fi

printf '✓ cloud session wired: profile=%s system=%s\n' "$profile" "$CFG"
