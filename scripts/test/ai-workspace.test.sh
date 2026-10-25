#!/usr/bin/env bash
# scripts/test/ai-workspace.test.sh
#
# Self-tests for scripts/ai-workspace.sh (IMP-20261025-cloud-sessions FR-16,
# AC-8): a workspace root scaffolded into <dir>, and a docs repo scaffolded with
# --docs — root files under workspace/, the template's docs/ at the clone's top,
# nothing the clone already holds overwritten.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_DOTFILES="$ROOT"

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }

# --- 1. <dir>, run from elsewhere ---
ELSEWHERE="$TMP/elsewhere"  # the cwd of every run: it must stay empty
mkdir -p "$TMP/ws" "$ELSEWHERE"
cd "$ELSEWHERE"
"$ROOT/scripts/ai-workspace.sh" "$TMP/ws" >/dev/null 2>&1 || fail "<dir> run rc"
for f in _canonical.md CLAUDE.md AGENTS.md Makefile .github/scripts/sync-agents.sh docs/improvements-log.md; do
  [ -e "$TMP/ws/$f" ] || fail "<dir>: $f not scaffolded"
done
[ -x "$TMP/ws/.github/scripts/sync-agents.sh" ] || fail "<dir>: sync-agents.sh not executable"

# --- 2. --docs: a docs clone that already has its own improvements log ---
D="$TMP/tobevisit-docs"
mkdir -p "$D"
echo "# ours" > "$D/improvements-log.md"
out="$("$ROOT/scripts/ai-workspace.sh" --docs "$D" 2>&1)" || fail "--docs run rc"
for f in _canonical.md CLAUDE.md AGENTS.md Makefile .github/scripts/sync-agents.sh; do
  [ -e "$D/workspace/$f" ] || fail "--docs: workspace/$f not scaffolded"
done
[ -x "$D/workspace/.github/scripts/sync-agents.sh" ] || fail "--docs: sync-agents.sh not executable"
[ -e "$D/workspace/docs" ] && fail "--docs: the template's docs/ put under workspace/"
[ -e "$D/docs" ] && fail "--docs: a docs/ made inside the docs repo"
[ "$(cat "$D/improvements-log.md")" = "# ours" ] || fail "--docs: the clone's own file overwritten"
echo "$out" | grep -q "make -C $D/workspace sync-agents" || fail "--docs: next step does not name workspace/"
make -C "$D/workspace" sync-agents >/dev/null 2>&1 || fail "--docs: make sync-agents fails in workspace/"
grep -q "GENERATED" "$D/workspace/CLAUDE.md" || fail "--docs: workspace/CLAUDE.md not rendered there"

# --- 3. a second run changes nothing; bad arguments are refused ---
echo "sentinel" > "$D/workspace/_canonical.md"
"$ROOT/scripts/ai-workspace.sh" --docs "$D" >/dev/null 2>&1 || fail "second --docs run rc"
[ "$(cat "$D/workspace/_canonical.md")" = "sentinel" ] || fail "second run overwrote _canonical.md"
"$ROOT/scripts/ai-workspace.sh" --docs >/dev/null 2>&1 && fail "--docs without a clone accepted"
"$ROOT/scripts/ai-workspace.sh" --docs "$TMP/missing" >/dev/null 2>&1 && fail "a missing clone accepted"
"$ROOT/scripts/ai-workspace.sh" --nope >/dev/null 2>&1 && fail "an unknown option accepted"

[ -z "$(ls -A "$ELSEWHERE")" ] || fail "a run wrote to the cwd"

if [ "$fails" -ne 0 ]; then
  echo "$fails ai-workspace test(s) failed ✗" >&2
  exit 1
fi
echo "ai-workspace tests passed ✓"
