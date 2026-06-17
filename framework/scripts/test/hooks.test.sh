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

# Copilot CLI real payload shape: toolArgs is a JSON-encoded string (T7 finding)
sed -i.bak 's/^status: in-progress/status: specify/' "$proj/docs/specs/active/CR-20260101-demo.md" && rm -f "$proj/docs/specs/active/CR-20260101-demo.md.bak"
set +e
out="$(printf '{"sessionId":"cs1","toolName":"edit","toolArgs":"{\\"path\\":\\"%s/src/foo/bar.ts\\"}","cwd":"%s"}' "$proj" "$proj" | "$GUARD" 2>&1)"; rc=$?
set -e
expect "guard denies under Copilot toolArgs payload" 2 "$rc"
echo "$out" | grep -q "CR-20260101-demo" || { echo "FAIL: Copilot-shape deny must name the spec" >&2; fails=$((fails+1)); }
sed -i.bak 's/^status: specify/status: in-progress/' "$proj/docs/specs/active/CR-20260101-demo.md" && rm -f "$proj/docs/specs/active/CR-20260101-demo.md.bak"

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

printf 'openai_key = "%s%s"\n' "sk-" "abcdefghijklmnopqrstuvwxyz123456" > "$repo/openai-leak.txt"
git -C "$repo" add openai-leak.txt
set +e
out="$(cd "$repo" && "$SCAN" 2>&1)"; rc=$?
set -e
expect "scan flags staged OpenAI key" 1 "$rc"
echo "$out" | grep -q "openai-leak.txt" || { echo "FAIL: OpenAI finding must cite the file" >&2; fails=$((fails+1)); }
git -C "$repo" rm -q --cached openai-leak.txt

printf '5. [Task complexity estimation](#ta%s%s)\n' "s" "k-complexity-estimation" > "$repo/clean-anchor.md"
git -C "$repo" add clean-anchor.md
set +e
(cd "$repo" && "$SCAN" >/dev/null 2>&1); rc=$?
set -e
expect "scan allows Markdown task anchor" 0 "$rc"
git -C "$repo" rm -q --cached clean-anchor.md

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

# Command substitutions / variable refs are not hardcoded literals.
printf 'token="$(security find-generic-password -w)"\npassword="$KEYCHAIN_PW"\n' > "$repo/subst.sh"
set +e
"$SCAN" "$repo/subst.sh" >/dev/null 2>&1; rc=$?
set -e
expect "scan ignores command-substitution credential reads" 0 "$rc"

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

# ---------- test-rerun-guard.sh ----------
GUARD2="$HOOKS_DIR/test-rerun-guard.sh"
export AI_HOOKS_STATE_DIR="$TMP/state"
trepo="$TMP/trepo"
mkdir -p "$trepo"
git -C "$trepo" init -q && git -C "$trepo" config user.email t@t && git -C "$trepo" config user.name t
echo "x" > "$trepo/f.txt" && git -C "$trepo" add f.txt && git -C "$trepo" commit -qm i

tpay() { printf '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$trepo"; }

set +e
tpay "make test" | "$GUARD2" 2>/dev/null; rc=$?
set -e
expect "rerun-guard allows first test run" 0 "$rc"

set +e
out="$(tpay "make test" | "$GUARD2" 2>&1)"; rc=$?
set -e
expect "rerun-guard denies identical re-run" 2 "$rc"
echo "$out" | grep -q "FORCE_TEST_RERUN" || { echo "FAIL: deny must name the override" >&2; fails=$((fails+1)); }

echo "y" >> "$trepo/f.txt"
set +e
tpay "make test" | "$GUARD2" 2>/dev/null; rc=$?
set -e
expect "rerun-guard allows after worktree change" 0 "$rc"

set +e
tpay "FORCE_TEST_RERUN=1 make test" | "$GUARD2" 2>/dev/null; rc=$?
set -e
expect "rerun-guard honors FORCE_TEST_RERUN=1" 0 "$rc"

set +e
tpay "ls -la" | "$GUARD2" 2>/dev/null; rc=$?
set -e
expect "rerun-guard ignores non-test commands" 0 "$rc"

set +e
printf '{"session_id":"s1","tool_input":{"command":"make test"},"cwd":"/nonexistent"}' | "$GUARD2" 2>/dev/null; rc=$?
set -e
expect "rerun-guard fails open outside git" 0 "$rc"

# ---------- stop-build-check.sh ----------
SBC="$HOOKS_DIR/stop-build-check.sh"
tr1="$TMP/tr-edit-after-test.jsonl"
cat > "$tr1" <<'EOF'
{"message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"make test"}}]}}
{"message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/p/src/a.go"}}]}}
EOF
set +e
out="$(printf '{"transcript_path":"%s"}' "$tr1" | "$SBC" 2>&1)"; rc=$?
set -e
expect "stop-check exits 0 (advisory)" 0 "$rc"
echo "$out" | grep -q "advisory" || { echo "FAIL: stop-check must advise when edit follows last test" >&2; fails=$((fails+1)); }

tr2="$TMP/tr-test-after-edit.jsonl"
cat > "$tr2" <<'EOF'
{"message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/p/src/a.go"}}]}}
{"message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"make test"}}]}}
EOF
set +e
out="$(printf '{"transcript_path":"%s"}' "$tr2" | "$SBC" 2>&1)"; rc=$?
set -e
expect "stop-check silent when tests ran after edits" 0 "$rc"
[ -z "$out" ] || { echo "FAIL: stop-check must stay silent: $out" >&2; fails=$((fails+1)); }

set +e
printf '{"no":"transcript"}' | "$SBC" >/dev/null 2>&1; rc=$?
set -e
expect "stop-check fails open without transcript" 0 "$rc"

# md-only edits are not code edits
tr3="$TMP/tr-md-only.jsonl"
printf '{"message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/p/docs/a.md"}}]}}\n' > "$tr3"
set +e
out="$(printf '{"transcript_path":"%s"}' "$tr3" | "$SBC" 2>&1)"; rc=$?
set -e
expect "stop-check ignores md-only sessions" 0 "$rc"
[ -z "$out" ] || { echo "FAIL: md-only session must not advise" >&2; fails=$((fails+1)); }

# ---------- preflight-reminder.sh ----------
PFR="$HOOKS_DIR/preflight-reminder.sh"
trn="$TMP/tr-nopreflight.jsonl"
printf '{"message":{"content":[{"type":"text","text":"hello"}]}}\n' > "$trn"

ppay() { printf '{"session_id":"%s","tool_input":{"file_path":"%s"},"transcript_path":"%s"}' "$1" "$2" "$3"; }

set +e
out="$(ppay pf1 /p/src/a.go "$trn" | "$PFR" 2>&1)"; rc=$?
set -e
expect "preflight-reminder advises on first code edit" 0 "$rc"
echo "$out" | grep -q "preflight" || { echo "FAIL: reminder text missing" >&2; fails=$((fails+1)); }

set +e
out="$(ppay pf1 /p/src/b.go "$trn" | "$PFR" 2>&1)"; rc=$?
set -e
expect "preflight-reminder fires once per session" 0 "$rc"
[ -z "$out" ] || { echo "FAIL: second edit must be silent" >&2; fails=$((fails+1)); }

trp="$TMP/tr-preflight.jsonl"
printf '{"message":{"content":[{"type":"text","text":"Preflight proof: Task T5, precedents read"}]}}\n' > "$trp"
set +e
out="$(ppay pf2 /p/src/a.go "$trp" | "$PFR" 2>&1)"; rc=$?
set -e
expect "preflight-reminder silent when proof present" 0 "$rc"
[ -z "$out" ] || { echo "FAIL: must be silent with proof in transcript" >&2; fails=$((fails+1)); }

set +e
out="$(ppay pf3 /p/docs/a.md "$trn" | "$PFR" 2>&1)"; rc=$?
set -e
expect "preflight-reminder ignores md edits" 0 "$rc"
[ -z "$out" ] || { echo "FAIL: md edit must not trigger reminder" >&2; fails=$((fails+1)); }

if [ "$fails" -ne 0 ]; then
  echo "$fails hook self-test(s) failed ✗" >&2
  exit 1
fi
echo "framework/hooks self-tests passed ✓"
