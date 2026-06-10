#!/usr/bin/env bash
# scripts/test/pre-commit.test.sh
#
# Self-tests for scripts/git-hooks/pre-commit (AC-2 of
# IMP-20260610-mechanize-framework-guardrails). Fixture repo with
# core.hooksPath pointed at the real hook dir; asserts secret rejection,
# stale-stamp rejection, escape hatch, clean pass, and chaining to a
# repo-local hook.
set -euo pipefail

DF="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_DOTFILES="$DF"

fails=0
expect() {
  if [ "$2" -ne "$3" ]; then
    echo "FAIL: $1 (expected rc=$2, got rc=$3)" >&2
    fails=$((fails + 1))
  fi
}

repo="$TMP/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@t
git -C "$repo" config user.name t
git -C "$repo" config core.hooksPath "$DF/scripts/git-hooks"

today="$(date +%F)"

# 1. clean commit passes
echo "hello" > "$repo/a.txt"
git -C "$repo" add a.txt
set +e
git -C "$repo" commit -qm ok >/dev/null 2>&1; rc=$?
set -e
expect "clean commit passes" 0 "$rc"

# 2. planted secret is rejected with location
# Key assembled at runtime — keeps this source file clean for the very
# backstop it tests.
printf 'key = "%s%s"\n' "AKIA" "IOSFODNN7EXAMPLE" > "$repo/leak.txt"
git -C "$repo" add leak.txt
set +e
out="$(git -C "$repo" commit -qm leak 2>&1)"; rc=$?
set -e
expect "secret commit rejected" 1 "$rc"
echo "$out" | grep -q "leak.txt" || { echo "FAIL: secret finding must cite file" >&2; fails=$((fails+1)); }
git -C "$repo" reset -q leak.txt && rm "$repo/leak.txt"

# 3. stale stamp is rejected
printf '# d\n*Last updated: 2020-01-01*\n' > "$repo/doc.md"
git -C "$repo" add doc.md
set +e
out="$(git -C "$repo" commit -qm doc 2>&1)"; rc=$?
set -e
expect "stale stamp rejected" 1 "$rc"
echo "$out" | grep -q "doc.md" || { echo "FAIL: stale stamp must cite file" >&2; fails=$((fails+1)); }

# 4. escape hatch passes the same commit
set +e
SKIP_STAMP_CHECK=1 git -C "$repo" commit -qm doc >/dev/null 2>&1; rc=$?
set -e
expect "SKIP_STAMP_CHECK=1 bypasses stamp check" 0 "$rc"

# 5. fresh stamp passes
printf '# d\n*Last updated: %s*\n' "$today" > "$repo/doc2.md"
git -C "$repo" add doc2.md
set +e
git -C "$repo" commit -qm doc2 >/dev/null 2>&1; rc=$?
set -e
expect "fresh stamp passes" 0 "$rc"

# 6. repo-local hook is chained after our checks
cat > "$repo/.git/hooks/pre-commit" <<'EOF'
#!/bin/sh
echo "local-hook-ran" >&2
exit 1
EOF
chmod +x "$repo/.git/hooks/pre-commit"
echo "more" >> "$repo/a.txt"
git -C "$repo" add a.txt
set +e
out="$(git -C "$repo" commit -qm chain 2>&1)"; rc=$?
set -e
expect "chained local hook controls the outcome" 1 "$rc"
echo "$out" | grep -q "local-hook-ran" || { echo "FAIL: local hook must have run" >&2; fails=$((fails+1)); }

if [ "$fails" -ne 0 ]; then
  echo "$fails pre-commit self-test(s) failed ✗" >&2
  exit 1
fi
echo "scripts/git-hooks/pre-commit self-tests passed ✓"
