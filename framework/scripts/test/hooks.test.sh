#!/usr/bin/env bash
# framework/scripts/test/hooks.test.sh
#
# Self-tests for framework/hooks/{spec-status-guard,secrets-scan,stamp-refresh}.sh.
# Builds fixtures in a temp dir and asserts allow/deny/exit-code behaviour
# (AC-1 groundwork of IMP-20260610-mechanize-framework-guardrails).
set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/../../hooks" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
expect() { # $1 desc, $2 expected rc, $3 actual rc
  if [ "$2" -ne "$3" ]; then
    echo "FAIL: $1 (expected rc=$2, got rc=$3)" >&2
    fails=$((fails + 1))
  fi
}

payload() { # $1 file, $2 cwd
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "$2"
}

# ---------- spec-status-guard.sh ----------
GUARD="$HOOKS_DIR/spec-status-guard.sh"
proj="$TMP/proj"
mkdir -p "$proj/docs/specs/active" "$proj/src/foo"
cat > "$proj/docs/specs/active/CR-20260101-demo.md" <<'EOF'
---
id: CR-20260101-demo
type: CR
status: specify
affected-code:
  - src/foo/ (new)
---
# demo
EOF
echo "x" > "$proj/src/foo/bar.ts"
echo "y" > "$proj/src/other.ts"

set +e
out="$(payload "$proj/src/foo/bar.ts" "$proj" | "$GUARD" 2>&1)"; rc=$?
set -e
expect "guard denies governed code edit at specify" 2 "$rc"
echo "$out" | grep -q "CR-20260101-demo" || { echo "FAIL: deny message must name the spec" >&2; fails=$((fails+1)); }

set +e
payload "$proj/src/other.ts" "$proj" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "guard allows ungoverned code path" 0 "$rc"

set +e
payload "$proj/docs/specs/active/CR-20260101-demo.md" "$proj" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "guard allows editing the spec itself" 0 "$rc"

sed -i.bak 's/^status: specify/status: in-progress/' "$proj/docs/specs/active/CR-20260101-demo.md" && rm -f "$proj/docs/specs/active/CR-20260101-demo.md.bak"
set +e
payload "$proj/src/foo/bar.ts" "$proj" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "guard allows governed edit once in-progress" 0 "$rc"

set +e
printf 'not json' | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "guard fails open on malformed payload" 0 "$rc"

# ---------- secrets-scan.sh ----------
SCAN="$HOOKS_DIR/secrets-scan.sh"
repo="$TMP/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@t && git -C "$repo" config user.name t

# Assemble the planted key at runtime so this source file itself never
# contains a contiguous secret-pattern match (the pre-commit backstop
# scans this repo too).
printf 'aws_key = "%s%s"\n' "AKIA" "IOSFODNN7EXAMPLE" > "$repo/leak.txt"
git -C "$repo" add leak.txt
set +e
out="$(cd "$repo" && "$SCAN" 2>&1)"; rc=$?
set -e
expect "scan flags staged AWS key" 1 "$rc"
echo "$out" | grep -q "leak.txt" || { echo "FAIL: finding must cite the file" >&2; fails=$((fails+1)); }
git -C "$repo" rm -q --cached leak.txt

echo 'SECRET=1' > "$repo/.env"
git -C "$repo" add -f .env
set +e
(cd "$repo" && "$SCAN" >/dev/null 2>&1); rc=$?
set -e
expect "scan blocks staged .env" 1 "$rc"
git -C "$repo" rm -q --cached .env

echo 'API_KEY=put-your-key-here' > "$repo/.env.example"
echo 'plain text, nothing secret' > "$repo/clean.txt"
git -C "$repo" add .env.example clean.txt
set +e
(cd "$repo" && "$SCAN" >/dev/null 2>&1); rc=$?
set -e
expect "scan passes clean staged tree (.env.example allowed)" 0 "$rc"

set +e
"$SCAN" "$repo/leak.txt" >/dev/null 2>&1; rc=$?
set -e
expect "scan flags explicit file argument" 1 "$rc"

# ---------- stamp-refresh.sh ----------
STAMP="$HOOKS_DIR/stamp-refresh.sh"
today="$(date +%F)"
doc="$TMP/doc.md"
printf '# t\n*Last updated: 2020-01-01*\nbody\n' > "$doc"
payload "$doc" "$TMP" | "$STAMP"
grep -q "\*Last updated: $today\*" "$doc" || { echo "FAIL: stamp not refreshed" >&2; fails=$((fails+1)); }

nostamp="$TMP/nostamp.md"
printf '# t\nbody\n' > "$nostamp"
cp "$nostamp" "$nostamp.orig"
payload "$nostamp" "$TMP" | "$STAMP"
cmp -s "$nostamp" "$nostamp.orig" || { echo "FAIL: file without stamp must be untouched" >&2; fails=$((fails+1)); }

mkdir -p "$TMP/docs/specs/archived"
arch="$TMP/docs/specs/archived/old.md"
printf '# t\n*Last updated: 2020-01-01*\n' > "$arch"
payload "$arch" "$TMP" | "$STAMP"
grep -q '2020-01-01' "$arch" || { echo "FAIL: archived stamp must be preserved" >&2; fails=$((fails+1)); }

if [ "$fails" -ne 0 ]; then
  echo "$fails hook self-test(s) failed ✗" >&2
  exit 1
fi
echo "framework/hooks self-tests passed ✓"
