#!/usr/bin/env bash
# scripts/test/check-md-links.test.sh
#
# Self-test for scripts/check-md-links.sh. Builds a tiny fixture in a
# temp dir with one valid and one broken link, runs the script in
# custom-scope mode against the fixture, and asserts:
#
#   1. Exit code is 1 (broken link detected).
#   2. The broken target appears in stderr output.
#   3. The valid target does NOT appear in stderr output.
#
# Then runs the script against a tree with only valid links and asserts
# exit 0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUT="$SCRIPT_DIR/check-md-links.sh"

if [[ ! -x "$SUT" ]]; then
  chmod +x "$SUT" 2>/dev/null || true
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Negative fixture: one valid, one broken link ---
mkdir -p "$TMP/neg/sub"
cat > "$TMP/neg/target.md" <<'EOF'
# target
EOF
cat > "$TMP/neg/sub/source.md" <<'EOF'
# source

[ok](../target.md)
[bad](../missing-target.md)
[absolute is ignored](https://example.com)
[anchor only is ignored](#section)
EOF

set +e
out="$("$SUT" "$TMP/neg/sub/source.md" 2>&1)"
rc=$?
set -e

if [[ $rc -ne 1 ]]; then
  echo "FAIL: expected exit 1 for broken-link fixture, got $rc" >&2
  echo "$out" >&2
  exit 1
fi

if ! echo "$out" | grep -q 'missing-target.md'; then
  echo "FAIL: expected 'missing-target.md' in output" >&2
  echo "$out" >&2
  exit 1
fi

# Valid target must not be flagged as broken
if echo "$out" | grep -q '\-> \.\./target\.md'; then
  echo "FAIL: valid link wrongly reported as broken" >&2
  echo "$out" >&2
  exit 1
fi

# --- Positive fixture: only valid links ---
mkdir -p "$TMP/pos/sub"
cat > "$TMP/pos/target.md" <<'EOF'
# target
EOF
cat > "$TMP/pos/sub/source.md" <<'EOF'
# source

[ok](../target.md)
[external is ignored](https://example.com)
EOF

set +e
out2="$("$SUT" "$TMP/pos/sub/source.md" 2>&1)"
rc2=$?
set -e

if [[ $rc2 -ne 0 ]]; then
  echo "FAIL: expected exit 0 for clean fixture, got $rc2" >&2
  echo "$out2" >&2
  exit 1
fi

echo "scripts/check-md-links.sh self-tests passed ✓"

