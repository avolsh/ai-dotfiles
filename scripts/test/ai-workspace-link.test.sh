#!/usr/bin/env bash
# scripts/test/ai-workspace-link.test.sh
#
# Self-tests for scripts/ai-workspace-link.sh (AC-7 of
# IMP-20261025-cloud-sessions). Two fixtures: the flat clones of a cloud
# session, and a laptop layout whose root already holds real files — one
# identical to its docs/workspace/ source, one that differs.
set -euo pipefail
# The host's git config may rewrite origins (url.<base>.insteadOf; a cloud container sets it through
# GIT_CONFIG_COUNT); the fixtures read them as written.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GIT_CONFIG_COUNT

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }
clone() { # $1 dir, $2 origin URL ("" = none)
  git init -q "$1"
  [ -z "$2" ] || git -C "$1" remote add origin "$2"
}
listing() { (cd "$1" && find . -path ./ai-dotfiles -prune -o -print | sort | while IFS= read -r p; do
  printf '%s %s\n' "$p" "$(readlink "$p" || true)"; done); }

# --- 1. cloud: flat clones beside the dotfiles ---
WS="$TMP/cloud"
DF="$WS/ai-dotfiles"
mkdir -p "$DF"
cp -R "$SRC/scripts" "$DF/"
clone "$DF" https://github.com/avolsh/ai-dotfiles
clone "$WS/tobevisit-docs" https://github.com/tobeverse/tobevisit-docs
mkdir -p "$WS/tobevisit-docs/workspace/.github"
echo "# workspace" > "$WS/tobevisit-docs/workspace/CLAUDE.md"
echo "x" > "$WS/tobevisit-docs/workspace/.github/copilot-instructions.md"
clone "$WS/repo-a" https://github.com/tobeverse/repo-a.git
clone "$WS/repo-b" git@github.com:geeoz/repo-b.git
clone "$WS/no-origin" ""
mkdir -p "$WS/not-a-repo"

"$DF/scripts/ai-workspace-link.sh" --cloud "$WS" >/dev/null 2>&1 || fail "cloud run rc"
[ "$(readlink "$WS/CLAUDE.md")" = "docs/workspace/CLAUDE.md" ] || fail "root CLAUDE.md is not the relative link"
grep -q workspace "$WS/CLAUDE.md" 2>/dev/null || fail "root CLAUDE.md does not resolve"
[ -f "$WS/.github/copilot-instructions.md" ] || fail "dot entry not linked"
[ "$(readlink "$WS/docs")" = "tobevisit-docs" ] || fail "docs not linked to the clone holding workspace/"
[ "$(cd "$WS/env/ai-dotfiles" && pwd -P)" = "$(cd "$DF" && pwd -P)" ] || fail "env/ai-dotfiles does not resolve"
[ "$(cd "$WS/src/github.com/tobeverse/repo-a" && pwd -P)" = "$(cd "$WS/repo-a" && pwd -P)" ] || fail "https origin not placed"
[ "$(cd "$WS/src/github.com/geeoz/repo-b" && pwd -P)" = "$(cd "$WS/repo-b" && pwd -P)" ] || fail "ssh origin not placed"
[ -e "$WS/src/github.com/avolsh/ai-dotfiles" ] && fail "the dotfiles placed under src/ as well as env/"
[ -e "$WS/src/github.com/tobeverse/tobevisit-docs" ] && fail "the docs clone placed under src/ as well as docs"
[ -e "$WS/src/not-a-repo" ] && fail "a non-repo placed"

before="$(listing "$WS")"
"$DF/scripts/ai-workspace-link.sh" --cloud "$WS" >/dev/null 2>&1 || fail "second cloud run rc"
[ "$before" = "$(listing "$WS")" ] || fail "second cloud run changed the root"

# --- 2. laptop: layout already in place, real root files ---
L="$TMP/laptop"
LDF="$L/env/ai-dotfiles"
mkdir -p "$LDF" "$L/docs/workspace" "$L/src/github.com/tobeverse"
cp -R "$SRC/scripts" "$LDF/"
echo "# new" > "$L/docs/workspace/CLAUDE.md"
echo "# same" > "$L/docs/workspace/AGENTS.md"
echo "# old, edited on the laptop" > "$L/CLAUDE.md"
echo "# same" > "$L/AGENTS.md"

out="$("$LDF/scripts/ai-workspace-link.sh" 2>&1)" || fail "laptop run rc"
[ -L "$L/CLAUDE.md" ] && fail "a differing real file was replaced"
grep -q "edited on the laptop" "$L/CLAUDE.md" || fail "the differing real file lost its content"
echo "$out" | grep -q "$L/CLAUDE.md differs" || fail "the differing real file not reported"
[ "$(readlink "$L/AGENTS.md")" = "docs/workspace/AGENTS.md" ] || fail "an identical real file not replaced by the link"
echo "$out" | grep -q "in the way" && fail "the cloud layout was attempted on a laptop"
[ -e "$L/env/ai-dotfiles/../../src/github.com/tobeverse/ai-dotfiles" ] && fail "laptop layout touched"
[ -e "$L/docs/docs" ] && fail "docs linked on a laptop"

if [ "$fails" -ne 0 ]; then
  echo "$fails ai-workspace-link test(s) failed ✗" >&2
  exit 1
fi
echo "ai-workspace-link tests passed ✓"
