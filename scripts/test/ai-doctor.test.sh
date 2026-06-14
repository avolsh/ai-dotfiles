#!/usr/bin/env bash
# scripts/test/ai-doctor.test.sh
#
# Self-tests for scripts/ai-doctor.sh (AC-3 of
# IMP-20260610-mechanize-framework-guardrails). Builds a fixture dotfiles
# tree + profile in a temp dir, asserts OK on a healthy profile, FAIL with
# the expected target on a deliberately broken symlink, and OK again after
# repair. HOME is overridden so real tool homes are never touched.
set -euo pipefail

SUT="$(cd "$(dirname "$0")/.." && pwd)/ai-doctor.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
expect() { # $1 desc, $2 expected rc, $3 actual rc
  if [ "$2" -ne "$3" ]; then
    echo "FAIL: $1 (expected rc=$2, got rc=$3)" >&2
    fails=$((fails + 1))
  fi
}

# --- fixture dotfiles tree ---
DF="$TMP/dotfiles"
mkdir -p "$DF/framework/spec-workflows" "$DF/framework/prompts" \
         "$DF/framework/templates/system/claude" "$DF/framework/skills" \
         "$DF/framework/agents" "$DF/framework/upstream"
echo "# b" > "$DF/framework/boundaries.md"
echo "# c" > "$DF/framework/templates/system/claude/CLAUDE.md"

P="$DF/profiles/test/claude"
mkdir -p "$P"
ln -s "$DF/framework/templates/system/claude/CLAUDE.md" "$P/CLAUDE.md"
ln -s "$DF/framework/boundaries.md" "$P/boundaries.md"
for ref in spec-workflows prompts templates skills agents upstream; do
  ln -s "$DF/framework/$ref" "$P/$ref"
done

export HOME="$TMP/home"
mkdir -p "$HOME/.claude"

# 1. healthy profile passes
set +e
out="$(AI_DOTFILES="$DF" "$SUT" test 2>&1)"; rc=$?
set -e
expect "healthy profile passes" 0 "$rc"

# 2. broken ref symlink fails and names the expected target
rm "$DF/framework/boundaries.md"   # leaves $P/boundaries.md dangling
set +e
out="$(AI_DOTFILES="$DF" "$SUT" test 2>&1)"; rc=$?
set -e
expect "broken symlink fails" 1 "$rc"
echo "$out" | grep -q "boundaries.md" || { echo "FAIL: broken link must be named" >&2; fails=$((fails+1)); }

# 3. repair restores OK
echo "# b" > "$DF/framework/boundaries.md"
set +e
AI_DOTFILES="$DF" "$SUT" test >/dev/null 2>&1; rc=$?
set -e
expect "repaired profile passes" 0 "$rc"

# 4. fast mode ignores ref links (only instruction + manifest)
rm "$DF/framework/boundaries.md"
set +e
AI_DOTFILES="$DF" "$SUT" --fast test >/dev/null 2>&1; rc=$?
set -e
expect "fast mode skips ref checks" 0 "$rc"
echo "# b" > "$DF/framework/boundaries.md"

# 5. manifest mismatch fails
printf 'profile=other\ntarget=%s\n' "$P/CLAUDE.md" > "$HOME/.claude/.active-manifest"
set +e
out="$(AI_DOTFILES="$DF" "$SUT" test 2>&1)"; rc=$?
set -e
expect "manifest profile mismatch fails" 1 "$rc"

# 6. matching manifest with resolving target passes
printf 'profile=test\ntarget=%s\n' "$P/CLAUDE.md" > "$HOME/.claude/.active-manifest"
set +e
AI_DOTFILES="$DF" "$SUT" test >/dev/null 2>&1; rc=$?
set -e
expect "consistent manifest passes" 0 "$rc"

# 7. missing profile dir fails
set +e
AI_DOTFILES="$DF" "$SUT" nosuch >/dev/null 2>&1; rc=$?
set -e
expect "missing profile dir fails" 1 "$rc"

if [ "$fails" -ne 0 ]; then
  echo "$fails ai-doctor self-test(s) failed ✗" >&2
  exit 1
fi
echo "scripts/ai-doctor.sh self-tests passed ✓"
