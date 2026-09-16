#!/usr/bin/env bash
# scripts/test/spec-status.test.sh
#
# Self-tests for scripts/spec-status.py (IMP-20260914-machine-readable-spec-reports
# AC-2, AC-3). Builds a throwaway corpus — an in-progress spec at 3 of 5 tasks, a
# specify spec with one met and one unmet `depends-on:`, a done spec in archived/ —
# and asserts what the command reports and that it writes nothing.
set -euo pipefail

SUT="$(cd "$(dirname "$0")/.." && pwd)/spec-status.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }
json_ok() { # $1 desc, $2 json, $3 python expression over `d` that must be True
  if ! printf '%s' "$2" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if ($3) else 1)" 2>/dev/null; then
    fail "$1 (JSON check failed: $3)"
  fi
}

P="$TMP/proj"
mkdir -p "$P/docs/specs/active" "$P/docs/specs/archived"

cat > "$P/docs/specs/archived/IMP-20260801-foundation.md" <<'EOF'
---
id: IMP-20260801-foundation
type: IMP
date: 2026-08-01
status: done
owner: alex
risk: low
---
# IMP-20260801-foundation
*Last updated: 2026-08-10*
EOF

# Every Status spelling the corpus uses: glyph or none, any case, trailing note
# or date. Descoped and cancelled rows leave the total; an escaped pipe in a
# description must not shift the Status column.
cat > "$P/docs/specs/active/CR-20260901-progress.md" <<'EOF'
---
id: CR-20260901-progress
type: CR
date: 2026-09-01
status: in-progress
owner: sam
risk: medium
---
# CR-20260901-progress
*Last updated: 2026-09-10*

## Tasks

> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | first, `severity: high \| critical` | `a` | — | — | — | default | ☑ done |
| T2 | second | `b` | — | T1 | — | default | ✅ done (2026-09-05) |
| T3 | third | `c` | — | T2 | — | default | Done — reproduced first |
| T4 | fourth | `d` | — | T3 | — | default | ☐ pending |
| T5 | fifth | `e` | — | T4 | — | default | in progress |
| T6 | sixth | `f` | — | — | — | default | ⊘ descoped |
| T7 | seventh | `g` | — | — | — | default | ☒ cancelled |

## Closure Evidence

| AC | Evidence | Status |
|---|---|---|
| AC-1 | a table in another section is not a task table | done |
EOF

cat > "$P/docs/specs/active/BUG-20260905-blocked.md" <<'EOF'
---
id: BUG-20260905-blocked
type: BUG
date: 2026-09-05
status: specify
owner: kim
severity: high
depends-on:
  - IMP-20260801-foundation
  - CR-20260901-progress
---
# BUG-20260905-blocked

## Tasks

Pending — Plan stage only.
EOF

snapshot() { (cd "$P" && find . -print | LC_ALL=C sort && find . -type f -exec shasum {} + | LC_ALL=C sort); }
before="$(snapshot)"

# ---------- AC-2: status reads the corpus (FR-3, FR-5) ----------
set +e
out="$(python3 "$SUT" --json --today 2026-09-16 "$P" 2>"$TMP/stderr")"; rc=$?
set -e
[ "$rc" -eq 0 ] || fail "AC-2 --json exits 0 (got $rc: $(cat "$TMP/stderr"))"
[ -s "$TMP/stderr" ] && fail "AC-2 --json leaves stderr empty (got: $(cat "$TMP/stderr"))"
json_ok "AC-2 lists active specs only, specify before in-progress" "$out" \
  "d['schemaVersion'] == 1 and d['today'] == '2026-09-16' and [s['id'] for s in d['specs']] == ['BUG-20260905-blocked', 'CR-20260901-progress']"
json_ok "AC-2 counts the in-progress spec at 3 of 5" "$out" \
  "d['specs'][1]['tasks'] == {'done': 3, 'total': 5, 'excluded': 2}"
json_ok "AC-2 reports only the unmet depends-on ID" "$out" \
  "d['specs'][0]['unmetDependsOn'] == ['CR-20260901-progress'] and d['specs'][1]['unmetDependsOn'] == []"
json_ok "AC-2 a prose-only Tasks section has no task counts" "$out" "d['specs'][0]['tasks'] is None"
json_ok "AC-2 carries type, status, tier and owner" "$out" \
  "d['specs'][0]['type'] == 'BUG' and d['specs'][0]['status'] == 'specify' and d['specs'][0]['severity'] == 'high' and d['specs'][0]['risk'] is None and d['specs'][0]['owner'] == 'kim' and d['specs'][1]['risk'] == 'medium'"
json_ok "AC-2 ages the Last updated stamp against --today" "$out" \
  "d['specs'][1]['lastUpdated'] == '2026-09-10' and d['specs'][1]['ageDays'] == 6 and d['specs'][0]['lastUpdated'] is None and d['specs'][0]['ageDays'] is None"
json_ok "AC-2 paths are relative to the project root" "$out" \
  "d['specs'][1]['path'] == 'docs/specs/active/CR-20260901-progress.md'"

# The text form carries the same facts.
text="$(python3 "$SUT" --today 2026-09-16 "$P")"
printf '%s\n' "$text" | grep -q 'CR-20260901-progress.*3/5' || fail "AC-2 text shows 3/5 (got: $text)"
printf '%s\n' "$text" | grep -q 'BUG-20260905-blocked.*CR-20260901-progress' || fail "AC-2 text shows the unmet ID (got: $text)"

[ "$(snapshot)" = "$before" ] || fail "AC-2 FR-5 the fixture tree is byte-identical afterwards"
[ -e "$(dirname "$SUT")/__pycache__" ] && fail "AC-2 FR-5 no bytecode cache is written beside the scripts"

# A path inside the project walks up to its root, as validate-specs does; with no
# path the command reports on this repository's own corpus.
python3 "$SUT" --json "$P/docs/specs" | grep -q '"CR-20260901-progress"' \
  || fail "AC-2 FR-5 a path inside the project resolves its root"
python3 "$SUT" --json | python3 -c 'import json,sys; json.load(sys.stdin)' \
  || fail "AC-2 the real corpus produces valid JSON"

# ---------- AC-3: the dashboard groups by status (FR-4) ----------
# `make specs-view` is the surface under test; `--today` is pinned through TODAY so
# the ages in the snapshot do not drift with the calendar.
MAKEFILE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
expected="$(cat <<'SNAP'
specify (1, 1 blocked)
  FLAG     ID                    TYPE  TIER           OWNER  TASKS  AGE  BLOCKED ON
  BLOCKED  BUG-20260905-blocked  BUG   severity:high  kim    —      —    CR-20260901-progress

in-progress (1)
  FLAG  ID                    TYPE  TIER         OWNER  TASKS  AGE  BLOCKED ON
        CR-20260901-progress  CR    risk:medium  sam    3/5    6d   —

2 active spec(s); 1 blocked.
SNAP
)"
set +e
view="$(make --no-print-directory -s -C "$MAKEFILE_DIR" specs-view PROJECT="$P" TODAY=2026-09-16 2>"$TMP/stderr")"; rc=$?
set -e
[ "$rc" -eq 0 ] || fail "AC-3 make specs-view exits 0 (got $rc: $(cat "$TMP/stderr"))"
if [ "$view" != "$expected" ]; then
  fail "AC-3 make specs-view matches the snapshot"
  diff <(printf '%s\n' "$expected") <(printf '%s\n' "$view") >&2 || true
fi
[ "$(snapshot)" = "$before" ] || fail "AC-3 FR-5 the fixture tree is byte-identical after the view"

if [ "$fails" -eq 0 ]; then
  echo "scripts/spec-status.py self-tests passed ✓"
else
  echo "$fails spec-status self-test(s) failed ✗" >&2
  exit 1
fi
