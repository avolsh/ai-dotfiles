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


# --- IMP-20260826 T1: collect-then-decide (FR-1, FR-2, FR-4) ---
# Fixture helper: a minimal active spec leasing one path.
mkspec() { # $1 root, $2 filename, $3 status, $4 date, $5 path, [$6 depends-on spec id]
  local f="$1/docs/specs/active/$2"
  {
    echo "---"
    echo "id: ${2%.md}"
    echo "type: IMP"
    echo "date: $4"
    echo "status: $3"
    [ -n "${6:-}" ] && { echo "depends-on:"; echo "  - $6"; }
    echo "affected-code:"
    echo "  - $5"
    echo "---"
    echo "# ${2%.md}"
  } > "$f"
}

# AC-2 — a governing in-progress spec admits the edit even though an earlier
# spec at `plan` leases the same path (the guard must not exit on first match).
p2="$TMP/ac2"
mkdir -p "$p2/docs/specs/active" "$p2/src"
echo "x" > "$p2/src/x.ts"
mkspec "$p2" "IMP-20260805-blocker.md"   plan        2026-08-05 src/x.ts
mkspec "$p2" "IMP-20260806-governing.md" in-progress 2026-08-06 src/x.ts
set +e
payload "$p2/src/x.ts" "$p2" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "AC-2 guard allows when an in-progress spec governs the path" 0 "$rc"

# AC-3 — a genuine collision still denies, naming the earliest blocker by date
# and stating both allow conditions.
p3="$TMP/ac3"
mkdir -p "$p3/docs/specs/active" "$p3/src"
echo "x" > "$p3/src/x.ts"
mkspec "$p3" "IMP-20260801-early.md" specify 2026-08-01 src/x.ts
mkspec "$p3" "IMP-20260810-late.md"  specify 2026-08-10 src/x.ts
set +e
out="$(payload "$p3/src/x.ts" "$p3" | "$GUARD" 2>&1)"; rc=$?
set -e
expect "AC-3 guard denies a genuine collision" 2 "$rc"
echo "$out" | grep -q "IMP-20260801-early" || { echo "FAIL: AC-3 denial must name the earliest blocker" >&2; fails=$((fails+1)); }
echo "$out" | grep -q "in-progress" || { echo "FAIL: AC-3 denial must state the in-progress allow condition" >&2; fails=$((fails+1)); }
echo "$out" | grep -q "depends-on" || { echo "FAIL: AC-3 denial must state the depends-on allow condition" >&2; fails=$((fails+1)); }

# FR-4 — "earliest" is read from `date:`, not from the filename glob order.
# Re-dating the alphabetically-first spec past the other must move the blame.
sed -i.bak 's/^date: 2026-08-01/date: 2026-08-20/' "$p3/docs/specs/active/IMP-20260801-early.md" && rm -f "$p3/docs/specs/active/IMP-20260801-early.md.bak"
set +e
out="$(payload "$p3/src/x.ts" "$p3" | "$GUARD" 2>&1)"; rc=$?
set -e
expect "FR-4 guard still denies after re-dating" 2 "$rc"
echo "$out" | grep -q "IMP-20260810-late" || { echo "FAIL: FR-4 earliest blocker must come from date:, not glob order" >&2; fails=$((fails+1)); }

# --- IMP-20260826 T2: depends-on is not a claim (FR-3) ---
# AC-1 — spec B at `specify` leases the path and its depends-on names spec A,
# which is active at `in-progress` and does NOT lease the path. Rule #10 keeps
# B at `specify` until A is done, so B cannot hold a lease against A.
p1="$TMP/ac1"
mkdir -p "$p1/docs/specs/active" "$p1/src"
echo "x" > "$p1/src/x.ts"
mkspec "$p1" "BUG-20260901-spec-a.md" in-progress 2026-09-01 src/unrelated.ts
mkspec "$p1" "IMP-20260902-spec-b.md" specify     2026-09-02 src/x.ts BUG-20260901-spec-a
set +e
payload "$p1/src/x.ts" "$p1" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "AC-1 guard ignores a blocker whose depends-on names an in-progress spec" 0 "$rc"

# FR-3 is not a blanket pass: the same blocker denies when the spec it depends
# on is not active at in-progress.
sed -i.bak 's/^status: in-progress/status: specify/' "$p1/docs/specs/active/BUG-20260901-spec-a.md" && rm -f "$p1/docs/specs/active/BUG-20260901-spec-a.md.bak"
set +e
payload "$p1/src/x.ts" "$p1" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "FR-3 depends-on on a non-in-progress spec still denies" 2 "$rc"

# --- Replay of the eight logged collisions (tobevisit-content improvements-log,
# 2026-08-13 x3 covering four occurrences, 2026-08-14 x4). Seven are false
# positives the two allow conditions clear; the eighth is recorded as a genuine
# sequencing conflict "the two proposed hook rules would not fix" and must deny.
replay() { # $1 label, $2 edited path, $3 expected rc; specs on stdin as "file|status|date|path[|depends-on]"
  local d="$TMP/replay-$1" line
  mkdir -p "$d/docs/specs/active" "$d/src"
  while IFS='|' read -r f s dt pth dep; do
    [ -n "$f" ] || continue
    mkspec "$d" "$f" "$s" "$dt" "$pth" "${dep:-}"
  done
  mkdir -p "$d/$(dirname "$2")"; echo "x" > "$d/$2"
  set +e
  payload "$d/$2" "$d" | "$GUARD" 2>/dev/null; local rc=$?
  set -e
  expect "replay $1" "$3" "$rc"
}

# O1-O4 — an in-progress spec governs the path; specify-stage inventories block it.
replay o1 src/load-places.use-case.ts 0 <<'EOF'
BUG-20260813-google-error.md|in-progress|2026-08-13|src/load-places.use-case.ts
IMP-20260813-google-ingest-a.md|specify|2026-08-13|src/load-places.use-case.ts
IMP-20260813-google-ingest-b.md|specify|2026-08-13|src/load-places.use-case.ts
EOF
replay o2 src/init-content.use-case.ts 0 <<'EOF'
BUG-20260813-init-content.md|in-progress|2026-08-13|src/init-content.use-case.ts
IMP-20260813-configuration-store-safety.md|specify|2026-08-13|src/init-content.use-case.ts
IMP-20260813-layered-configuration.md|specify|2026-08-13|src/init-content.use-case.ts
EOF
replay o3 src/mongo-catalog-place-repository.ts 0 <<'EOF'
IMP-20260813-catalog-work.md|in-progress|2026-08-13|src/mongo-catalog-place-repository.ts
BUG-20260813-media-failure-as-empty-gallery.md|specify|2026-08-13|src/mongo-catalog-place-repository.ts
IMP-20260813-media-pipeline-state-machine.md|specify|2026-08-13|src/mongo-catalog-place-repository.ts
IMP-20260813-mongo-schema-indexes.md|specify|2026-08-13|src/mongo-catalog-place-repository.ts
EOF
replay o4 src/collect-catalog-garbage.use-case.ts 0 <<'EOF'
IMP-20260813-catalog-work.md|in-progress|2026-08-13|src/collect-catalog-garbage.use-case.ts
BUG-20260813-r2-partial-delete-ignored.md|specify|2026-08-13|src/collect-catalog-garbage.use-case.ts
EOF

# O5-O7 — the three depends-on deadlocks: the blocker declares it cannot start
# without the very spec it blocks, and does not lease the path itself.
replay o5 src/google-places-adapter.ts 0 <<'EOF'
BUG-20260813-google-error-checkpointed-as-success.md|in-progress|2026-08-13|src/other.ts
IMP-20260813-google-places-adapter-hardening.md|specify|2026-08-13|src/google-places-adapter.ts|BUG-20260813-google-error-checkpointed-as-success
EOF
replay o6 src/catalog-place-media.ts 0 <<'EOF'
BUG-20260813-media-failure-as-empty-gallery.md|in-progress|2026-08-13|src/other.ts
IMP-20260813-media-pipeline-state-machine.md|specify|2026-08-13|src/catalog-place-media.ts|BUG-20260813-media-failure-as-empty-gallery
EOF
replay o7 src/r2-storage-adapter.ts 0 <<'EOF'
BUG-20260813-r2-partial-delete-ignored.md|in-progress|2026-08-13|src/other.ts
IMP-20260813-media-pipeline-state-machine.md|specify|2026-08-13|src/r2-storage-adapter.ts|BUG-20260813-r2-partial-delete-ignored
EOF

# O8 — genuine sequencing conflict: the blocker really will rewrite config.ts,
# no depends-on relates them, and no in-progress spec governs it. Still denies.
replay o8 src/config.ts 2 <<'EOF'
IMP-20260813-layered-configuration.md|specify|2026-08-13|src/config.ts
EOF

# --- IMP-20260929: a workspace spec tree enclosing a project one (FR-1, FR-2, FR-3) ---
# The shape that found the gap: a cross-repo spec lives in the workspace root's tree and leases the
# path as that tree spells it (`repo/<path>`), while the repository owns a tree of its own whose
# specify-stage specs lease the same files under their repo-relative names.
ws="$TMP/ws"
mkdir -p "$ws/docs/specs/active" "$ws/repo/docs/specs/active" "$ws/repo/src"
echo "x" > "$ws/repo/src/app.ts"
mkspec "$ws/repo" "CR-20260901-repo-plan.md" specify 2026-09-01 "src"

# AC-1 — the governing spec sits in the enclosing tree, at in-progress, leasing the workspace-relative
# path. Before this change the guard never read that tree and denied the edit.
mkspec "$ws" "CR-20260929-cross-repo.md" in-progress 2026-09-29 "repo/src"
set +e
payload "$ws/repo/src/app.ts" "$ws/repo" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "guard allows an edit governed from the enclosing workspace tree" 0 "$rc"

# AC-2 — the same shape with nothing at in-progress: a genuine conflict, and the message must say
# which tree the blamed spec came from, since two trees can hold blockers.
sed -i.bak 's/^status: in-progress/status: specify/' "$ws/docs/specs/active/CR-20260929-cross-repo.md"
rm -f "$ws/docs/specs/active/CR-20260929-cross-repo.md.bak"
set +e
out="$(payload "$ws/repo/src/app.ts" "$ws/repo" | "$GUARD" 2>&1)"; rc=$?
set -e
expect "guard denies when no tree has a governing spec" 2 "$rc"
echo "$out" | grep -q "CR-20260901-repo-plan" \
  || { echo "FAIL: nested deny must blame the earliest spec by date" >&2; fails=$((fails+1)); }
echo "$out" | grep -q "spec tree: $ws/repo/docs/specs/active" \
  || { echo "FAIL: nested deny must name the blocker's spec tree" >&2; fails=$((fails+1)); }

# FR-3 — depends-on reaches across trees: the project blocker declares it cannot start without the
# cross-repo spec, which is active at in-progress in the enclosing tree and leases nothing here.
mkspec "$ws" "CR-20260929-cross-repo.md" in-progress 2026-09-29 "repo/elsewhere"
mkspec "$ws/repo" "CR-20260901-repo-plan.md" specify 2026-09-01 "src" "CR-20260929-cross-repo"
set +e
payload "$ws/repo/src/app.ts" "$ws/repo" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "guard clears a project blocker waiting on a workspace spec" 0 "$rc"

# FR-5 — the enclosing tree only ever adds specs; a path no spec leases stays allowed.
echo "z" > "$ws/repo/README.other"
set +e
payload "$ws/repo/README.other" "$ws/repo" | "$GUARD" 2>/dev/null; rc=$?
set -e
expect "guard allows an ungoverned path under a nested workspace" 0 "$rc"

# ---------- bash-write-guard.sh ----------
# IMP-20260929-guarded-writes-through-bash. The suite replays the ten commands on record — the two shell
# writes of 2026-09-29 and the eight git verbs of 2026-09-28 — against the read-only commands the same
# sessions ran, because a guard that denied those would be switched off within a day.
BWG="$HOOKS_DIR/bash-write-guard.sh"
bwg="$TMP/bwg"
mkdir -p "$bwg/docs/specs/active" "$bwg/src/foo" "$bwg/docs"
mkspec "$bwg" "CR-20260101-leased.md" specify 2026-01-01 "src/foo"

cmd_payload() { # $1 command, $2 cwd
  printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' \
    "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" "$2"
}

bwg_expect() { # $1 expected rc, $2 command
  set +e
  cmd_payload "$2" "$bwg" | "$BWG" >/dev/null 2>&1
  local rc=$?
  set -e
  expect "bash-write-guard: $2" "$1" "$rc"
}

# AC-1 — the two doors agree. Each verb writes a leased path that no in-progress spec governs.
bwg_expect 2 "cp /tmp/x src/foo/b"
bwg_expect 2 "sed -i '' s/x/y/ src/foo/b"
bwg_expect 2 "echo x > src/foo/b"
bwg_expect 2 "cat >> src/foo/b"
bwg_expect 2 "rm src/foo/b"
bwg_expect 2 "mkdir -p src/foo/deeper"
bwg_expect 2 "touch src/foo/b"
bwg_expect 2 "mv /tmp/x src/foo/b"
bwg_expect 2 "tee src/foo/b"
# A write is a write wherever it sits in a compound command.
bwg_expect 2 "npm test && cp /tmp/x src/foo/b"

# AC-1 — an unleased path, and the docs / Markdown exemptions the file tools have.
bwg_expect 0 "echo x > src/other.ts"
bwg_expect 0 "cp /tmp/x src/other.ts"
bwg_expect 0 "echo x > docs/note.md"
bwg_expect 0 "echo x > docs/specs/active/CR-20260101-leased.md"

# AC-1 — the denial names the verb, the path and the spec.
set +e
bwg_out="$(cmd_payload "cp /tmp/x src/foo/b" "$bwg" | "$BWG" 2>&1 >/dev/null)"
set -e
echo "$bwg_out" | grep -q "cp" || { echo "FAIL: bash deny must name the verb" >&2; fails=$((fails+1)); }
echo "$bwg_out" | grep -q "src/foo/b" || { echo "FAIL: bash deny must name the path" >&2; fails=$((fails+1)); }
echo "$bwg_out" | grep -q "CR-20260101-leased" || { echo "FAIL: bash deny must name the spec" >&2; fails=$((fails+1)); }

# AC-2 — the eight recorded git verbs, alone and inside a compound command.
for verb in "checkout -b feat origin/develop" "checkout -B feat" "rm x" "restore --staged _cms" \
            "stash" "stash pop" "merge --ff-only develop" "fetch"; do
  bwg_expect 2 "git $verb"
  bwg_expect 2 "cd /tmp && git $verb"
done

# AC-2 — the reading commands the same sessions ran stay unrestricted.
for verb in "status" "log --oneline -3" "diff" "show HEAD:package.json" "branch --show-current" "branch" \
            "stash list" "config --get user.name" "remote -v" "rev-parse HEAD"; do
  bwg_expect 0 "git $verb"
done

# AC-3 — unreadable commands are allowed, on purpose (FR-4).
bwg_expect 0 "echo x > \$TARGET/src/foo/b"
bwg_expect 0 "cp /tmp/x \"\$(dirname src/foo/b)\""
bwg_expect 0 "bash -c 'rm src/foo/b'"
bwg_expect 0 "python3 scripts/write.py"
bwg_expect 0 "find . -name x -exec rm {} ;"
bwg_expect 0 "cp /tmp/x src/foo/*.ts"
set +e
printf 'not json' | "$BWG" >/dev/null 2>&1; rc=$?
set -e
expect "bash-write-guard fails open on a malformed payload" 0 "$rc"
set +e
printf '{"tool_name":"Bash","tool_input":{}}' | "$BWG" >/dev/null 2>&1; rc=$?
set -e
expect "bash-write-guard fails open when there is no command" 0 "$rc"

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
