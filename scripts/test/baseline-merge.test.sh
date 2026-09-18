#!/usr/bin/env bash
# scripts/test/baseline-merge.test.sh
#
# Self-tests for the baseline REQ index and delta merge
# (IMP-20260914-baseline-deltas-and-merge). Library behaviour is asserted by
# running Python against `scripts/speclib.py`; the CLI is exercised on
# throwaway project roots in a temp dir.
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
check() { # $1 desc, $2 baseline text (bound to `text`), $3 python source
  local err
  if ! err="$(TEXT="$2" PYTHONDONTWRITEBYTECODE=1 python3 -c "
import os, sys
sys.path.insert(0, '$SCRIPTS')
from pathlib import Path
from speclib import *
from speclib import _parse_front_matter
text = os.environ['TEXT']
def mkspec(t, name='IMP-20261001-demo.md'):
    fm, body, end, _ = _parse_front_matter(t, Path('/demo/docs/specs/active') / name)
    return Spec(Path('/demo/docs/specs/active') / name, fm, body, end)
$3
" 2>&1)"; then
    echo "FAIL: $1" >&2
    printf '%s\n' "$err" | tail -3 | sed 's/^/  /' >&2
    fails=$((fails + 1))
  fi
}

# ---------- T1: baseline REQ index ----------
BASELINE='# Demo
*Last updated: 2026-08-26*

| Last src verified | 2026-08-26 (demo) |

## Functional Requirements

### Ingest

- **MUST** do one thing. *(REQ-X-001)*
- **MUST** do another thing, wrapped
  over two lines. *(REQ-X-002)*
  - Scenario: Given a place When it is ingested Then it is stored
- ~~REQ-X-003~~ deleted — Why: gone. Migration: none.

```bash
# not a heading
```

## Invariants

- **MUST** hold. *(REQ-X-INV-7)*
- **MUST** cite REQ-X-001 without redefining it. *(REQ-X-004)*'

check "index finds each definition once, citations excluded" "$BASELINE" '
idx = index_baseline(text)
assert sorted(idx.entries) == ["REQ-X-001", "REQ-X-002", "REQ-X-004", "REQ-X-INV-7"], sorted(idx.entries)
assert idx.duplicates == [], idx.duplicates'

check "a one-line REQ spans its own line, 1-indexed" "$BASELINE" '
e = index_baseline(text).entries["REQ-X-001"]
lines = text.splitlines()
assert (e.start, e.end, e.line) == (9, 10, 10), (e.start, e.end, e.line)'

check "a wrapped REQ spans from its bullet through its nested scenario" "$BASELINE" '
e = index_baseline(text).entries["REQ-X-002"]
lines = text.splitlines()
assert lines[e.start].startswith("- **MUST** do another"), lines[e.start]
assert lines[e.end - 1].lstrip().startswith("- Scenario:"), lines[e.end - 1]
assert e.line == 12, e.line'

check "each REQ knows its nearest heading; fenced lines are not headings" "$BASELINE" '
idx = index_baseline(text)
assert idx.entries["REQ-X-001"].heading == "### Ingest", idx.entries["REQ-X-001"].heading
assert idx.entries["REQ-X-INV-7"].heading == "## Invariants", idx.entries["REQ-X-INV-7"].heading'

check "next_id continues past tombstones and keeps zero padding" "$BASELINE" '
idx = index_baseline(text)
assert idx.next_id("REQ-X") == "REQ-X-005", idx.next_id("REQ-X")
assert idx.next_id("REQ-X-INV") == "REQ-X-INV-8", idx.next_id("REQ-X-INV")
assert idx.next_id("REQ-NEW") == "REQ-NEW-001", idx.next_id("REQ-NEW")'

check "duplicates are reported with both lines; history annotations are not definitions" '## FR
- a *(REQ-D-001)*
- b *(REQ-D-001; added by IMP-1)*
- c *(REQ-D-002 superseded by REQ-D-003)*' '
idx = index_baseline(text)
assert idx.duplicates == [("REQ-D-001", 3, 2)], idx.duplicates
assert "REQ-D-002" not in idx.entries'

# ---------- T2: delta parser (FR-1, FR-2) ----------
SPEC='---
id: IMP-20261001-demo
status: specify
---
# IMP-20261001-demo

## Design

```markdown
## Baseline Deltas
### docs/domain/ignored.md
```

## Baseline Deltas

### docs/domain/demo.md

#### ADDED
- Under `### Ingest`:
  - **MUST** do a new thing,
    wrapped. *(REQ-X-005)*
    - Scenario: Given a place When it is ingested Then it is kept
  - **MUST** do a second new thing. *(REQ-X-006)*

#### MODIFIED
- REQ-X-002 — Why: the old form was wrong
  - **MUST** do another thing, better. *(REQ-X-002)*
    - Verified by: `src/demo.test.ts`

#### REMOVED
- REQ-X-001 — Reason: obsolete — Migration: use REQ-X-005

#### RENAMED
- FROM REQ-X-004 TO REQ-X-007 — Why: moved

## Out of Scope
- nothing'

check "no Baseline Deltas section parses to None" '---
id: IMP-20261001-none
---
# x

## Summary
- a' '
assert parse_baseline_deltas(mkspec(text)) is None'

check "a section shown only inside a fence is not the section" '---
id: IMP-20261001-fenced
---
# x

## Design

```markdown
## Baseline Deltas
```' '
assert parse_baseline_deltas(mkspec(text)) is None'

check "a fenced example is not the section; one baseline with four blocks is read" "$SPEC" '
d = parse_baseline_deltas(mkspec(text))
assert d.findings == (), d.findings
assert [b.path for b in d.baselines] == ["docs/domain/demo.md"], d.baselines
b = d.baselines[0]
assert (len(b.added), len(b.modified), len(b.removed), len(b.renamed)) == (2, 1, 1, 1), b'

check "ADDED carries its heading and each REQ dedented with its nested lines" "$SPEC" '
b = parse_baseline_deltas(mkspec(text)).baselines[0]
first, second = b.added
assert first.heading == "### Ingest" and first.req_id == "REQ-X-005", first
assert first.lines == ("- **MUST** do a new thing,", "  wrapped. *(REQ-X-005)*", "  - Scenario: Given a place When it is ingested Then it is kept"), first.lines
assert second.req_id == "REQ-X-006" and second.lines == ("- **MUST** do a second new thing. *(REQ-X-006)*",), second
assert first.line == 20, first.line'

check "MODIFIED, REMOVED and RENAMED carry their parts" "$SPEC" '
b = parse_baseline_deltas(mkspec(text)).baselines[0]
m = b.modified[0]
assert (m.req_id, m.why) == ("REQ-X-002", "the old form was wrong"), m
assert m.lines == ("- **MUST** do another thing, better. *(REQ-X-002)*", "  - Verified by: `src/demo.test.ts`"), m.lines
r = b.removed[0]
assert (r.req_id, r.reason, r.migration) == ("REQ-X-001", "obsolete", "use REQ-X-005"), r
n = b.renamed[0]
assert (n.from_id, n.to_id, n.why) == ("REQ-X-004", "REQ-X-007", "moved"), n'

BAD='---
id: IMP-20261001-bad
---
# x

## Baseline Deltas

stray text

### src/not-a-baseline.ts

### docs/domain/demo.md

#### CHANGED
- REQ-X-001

#### ADDED
- REQ-X-009 with no heading
- Under `### Ingest`:
  - **MUST** carry no annotation.

#### MODIFIED
- REQ-X-002 — Why: no replacement
- REQ-X-003
  - **MUST** define the wrong ID. *(REQ-X-004)*

#### REMOVED
- REQ-X-001 — Reason: gone

#### RENAMED
- FROM REQ-X-004 — Why: no target'

check "each malformed part is one finding naming its line" "$BAD" '
d = parse_baseline_deltas(mkspec(text))
got = [(f.line, f.check) for f in d.findings]
msgs = " | ".join(f.message for f in d.findings)
assert all(c == "baseline_delta_malformed" for _, c in got), got
assert [l for l, _ in got] == [8, 10, 14, 18, 20, 23, 24, 28, 31], (got, msgs)
for needle in ("outside a baseline", "docs/domain/", "CHANGED", "Under", "annotation", "replacement", "REQ-X-004", "Migration", "FROM"):
    assert needle in msgs, (needle, msgs)'

check "HTML comments inside the section are guidance, not content" '---
id: IMP-20261001-comment
---
# x

## Baseline Deltas
<!-- One `###` per baseline:
### docs/domain/<feature>.md
#### ADDED
- Under `### <heading>`:
-->
<!-- or delete this section -->' '
d = parse_baseline_deltas(mkspec(text))
assert d is not None and d.baselines == () and d.findings == (), d'

# ---------- T3: baseline-merge --check (FR-2, FR-6; AC-2) ----------
TOOL="$SCRIPTS/baseline-merge.py"
out=""
rc=0
expect() { # $1 desc, $2 expected rc, $3 actual rc
  if [ "$2" -ne "$3" ]; then
    echo "FAIL: $1 (expected rc=$2, got rc=$3)" >&2
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    fails=$((fails + 1))
  fi
}
assert_reports() { # $1 desc, $2 grep pattern (against $out)
  if ! printf '%s' "$out" | grep -q -- "$2"; then
    echo "FAIL: $1 (no line matching '$2')" >&2
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    fails=$((fails + 1))
  fi
}
assert_silent() { # $1 desc, $2 grep pattern (against $out)
  if printf '%s' "$out" | grep -q -- "$2"; then
    echo "FAIL: $1 (unexpected line matching '$2')" >&2
    fails=$((fails + 1))
  fi
}
tool() { # $@ args — sets $out and $rc
  set +e
  out="$(PYTHONDONTWRITEBYTECODE=1 python3 "$TOOL" "$@" 2>&1)"; rc=$?
  set -e
}
newproj() { # $1 name -> echoes a project root holding docs/domain/demo.md
  local d="$TMP/$1"
  mkdir -p "$d/docs/specs/active" "$d/docs/specs/archived" "$d/docs/domain"
  cat > "$d/docs/domain/demo.md" <<'EOF'
# Demo
*Last updated: 2026-08-26*

| Last src verified | 2026-08-26 (demo) |

## Functional Requirements

### Ingest

- **MUST** do one thing. *(REQ-X-001)*
- **MUST** do another thing. *(REQ-X-002)*
- ~~REQ-X-003~~ deleted — Why: gone.
- **MUST** do a fourth thing. *(REQ-X-004)*
EOF
  printf '%s' "$d"
}
delta_spec() { # $1 root, $2 dir (active|archived), $3 id, $4 extra front-matter; body on stdin
  {
    echo "---"
    echo "id: $3"
    echo "status: specify"
    [ -z "$4" ] || printf '%s\n' "$4"
    echo "---"
    echo "# $3"
    echo
    echo "## Baseline Deltas"
    echo
    cat
  } > "$1/docs/specs/$2/$3.md"
}

p="$(newproj clean)"
delta_spec "$p" active IMP-20261001-clean "" <<'EOF'
### docs/domain/demo.md

#### ADDED
- Under `### Ingest`:
  - **MUST** do a fifth thing. *(REQ-X-005)*
  - **MUST** do a sixth thing. *(REQ-X-006)*

#### MODIFIED
- REQ-X-002 — Why: sharper
  - **MUST** do another thing, sharper. *(REQ-X-002)*

#### REMOVED
- REQ-X-001 — Reason: obsolete — Migration: none

#### RENAMED
- FROM REQ-X-004 TO REQ-X-007 — Why: moved
EOF
tool --check "$p/docs/specs/active/IMP-20261001-clean.md"
expect "a valid delta passes --check" 0 "$rc"
assert_reports "a clean --check says so" "^baseline-merge: OK"

# AC-2: a missing target, and two unrelated active specs on one REQ.
p="$(newproj ac2)"
delta_spec "$p" active IMP-20261001-missing "" <<'EOF'
### docs/domain/demo.md

#### MODIFIED
- REQ-X-009
  - **MUST** not exist. *(REQ-X-009)*
EOF
delta_spec "$p" active IMP-20261001-first "" <<'EOF'
### docs/domain/demo.md

#### MODIFIED
- REQ-X-002
  - **MUST** one way. *(REQ-X-002)*
EOF
delta_spec "$p" active IMP-20261002-second "" <<'EOF'
### docs/domain/demo.md

#### MODIFIED
- REQ-X-002
  - **MUST** another way. *(REQ-X-002)*
EOF
tool --check "$p/docs/specs/active/IMP-20261001-missing.md"
expect "AC-2 a missing MODIFIED target fails --check" 1 "$rc"
assert_reports "AC-2 the missing target is named" "IMP-20261001-missing.md:[0-9]*:baseline_delta_target_missing:.*REQ-X-009"
set +e; out="$(cd "$p" && PYTHONDONTWRITEBYTECODE=1 python3 "$TOOL" --check 2>&1)"; rc=$?; set -e
expect "AC-2 --check over every active spec of the working directory's project fails" 1 "$rc"
assert_reports "AC-2 the collision is reported on the first spec" "IMP-20261001-first.md:[0-9]*:baseline_delta_collision:.*REQ-X-002.*IMP-20261002-second"
assert_reports "AC-2 the collision is reported on the second spec" "IMP-20261002-second.md:[0-9]*:baseline_delta_collision:.*IMP-20261001-first"

# Declared relation, or the other spec archived: no collision.
p="$(newproj related)"
delta_spec "$p" active IMP-20261001-first "siblings:
  - IMP-20261002-second" <<'EOF'
### docs/domain/demo.md

#### MODIFIED
- REQ-X-002
  - **MUST** one way. *(REQ-X-002)*
EOF
delta_spec "$p" active IMP-20261002-second "" <<'EOF'
### docs/domain/demo.md

#### MODIFIED
- REQ-X-002
  - **MUST** another way. *(REQ-X-002)*
EOF
delta_spec "$p" archived IMP-20260901-old "" <<'EOF'
### docs/domain/demo.md

#### MODIFIED
- REQ-X-002
  - **MUST** the old way. *(REQ-X-002)*
EOF
tool --check "$p/docs/specs/active/IMP-20261002-second.md"
expect "a relation declared on either side, or an archived spec, is no collision" 0 "$rc"

# Numbering, taken IDs, headings, files, conflicts.
p="$(newproj numbering)"
cat > "$p/docs/domain/dup.md" <<'EOF'
# Dup

## FR

- **MUST** a. *(REQ-D-001)*
- **MUST** b. *(REQ-D-001)*
EOF
cat > "$p/docs/domain/plain.md" <<'EOF'
# Plain

## FR

- **MUST** carry no IDs.
EOF
delta_spec "$p" active IMP-20261001-bad "" <<'EOF'
### docs/domain/demo.md

#### ADDED
- Under `### Ingest`:
  - **MUST** reuse. *(REQ-X-004)*
  - **MUST** skip. *(REQ-X-006)*
- Under `### Nowhere`:
  - **MUST** land nowhere. *(REQ-X-INV-001)*

#### MODIFIED
- REQ-X-001
  - **MUST** change. *(REQ-X-001)*

#### REMOVED
- REQ-X-001 — Reason: twice — Migration: none
- REQ-X-003 — Reason: already gone — Migration: none

### docs/domain/dup.md

#### REMOVED
- REQ-D-001 — Reason: which one — Migration: none

### docs/domain/plain.md

#### ADDED
- Under `## FR`:
  - **MUST** start a series. *(REQ-P-001)*

#### MODIFIED
- REQ-P-001
  - **MUST** not be addressable. *(REQ-P-001)*

### docs/domain/absent.md

#### REMOVED
- REQ-A-001 — Reason: no file — Migration: none
EOF
tool --check "$p/docs/specs/active/IMP-20261001-bad.md"
expect "a bad delta fails --check" 1 "$rc"
assert_reports "an ADDED ID already defined is taken" "baseline_delta_id_taken:.*REQ-X-004"
assert_reports "an ADDED ID that skips a number names the next one" "baseline_delta_numbering:.*REQ-X-006.*REQ-X-005"
assert_reports "an ADDED heading absent from the baseline" "baseline_delta_heading_missing:.*### Nowhere"
assert_reports "one REQ-ID touched twice in one baseline" "baseline_delta_conflict:.*REQ-X-001"
assert_reports "a tombstoned ID is not a target" "baseline_delta_target_missing:.*REQ-X-003"
assert_reports "a duplicated target is ambiguous" "baseline_delta_target_ambiguous:.*REQ-D-001"
assert_silent "a new series in an un-ID'd baseline starts at 001" "baseline_delta_numbering:.*REQ-P-001"
assert_reports "a MODIFIED against an un-ID'd baseline says the closure edits it by hand" "baseline_delta_target_missing:.*REQ-P-001.*by hand at this spec.s closure"
assert_reports "a missing baseline file" "baseline_delta_file_missing:.*docs/domain/absent.md"
assert_silent "no target check runs against a missing file" "baseline_delta_target_missing:.*REQ-A-001"

p="$(newproj malformed)"
delta_spec "$p" active IMP-20261001-malformed "" <<'EOF'
### docs/domain/demo.md

#### REMOVED
- REQ-X-001 — Reason: gone
EOF
tool --check "$p/docs/specs/active/IMP-20261001-malformed.md"
expect "a malformed delta fails --check" 1 "$rc"
assert_reports "malformed findings come through --check" "baseline_delta_malformed:.*Migration"

# ---------- T4: baseline-merge --apply (FR-8; AC-1, AC-2) ----------
applyproj() { # $1 name -> echoes a project root holding the AC-1 fixture baseline
  local d="$TMP/$1"
  mkdir -p "$d/docs/specs/active" "$d/docs/specs/archived" "$d/docs/domain"
  cat > "$d/docs/domain/demo.md" <<'EOF'
# Demo
*Last updated: 2026-08-26*

| Field | Value |
|---|---|
| Last src verified | 2026-08-26 (demo re-read) |

## Functional Requirements

### Ingest

- **MUST** do one thing. *(REQ-X-001)*
- **MUST** do another thing,
  wrapped over two lines. *(REQ-X-002)*
- **MUST** do a third thing. *(REQ-X-003; CR-1 FR-2)*

### Publish

- **MUST** publish. *(REQ-Y-001)*
EOF
  printf '%s' "$d"
}
assert_file() { # $1 desc, $2 file, $3 expected content
  if ! diff -u <(printf '%s\n' "$3") "$2" > "$TMP/diff.out"; then
    echo "FAIL: $1" >&2
    sed 's/^/  /' "$TMP/diff.out" >&2
    fails=$((fails + 1))
  fi
}

p="$(applyproj ac1)"
delta_spec "$p" active IMP-20261001-ac1 "closed: 2026-10-01" <<'EOF'
### docs/domain/demo.md

#### ADDED
- Under `### Ingest`:
  - **MUST** do a fourth thing. *(REQ-X-004)*
    - Scenario: Given a place When it is ingested Then it is kept

#### MODIFIED
- REQ-X-002 — Why: one line now
  - **MUST** do another thing, in one line. *(REQ-X-002)*
    - Verified by: `src/x.test.ts`

#### REMOVED
- REQ-X-003 — Reason: obsolete — Migration: use REQ-X-004
EOF
tool --apply "$p/docs/specs/active/IMP-20261001-ac1.md"
expect "AC-1 --apply exits 0" 0 "$rc"
assert_reports "AC-1 --apply names what it wrote" "^baseline-merge: applied 1 baseline(s)"
assert_file "AC-1 the baseline matches the golden file" "$p/docs/domain/demo.md" '# Demo
*Last updated: 2026-10-01*

| Field | Value |
|---|---|
| Last src verified | 2026-10-01 (IMP-20261001-ac1) |

## Functional Requirements

### Ingest

- **MUST** do one thing. *(REQ-X-001)*
- **MUST** do another thing, in one line. *(REQ-X-002; amended by IMP-20261001-ac1 — one line now)*
  - Verified by: `src/x.test.ts`
- ~~REQ-X-003~~ deleted — Why: obsolete. Migration: use REQ-X-004.
- **MUST** do a fourth thing. *(REQ-X-004)*
  - Scenario: Given a place When it is ingested Then it is kept

### Publish

- **MUST** publish. *(REQ-Y-001)*'
out="$(cd "$p" && PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPTS/validate-specs.py" docs/specs 2>&1)" || true
assert_silent "AC-1 the merged baseline has no duplicate REQ-ID" "domain_req_id_duplicate"

p="$(applyproj renamed)"
delta_spec "$p" active IMP-20261002-renamed "closed: 2026-10-02" <<'EOF'
### docs/domain/demo.md

#### RENAMED
- FROM REQ-X-003 TO REQ-X-004 — Why: moved

#### ADDED
- Under `### Publish`:
  - **MUST** publish twice. *(REQ-Y-002)*
EOF
tool --apply "$p/docs/specs/active/IMP-20261002-renamed.md"
expect "RENAMED --apply exits 0" 0 "$rc"
assert_file "RENAMED tombstones FROM in place and TO takes its text; ADDED appends to its heading's list" "$p/docs/domain/demo.md" '# Demo
*Last updated: 2026-10-02*

| Field | Value |
|---|---|
| Last src verified | 2026-10-02 (IMP-20261002-renamed) |

## Functional Requirements

### Ingest

- **MUST** do one thing. *(REQ-X-001)*
- **MUST** do another thing,
  wrapped over two lines. *(REQ-X-002)*
- ~~REQ-X-003~~ superseded by REQ-X-004 — Why: moved.
- **MUST** do a third thing. *(REQ-X-004; CR-1 FR-2; renamed from REQ-X-003 by IMP-20261002-renamed)*

### Publish

- **MUST** publish. *(REQ-Y-001)*
- **MUST** publish twice. *(REQ-Y-002)*'

p="$(applyproj trail)"
delta_spec "$p" active IMP-20261003-trail "closed: 2026-10-03" <<'EOF'
### docs/domain/demo.md

#### MODIFIED
- REQ-X-003 — Why: sharper
  - **MUST** do a third thing, sharper. *(REQ-X-003)*
EOF
tool --apply "$p/docs/specs/active/IMP-20261003-trail.md"
expect "trail --apply exits 0" 0 "$rc"
if ! grep -qF -- '- **MUST** do a third thing, sharper. *(REQ-X-003; CR-1 FR-2; amended by IMP-20261003-trail — sharper)*' "$p/docs/domain/demo.md"; then
  echo "FAIL: MODIFIED keeps the annotation trail the author did not restate" >&2
  grep -n "REQ-X-003" "$p/docs/domain/demo.md" | sed 's/^/  /' >&2
  fails=$((fails + 1))
fi

# AC-2 apply half: a failing check writes nothing.
p="$(applyproj refused)"
cp "$p/docs/domain/demo.md" "$TMP/refused.orig"
delta_spec "$p" active IMP-20261001-refused "closed: 2026-10-01" <<'EOF'
### docs/domain/demo.md

#### ADDED
- Under `### Ingest`:
  - **MUST** be fine on its own. *(REQ-X-004)*

#### MODIFIED
- REQ-X-009
  - **MUST** not exist. *(REQ-X-009)*
EOF
tool --apply "$p/docs/specs/active/IMP-20261001-refused.md"
expect "AC-2 --apply on a failing check exits non-zero" 1 "$rc"
assert_reports "AC-2 --apply prints the check findings" "baseline_delta_target_missing:.*REQ-X-009"
if ! cmp -s "$TMP/refused.orig" "$p/docs/domain/demo.md"; then
  echo "FAIL: AC-2 the baseline is byte-identical after a refused --apply" >&2
  fails=$((fails + 1))
fi

p="$(applyproj unclosed)"
cp "$p/docs/domain/demo.md" "$TMP/unclosed.orig"
delta_spec "$p" active IMP-20261001-unclosed "" <<'EOF'
### docs/domain/demo.md

#### REMOVED
- REQ-X-001 — Reason: gone — Migration: none
EOF
tool --apply "$p/docs/specs/active/IMP-20261001-unclosed.md"
expect "--apply without closed: exits non-zero" 1 "$rc"
assert_reports "--apply without closed: says why" "closed:"
if ! cmp -s "$TMP/unclosed.orig" "$p/docs/domain/demo.md"; then
  echo "FAIL: --apply without closed: leaves the baseline byte-identical" >&2
  fails=$((fails + 1))
fi

p="$(applyproj nodeltas)"
printf -- '---\nid: IMP-20261001-nodeltas\nclosed: 2026-10-01\n---\n# x\n' > "$p/docs/specs/active/IMP-20261001-nodeltas.md"
tool --apply "$p/docs/specs/active/IMP-20261001-nodeltas.md"
expect "--apply on a spec without Baseline Deltas exits non-zero" 1 "$rc"
assert_reports "--apply without deltas says so" "no ## Baseline Deltas"

# ---------- T5: baseline-merge --diff (FR-7; AC-3) ----------
p="$(applyproj ac3)"
cp "$p/docs/domain/demo.md" "$TMP/ac3.orig"
delta_spec "$p" active IMP-20261001-ac3 "" <<'EOF'
### docs/domain/demo.md

#### ADDED
- Under `### Ingest`:
  - **MUST** do a fourth thing. *(REQ-X-004)*
    - Scenario: Given a place When it is ingested Then it is kept

#### MODIFIED
- REQ-X-002 — Why: one line now
  - **MUST** do another thing, in one line. *(REQ-X-002)*
    - Verified by: `src/x.test.ts`

#### REMOVED
- REQ-X-003 — Reason: obsolete — Migration: use REQ-X-004
EOF
tool --diff "$p/docs/specs/active/IMP-20261001-ac3.md"
expect "AC-3 --diff exits 0 without closed:" 0 "$rc"
if [ "$out" != '--- a/docs/domain/demo.md
+++ b/docs/domain/demo.md
@@ -1,18 +1,20 @@
 # Demo
-*Last updated: 2026-08-26*
+*Last updated: YYYY-MM-DD*
 
 | Field | Value |
 |---|---|
-| Last src verified | 2026-08-26 (demo re-read) |
+| Last src verified | YYYY-MM-DD (IMP-20261001-ac3) |
 
 ## Functional Requirements
 
 ### Ingest
 
 - **MUST** do one thing. *(REQ-X-001)*
-- **MUST** do another thing,
-  wrapped over two lines. *(REQ-X-002)*
-- **MUST** do a third thing. *(REQ-X-003; CR-1 FR-2)*
+- **MUST** do another thing, in one line. *(REQ-X-002; amended by IMP-20261001-ac3 — one line now)*
+  - Verified by: `src/x.test.ts`
+- ~~REQ-X-003~~ deleted — Why: obsolete. Migration: use REQ-X-004.
+- **MUST** do a fourth thing. *(REQ-X-004)*
+  - Scenario: Given a place When it is ingested Then it is kept
 
 ### Publish
 ' ]; then
  echo "FAIL: AC-3 --diff prints the snapshot unified diff" >&2
  printf '%s\n' "$out" | sed 's/^/  /' >&2
  fails=$((fails + 1))
fi
if ! cmp -s "$TMP/ac3.orig" "$p/docs/domain/demo.md"; then
  echo "FAIL: AC-3 --diff writes no file" >&2
  fails=$((fails + 1))
fi
delta_spec "$p" active IMP-20261001-ac3 "closed: 2026-10-01" <<'EOF'
### docs/domain/demo.md

#### REMOVED
- REQ-X-001 — Reason: gone — Migration: none
EOF
tool --diff "$p/docs/specs/active/IMP-20261001-ac3.md"
assert_reports "--diff uses closed: when the spec has one" "^+| Last src verified | 2026-10-01 (IMP-20261001-ac3) |"
delta_spec "$p" active IMP-20261001-ac3 "" <<'EOF'
### docs/domain/demo.md

#### REMOVED
- REQ-X-009 — Reason: gone — Migration: none
EOF
tool --diff "$p/docs/specs/active/IMP-20261001-ac3.md"
expect "--diff on a failing check exits non-zero" 1 "$rc"
assert_reports "--diff on a failing check prints the findings" "baseline_delta_target_missing"

if [ "$fails" -eq 0 ]; then
  echo "scripts/baseline-merge self-tests passed ✓"
else
  echo "$fails baseline-merge self-test(s) failed ✗" >&2
  exit 1
fi
