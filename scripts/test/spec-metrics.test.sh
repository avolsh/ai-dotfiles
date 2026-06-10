#!/usr/bin/env bash
# scripts/test/spec-metrics.test.sh
#
# Self-tests for scripts/spec-metrics.py (AC-6 of
# IMP-20260610-mechanize-framework-guardrails). Fixture corpus with one
# framework spec, one product spec, and one non-spec artifact; asserts
# classification, monthly grouping, and share arithmetic.
set -euo pipefail

SUT="$(cd "$(dirname "$0")/.." && pwd)/spec-metrics.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

A="$TMP/root/docs/specs/archived"
mkdir -p "$A"

cat > "$A/IMP-20260101-fw.md" <<'EOF'
---
id: IMP-20260101-fw
type: IMP
date: 2026-01-15
status: done
affected-repos:
  - ai-dotfiles
---
EOF

cat > "$A/CR-20260102-prod.md" <<'EOF'
---
id: CR-20260102-prod
type: CR
date: 2026-01-20
status: done
affected-repos:
  - tobevisit-web
---
EOF

cat > "$A/notes.md" <<'EOF'
no front matter — must be ignored
EOF

out="$(python3 "$SUT" "$TMP/root")"

fails=0
assert_contains() {
  if ! echo "$out" | grep -q "$1"; then
    echo "FAIL: expected output to contain '$1'" >&2
    echo "$out" >&2
    fails=$((fails + 1))
  fi
}

# one framework + one product in 2026-01 => 50% share
assert_contains "2026-01"
echo "$out" | grep "2026-01" | grep -q " 1 " || { echo "FAIL: month row must count 1 framework and 1 product" >&2; echo "$out" >&2; fails=$((fails+1)); }
assert_contains "50%"
assert_contains "total"

# empty corpus exits cleanly
out2="$(python3 "$SUT" "$TMP/empty")"
echo "$out2" | grep -q "no archived specs" || { echo "FAIL: empty corpus must be reported" >&2; fails=$((fails+1)); }

if [ "$fails" -ne 0 ]; then
  echo "$fails spec-metrics self-test(s) failed ✗" >&2
  exit 1
fi
echo "scripts/spec-metrics.py self-tests passed ✓"
