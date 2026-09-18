#!/usr/bin/env bash
# scripts/test/consolidation-due.test.sh
#
# Self-tests for scripts/consolidation-due.py (IMP-20260914-consolidation-checkpoint
# AC-1 – AC-5). Builds throwaway projects — a module map of two contexts, archived
# specs closed against them, a consolidation log — and asserts which contexts are
# due, what a recommendation gathers, and that the command writes nothing.
set -euo pipefail

SUT="$(cd "$(dirname "$0")/.." && pwd)/consolidation-due.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }
json_ok() { # $1 desc, $2 json, $3 python expression over `d` that must be True
  if ! printf '%s' "$2" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if ($3) else 1)" 2>/dev/null; then
    fail "$1 (JSON check failed: $3)"
  fi
}
# ctx <json> <name> <python expression over `c`, the context record>
ctx_ok() {
  json_ok "$1" "$2" "(lambda c: c is not None and ($4))(next((c for c in d['contexts'] if c['context'] == '$3'), None))"
}

new_project() { # $1 dir
  mkdir -p "$1/docs/specs/active" "$1/docs/specs/archived" "$1/docs/architecture"
  cat > "$1/docs/architecture/module-map.md" <<'EOF'
# Module Map

## Bounded Contexts

| Context       | Directory             | Purpose | Key files | Depends on |
| ------------- | --------------------- | ------- | --------- | ---------- |
| **Alpha**     | `src/contexts/alpha/` | a       | —         | —          |
| **Beta**      | `src/contexts/beta/`  | b       | —         | Alpha      |

## Cross-Cutting Files

| File                    | Purpose | Touched by |
| ----------------------- | ------- | ---------- |
| `src/composition-root.ts` | wiring | any       |
EOF
}

# spec <dir> <id> <closed> <risk> <affected-code path>... ; body read from stdin if not a tty
spec() {
  local dir="$1" id="$2" closed="$3" risk="$4"; shift 4
  {
    printf -- '---\nid: %s\ntype: IMP\ndate: %s\nstatus: done\nclosed: %s\nowner: alex\nrisk: %s\naffected-code:\n' \
      "$id" "$closed" "$closed" "$risk"
    for p in "$@"; do printf '  - %s\n' "$p"; done
    printf -- '---\n# %s\n\n*Last updated: %s*\n' "$id" "$closed"
    [ -t 0 ] || cat
  } > "$dir/docs/specs/archived/$id.md"
}

# ---------- AC-1: counter and triggers (FR-1, FR-2) ----------
P="$TMP/p1"
new_project "$P"
cat > "$P/docs/consolidation-log.md" <<'EOF'
---
since: 2026-09-01
---
# Consolidation Log
EOF
for i in 1 2 3 4 5; do spec "$P" "IMP-2026091$i-alpha-$i" "2026-09-1$i" medium "src/contexts/alpha/file-$i.ts (new)" </dev/null; done
spec "$P" "IMP-20260912-beta-1" 2026-09-12 low 'src/contexts/beta/b.ts' </dev/null
spec "$P" "IMP-20260913-beta-2" 2026-09-13 low '`src/contexts/beta/c.ts` *(new)*' </dev/null
# Before `since:` — never counted.
spec "$P" "IMP-20260820-alpha-old" 2026-08-20 low 'src/contexts/alpha/old.ts' </dev/null
# Unmapped path — reported as unknown (OS-3).
spec "$P" "IMP-20260912-wiring" 2026-09-12 low 'src/composition-root.ts' </dev/null

snapshot() { (cd "$1" && find . -print | LC_ALL=C sort && find . -type f -exec shasum {} + | LC_ALL=C sort); }
before="$(snapshot "$P")"

set +e
out="$(python3 "$SUT" --json "$P" 2>"$TMP/stderr")"; rc=$?
set -e
[ "$rc" -eq 0 ] || fail "AC-1 --json exits 0 (got $rc: $(cat "$TMP/stderr"))"
json_ok "AC-1 default threshold is 5 and since is read" "$out" "d['threshold'] == 5 and d['since'] == '2026-09-01'"
ctx_ok "AC-1 Alpha is due at 5/5" "$out" Alpha "c['count'] == 5 and c['due'] and c['triggers'] == ['count 5/5']"
ctx_ok "AC-1 Alpha counts only closures after since" "$out" Alpha "'IMP-20260820-alpha-old' not in c['closures']"
ctx_ok "AC-1 Beta is not due at 2/5, backticks and (new) markers stripped" "$out" Beta "c['count'] == 2 and not c['due'] and c['triggers'] == []"
ctx_ok "AC-1 OS-3 an unmapped path counts under unknown" "$out" unknown "c['count'] == 1 and c['closures'] == ['IMP-20260912-wiring']"

spec "$P" "IMP-20260914-beta-risky" 2026-09-14 high 'src/contexts/beta/d.ts' </dev/null
out="$(python3 "$SUT" --json "$P")"
ctx_ok "AC-1 a risk: high closure makes Beta due" "$out" Beta "c['due'] and c['count'] == 3 and c['triggers'] == ['large IMP-20260914-beta-risky (risk: high)']"

# More than 15 affected-code entries, and more than 8 tasks, are large too.
paths=(); for i in $(seq 1 16); do paths+=("src/contexts/beta/many-$i.ts"); done
P2="$TMP/p1b"; new_project "$P2"
spec "$P2" "IMP-20260920-wide" 2026-09-20 low "${paths[@]}" </dev/null
{
  printf '\n## Tasks\n\n| # | Description | Status |\n|---|---|---|\n'
  for i in $(seq 1 9); do printf '| T%s | t | ☑ done |\n' "$i"; done
} | spec "$P2" "IMP-20260920-long" 2026-09-20 low 'src/contexts/alpha/x.ts'
out="$(python3 "$SUT" --json "$P2")"
ctx_ok "AC-1 >15 affected-code entries is large" "$out" Beta "c['due'] and c['triggers'] == ['large IMP-20260920-wide (16 affected-code entries)']"
ctx_ok "AC-1 >8 tasks is large" "$out" Alpha "c['due'] and c['triggers'] == ['large IMP-20260920-long (9 tasks)']"

text="$(python3 "$SUT" "$P")"
printf '%s\n' "$text" | grep -Eq '^Alpha +5/5 +due' || fail "AC-1 text shows Alpha 5/5 due (got: $text)"
printf '%s\n' "$text" | grep -Eq '^Beta +3/5 +due' || fail "AC-1 text shows Beta 3/5 due (got: $text)"

only="$(python3 "$SUT" --json --closed IMP-20260914-beta-risky "$P")"
json_ok "AC-1 --closed limits the report to that spec's contexts" "$only" "[c['context'] for c in d['contexts']] == ['Beta']"


# ---------- AC-3: a decision resets the counter (FR-5, FR-6) ----------
cat >> "$P/docs/consolidation-log.md" <<'EOF'

### 2026-09-15 — Alpha

- **Outcome:** declined — the five changes touched unrelated files
- **Trigger:** count 5/5
- **After:** IMP-20260915-alpha-5
EOF
before="$(snapshot "$P")"
out="$(python3 "$SUT" --json "$P")"
ctx_ok "AC-3 declined outcome resets Alpha to 0" "$out" Alpha "c['count'] == 0 and not c['due']"
ctx_ok "AC-3 the reason is retrievable" "$out" Alpha \
  "c['lastOutcome'] == {'date': '2026-09-15', 'outcome': 'declined', 'imp': None, 'reason': 'the five changes touched unrelated files'}"
ctx_ok "AC-3 Beta keeps its own counter" "$out" Beta "c['count'] == 3"
text="$(python3 "$SUT" "$P")"
printf '%s\n' "$text" | grep -q 'declined 2026-09-15 — the five changes touched unrelated files' \
  || fail "AC-3 text shows the last outcome and reason (got: $text)"
[ "$(snapshot "$P")" = "$before" ] || fail "AC-3 the command writes nothing"
[ -e "$(dirname "$SUT")/__pycache__" ] && fail "AC-3 no bytecode cache is written beside the scripts"

# ---------- AC-5: threshold override and the refactor IMP itself (FR-9, FR-10) ----------
P="$TMP/p5"
new_project "$P"
cat > "$P/docs/consolidation-log.md" <<'EOF'
---
threshold: 3
since: 2026-08-31
---
# Consolidation Log
EOF
for i in 1 2 3; do spec "$P" "IMP-2026090$i-a-$i" "2026-09-0$i" low "src/contexts/alpha/f$i.ts" </dev/null; done
out="$(python3 "$SUT" --json "$P")"
ctx_ok "AC-5 threshold: 3 makes Alpha due at 3/3" "$out" Alpha "c['count'] == 3 and c['threshold'] == 3 and c['due']"

cat >> "$P/docs/consolidation-log.md" <<'EOF'

### 2026-09-04 — Alpha

- **Outcome:** accepted — IMP-20260905-refactor-alpha
- **Trigger:** count 3/3
- **After:** IMP-20260903-a-3
EOF
spec "$P" "IMP-20260905-refactor-alpha" 2026-09-10 high $(for i in $(seq 1 16); do printf 'src/contexts/alpha/r%s.ts ' "$i"; done) </dev/null
out="$(python3 "$SUT" --json "$P")"
ctx_ok "AC-5 the accepted IMP neither counts nor fires the large trigger" "$out" Alpha \
  "c['count'] == 0 and not c['due'] and c['triggers'] == [] and c['lastOutcome']['imp'] == 'IMP-20260905-refactor-alpha'"

# A project without a log counts from the default since and threshold.
P="$TMP/p-nolog"; new_project "$P"
out="$(python3 "$SUT" --json "$P")"
json_ok "FR-9 no log: default threshold and since" "$out" "d['threshold'] == 5 and d['since'] == d['defaultSince'] and d['log'] is None"

# A project without module-map.md reports everything as unknown.
P="$TMP/p-nomap"; mkdir -p "$P/docs/specs/archived"
spec "$P" "IMP-20261001-x" 2026-10-01 low 'src/x.ts' </dev/null
out="$(python3 "$SUT" --json "$P")"
ctx_ok "OS-3 no module map: unknown" "$out" unknown "c['count'] == 1"

# ---------- AC-2: the recommendation carries its evidence (FR-3, FR-4, FR-7) ----------
P="$TMP/p2"
new_project "$P"
printf -- '---\nsince: 2026-08-31\n---\n# Consolidation Log\n' > "$P/docs/consolidation-log.md"
for i in 1 2 3 4; do spec "$P" "IMP-2026090$i-a-$i" "2026-09-0$i" low "src/contexts/alpha/f$i.ts" </dev/null; done
spec "$P" "IMP-20260905-a-5" 2026-09-05 medium 'src/contexts/alpha/f5.ts' 'src/contexts/beta/g.ts' <<'EOF'

## Closure Evidence

- **AC-1:** passed.
- **Accepted duplication:** `mapRow` stands in alpha and beta; each maps a different schema.

### Review

RESULT: 2 findings / 0 applied / 2 rejected — run 2026-09-05 against main..HEAD, claude.

| # | Finding | Disposition |
|---|---|---|
| 1 | src/contexts/alpha/f5.ts:12 → FR-2 violated: retry copied from beta | rejected — the retry policies differ by design |
| 2 | src/contexts/beta/g.ts:3 → FR-1 violated: name | rejected — beta only, not Alpha |
EOF
cat > "$P/docs/improvements-log.md" <<'EOF'
# Improvements Log

### 2026-08-20 — Old Alpha note before since

- **Category:** `pattern`
- **What was found:** Alpha was slow.

### 2026-09-03 — Alpha adapters drift apart

- **Category:** `anti-pattern`
- **What was found:** three adapters in `src/contexts/alpha/` each parse dates.

### 2026-09-04 — Unrelated tooling note

- **Category:** `tooling`
- **What was found:** nothing about that context.
EOF
before="$(snapshot "$P")"
set +e
rec="$(python3 "$SUT" --json --recommend Alpha "$P" 2>"$TMP/stderr")"; rc=$?
set -e
[ "$rc" -eq 0 ] || fail "AC-2 --recommend exits 0 (got $rc: $(cat "$TMP/stderr"))"
json_ok "AC-2 the accepted-duplication bullet with its source" "$rec" \
  "[(x['source'], x['text'][:8]) for x in d['inputs']['acceptedDuplication']] == [('docs/specs/archived/IMP-20260905-a-5.md:20', '\`mapRow\`')]"
json_ok "AC-2 only the rejected finding whose path is in Alpha" "$rec" \
  "[x['source'] for x in d['inputs']['rejectedFindings']] == ['docs/specs/archived/IMP-20260905-a-5.md:28'] and 'differ by design' in d['inputs']['rejectedFindings'][0]['text']"
json_ok "AC-2 only the improvements-log entry after the cut-off naming Alpha" "$rec" \
  "[(x['source'], x['title']) for x in d['inputs']['improvementsLog']] == [('docs/improvements-log.md:8', 'Alpha adapters drift apart')]"
json_ok "AC-2 carries the context's closures and triggers" "$rec" \
  "d['context'] == 'Alpha' and d['count'] == 5 and d['triggers'] == ['count 5/5']"
text="$(python3 "$SUT" --recommend Alpha "$P")"
for needle in 'docs/specs/archived/IMP-20260905-a-5.md:20' 'docs/specs/archived/IMP-20260905-a-5.md:28' 'docs/improvements-log.md:8' 'refactor-only'; do
  printf '%s\n' "$text" | grep -qF "$needle" || fail "AC-2 text names $needle (got: $text)"
done
[ "$(snapshot "$P")" = "$before" ] || fail "AC-2 --recommend writes nothing"
set +e
python3 "$SUT" --recommend Gamma "$P" >/dev/null 2>"$TMP/stderr"; rc=$?
set -e
{ [ "$rc" -eq 2 ] && grep -q "Gamma" "$TMP/stderr"; } || fail "AC-2 an unknown context is a usage error naming it (rc $rc)"

# ---------- AC-4: a missing duplication input is stated, not skipped (FR-3, FR-8) ----------
gates() { # $1 dir, $2 duplication row
  cat > "$1/_canonical.md" <<EOF
# Project

## Build and Run

| # | Step | Kind | Mode | What fails it |
|---|---|---|---|---|
| 1 | \`lint\` | lint | gate | ESLint |
$2
EOF
}
mkdir -p "$P/.duplication-report"
gates "$P" '| — | `dup-report` | duplication | report | never; writes `.duplication-report/jscpd-report.json` |'
cat > "$P/.duplication-report/jscpd-report.json" <<'EOF'
{"duplicates": [
  {"lines": 20, "firstFile": {"name": "contexts/alpha/f1.ts"}, "secondFile": {"name": "contexts/alpha/f2.ts"}},
  {"lines": 7,  "firstFile": {"name": "contexts/beta/g.ts"},   "secondFile": {"name": "contexts/alpha/f3.ts"}},
  {"lines": 50, "firstFile": {"name": "contexts/beta/g.ts"},   "secondFile": {"name": "contexts/beta/h.ts"}}
], "statistics": {}}
EOF
rec="$(python3 "$SUT" --json --recommend Alpha "$P")"
json_ok "AC-4 report on disk: Alpha's clones and duplicated lines" "$rec" \
  "d['inputs']['duplication'] == {'status': 'report', 'path': '.duplication-report/jscpd-report.json', 'clones': 2, 'lines': 27, 'reason': None, 'source': '_canonical.md:8'}"
python3 "$SUT" --recommend Alpha "$P" | grep -q '2 clones, 27 duplicated lines' || fail "AC-4 text shows the figures"

rm "$P/.duplication-report/jscpd-report.json"
rec="$(python3 "$SUT" --json --recommend Alpha "$P")"
json_ok "AC-4 row present, report deleted: says missing at its path" "$rec" \
  "d['inputs']['duplication']['status'] == 'missing' and d['inputs']['duplication']['path'] == '.duplication-report/jscpd-report.json'"
python3 "$SUT" --recommend Alpha "$P" | grep -q 'report missing at .duplication-report/jscpd-report.json' || fail "AC-4 text says the report is missing"

gates "$P" '| — | n/a — no JavaScript tree to scan | duplication | — | — |'
rec="$(python3 "$SUT" --json --recommend Alpha "$P")"
json_ok "AC-4 n/a row: states its reason" "$rec" \
  "d['inputs']['duplication']['status'] == 'n/a' and d['inputs']['duplication']['reason'] == 'no JavaScript tree to scan'"
python3 "$SUT" --recommend Alpha "$P" | grep -q 'n/a — no JavaScript tree to scan' || fail "AC-4 text states the n/a reason"

rm "$P/_canonical.md"
rec="$(python3 "$SUT" --json --recommend Alpha "$P")"
json_ok "FR-8 no duplication row: says so" "$rec" "d['inputs']['duplication']['status'] == 'absent'"
python3 "$SUT" --recommend Alpha "$P" | grep -q 'no duplication row' || fail "FR-8 text says there is no duplication row"

if [ "$fails" -eq 0 ]; then
  echo "scripts/consolidation-due.py self-tests passed ✓"
else
  echo "$fails consolidation-due self-test(s) failed ✗" >&2
  exit 1
fi
