#!/usr/bin/env bash
# scripts/test/spec-next.test.sh
#
# Self-tests for scripts/spec-next.py: throwaway specs at one type × lane × status
# each, asserting the printed step carries its own questions, gate and rules and
# nothing belonging to another case (IMP-20260914-spec-next-instructions AC-1, AC-2).
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"
SPEC_NEXT="$SCRIPTS/spec-next.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

has() { # $1 desc, $2 output, $3 fixed string
  if ! printf '%s' "$2" | grep -qF -- "$3"; then echo "FAIL: $1 (missing '$3')" >&2; fails=$((fails + 1)); fi
}
lacks() { # $1 desc, $2 output, $3 fixed string (case-insensitive)
  if printf '%s' "$2" | grep -qiF -- "$3"; then echo "FAIL: $1 (unexpected '$3')" >&2; fails=$((fails + 1)); fi
}
json() { # $1 desc, $2 json, $3 python expression over `j`
  if ! printf '%s' "$2" | python3 -c "import json,sys; j=json.load(sys.stdin); sys.exit(0 if ($3) else 1)" 2>/dev/null; then
    echo "FAIL: $1 (json: $3)" >&2; fails=$((fails + 1))
  fi
}
newproj() { local d="$TMP/$1"; mkdir -p "$d/docs/specs/active" "$d/docs/specs/archived"; printf '%s' "$d"; }
count() { printf '%s\n' "$1" | grep -c -- "$2" || true; }

# ---------- AC-1 case 1: a CR electing the removed Trivial lane gets the standard track ----------
# (IMP-20260917-remove-trivial-lane AC-2 / FR-4)
p="$(newproj trivial)"
cat > "$p/docs/specs/active/CR-20260917-tiny.md" <<'SPEC'
---
id: CR-20260917-tiny
type: CR
date: 2026-09-17
status: specify
owner: alex
risk: trivial
affected-repos:
  - demo
affected-docs: []
affected-code:
  - src/a.ts
skills:
  - writing-specs
model-suggestion: fast
---
# CR-20260917-tiny
*Last updated: 2026-09-17*
## Summary
- **Goal:** Rename one label.
## Problem Statement
<!-- ≤12 lines -->
## Requirements
- FR-1: The system MUST ...
## Split Decision
<Fill during Specify. See docs/spec-templates-guide.md § Split Decision.>
## Tasks
Pending — Plan stage only.
SPEC
out="$(python3 "$SPEC_NEXT" "$p/docs/specs/active/CR-20260917-tiny.md")"
has "AC-2 trivial: standard lane named" "$out" "standard lane"
lacks "AC-2 trivial: no trivial lane" "$out" "trivial lane"
lacks "AC-2 trivial: no combined gate" "$out" "Combined specify+plan gate"
lacks "AC-2 trivial: no trivial question list" "$out" "trivial-questions.md"
has "AC-2 trivial: the standard CR question list" "$out" "cr-questions.md"
js="$(python3 "$SPEC_NEXT" --json "$p/docs/specs/active/CR-20260917-tiny.md")"
json "AC-2 trivial json: lane" "$js" "j['lane'] == 'standard' and j['status'] == 'specify'"
json "AC-2 trivial json: rules carry lines" "$js" "all(r['line'] for r in j['rules'])"

# ---------- AC-1 case 2: a high-risk IMP at plan, no Tasks table yet ----------
p="$(newproj plan)"
cat > "$p/docs/specs/active/IMP-20260917-big.md" <<'SPEC'
---
id: IMP-20260917-big
type: IMP
date: 2026-09-17
status: plan
owner: alex
risk: high
affected-repos:
  - demo
affected-docs: []
affected-code: []
skills:
  - writing-specs
model-suggestion: deep
---
# IMP-20260917-big
*Last updated: 2026-09-17*
## Summary
- **Goal:** Big change.
## Requirements
- FR-1: The system MUST do it.
## Design
Skipped — none.
## Split Decision
Kept as one — no trigger.
## Tasks
Pending — Plan stage only.
SPEC
out="$(python3 "$SPEC_NEXT" "$p/docs/specs/active/IMP-20260917-big.md")"
has "AC-1 plan: decomposition step" "$out" "Decompose into vertical-slice tasks"
has "AC-1 plan: safety net" "$out" "Plan-stage safety net"
has "AC-1 plan: task-table format" "$out" "tasks-table-format — Format"
has "AC-1 plan: plan gate" "$out" "Plan gate"
has "AC-1 plan: procedure file to load" "$out" "authoring-steps.md"
lacks "AC-1 plan: no questions" "$out" "Q1 "
lacks "AC-1 plan: no question list" "$out" "questions.md"
lacks "AC-1 plan: nothing from specify" "$out" "Requirements gate"
js="$(python3 "$SPEC_NEXT" "$p/docs/specs/active/IMP-20260917-big.md" --json)"
json "AC-1 plan json: step" "$js" "j['step']['id'] == 'decompose' and j['lane'] == 'standard'"
json "AC-1 plan json: no questions" "$js" "j['questions'] is None"
json "AC-1 plan json: Tasks missing" "$js" "j['missing_sections'] == ['Tasks']"
json "AC-1 plan json: procedure section to load" "$js" "j['sections'][0]['path'].endswith('authoring-steps.md') and j['sections'][0]['end'] > j['sections'][0]['start'] and j['files'] == []"
json "AC-2 trivial json: template to load" "$(python3 "$SPEC_NEXT" --json "$TMP/trivial/docs/specs/active/CR-20260917-tiny.md")" "j['files'][0].endswith('CR-TEMPLATE.md')"

# ---------- An IMP at specify with the body written moves to the Split check ----------
p="$(newproj split)"
sed -e 's/^status: plan$/status: specify/' -e 's/^risk: high$/risk: medium/' \
  "$TMP/plan/docs/specs/active/IMP-20260917-big.md" > "$p/docs/specs/active/IMP-20260917-big.md"
python3 - "$p/docs/specs/active/IMP-20260917-big.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("## Design\nSkipped — none.\n## Split Decision\nKept as one — no trigger.\n",
              "## Current State\nX.\n## Proposed Improvement\nY.\n## Acceptance Criteria\n### AC-1: it (FR-1)\n"
              "## Out of Scope\n- OS-1: none\n## Design\nPending — Visualize sub-step.\n## Split Decision\nPending\n")
open(p, "w").write(s)
PY
out="$(python3 "$SPEC_NEXT" "$p/docs/specs/active/IMP-20260917-big.md")"
has "specify: body written → Split check" "$out" "Next step: Split check"
has "specify: gate is the requirements gate" "$out" "Requirements gate"
lacks "specify: split step asks no questions" "$out" "Q1 "

# ---------- AC-1 case 3: an IMP in progress with T1 done → T2, then the closure gate ----------
p="$(newproj progress)"
sed -e 's/^status: plan$/status: in-progress/' "$TMP/plan/docs/specs/active/IMP-20260917-big.md" \
  > "$p/docs/specs/active/IMP-20260917-big.md"
python3 - "$p/docs/specs/active/IMP-20260917-big.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("## Tasks\nPending — Plan stage only.\n",
              "## Tasks\n\n| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |\n"
              "|---|---|---|---|---|---|---|---|\n"
              "| T1 | First slice (FR-1) | `a.py` | — | — | writing-specs | default | ☑ done |\n"
              "| T2 | Second slice (FR-1) | `b.py` | — | T1 | writing-specs | default | ☐ pending |\n")
open(p, "w").write(s)
PY
out="$(python3 "$SPEC_NEXT" "$p/docs/specs/active/IMP-20260917-big.md")"
has "AC-1 in-progress: next task is T2" "$out" "Task: T2 (☐ pending) — Second slice (FR-1)"
has "AC-1 in-progress: its files" "$out" '`b.py`'
has "AC-1 in-progress: closure gate named" "$out" "Closure gate"
lacks "AC-1 in-progress: T1 is not offered" "$out" "First slice"
lacks "AC-1 in-progress: nothing from plan" "$out" "Decompose into vertical-slice tasks"
js="$(python3 "$SPEC_NEXT" --json "$p/docs/specs/active/IMP-20260917-big.md")"
json "AC-1 in-progress json: task" "$js" "j['step']['id'] == 'task' and j['task']['id'] == 'T2'"
sed -i.bak 's/| ☐ pending |$/| ☑ done |/' "$p/docs/specs/active/IMP-20260917-big.md"
out="$(python3 "$SPEC_NEXT" "$p/docs/specs/active/IMP-20260917-big.md")"
has "AC-1 in-progress: all done → closure gate" "$out" "Next step: Closure gate"
lacks "AC-1 in-progress: no task once all are done" "$out" "Task: T"

# ---------- A done spec has no next step ----------
sed -i.bak 's/^status: in-progress$/status: done/' "$p/docs/specs/active/IMP-20260917-big.md"
out="$(python3 "$SPEC_NEXT" "$p/docs/specs/active/IMP-20260917-big.md")"
has "done: no next step" "$out" "No next step"

# ---------- An IMP at specify with Split and Design recorded reaches the requirements gate ----------
p="$(newproj gate)"
sed -e 's/^Pending — Visualize sub-step\.$/Skipped — no trigger./' -e 's/^Pending$/Kept as one — no trigger./' \
  "$TMP/split/docs/specs/active/IMP-20260917-big.md" > "$p/docs/specs/active/IMP-20260917-big.md"
out="$(python3 "$SPEC_NEXT" "$p/docs/specs/active/IMP-20260917-big.md")"
has "specify: everything recorded → requirements gate" "$out" "Next step: Requirements gate"
has "specify gate: its rule" "$out" "never-flip-without-gate — Never flip"

# ---------- AC-2 second half: rule text is read from the doc at run time, not copied ----------
tree="$TMP/tree"
mkdir -p "$tree/scripts" "$tree/docs"
cp "$SCRIPTS"/{spec-next.py,lifecycle_engine.py,yamlite.py,speclib.py,validate-anchors.py} "$tree/scripts/"
cp -R "$SCRIPTS/../framework" "$tree/framework"
cp "$SCRIPTS/../docs/writing-specs.md" "$tree/docs/"
python3 - "$tree/framework/spec-workflows/spec-lifecycle.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = "**Never** flip to `plan` without explicit human approval of requirements."
assert old in s, "rule sentence moved; update this fixture"
open(p, "w").write(s.replace(old, "**Never** flip to `plan` until the owner has said yes in chat."))
PY
out="$(python3 "$tree/scripts/spec-next.py" "$TMP/gate/docs/specs/active/IMP-20260917-big.md")"
has "AC-2 an edited rule sentence is printed as edited" "$out" "Never flip to \`plan\` until the owner has said yes in chat."
lacks "AC-2 the old sentence is gone" "$out" "without explicit human approval of requirements"

# A reference whose anchor disappeared stops the command (exit 2), which is the prompts' fallback signal.
sed -i.bak 's/<a id="never-flip-without-gate"><\/a>//' "$tree/framework/spec-workflows/spec-lifecycle.md"
set +e
python3 "$tree/scripts/spec-next.py" "$TMP/gate/docs/specs/active/IMP-20260917-big.md" >/dev/null 2>"$TMP/err"; rc=$?
set -e
[ "$rc" -eq 2 ] && grep -q "never-flip-without-gate" "$TMP/err" \
  || { echo "FAIL: AC-2 a vanished anchor exits 2 naming it (rc=$rc)" >&2; fails=$((fails + 1)); }

# ---------- Errors exit 2 so prompts can fall back ----------
set +e
python3 "$SPEC_NEXT" "$TMP/nope.md" >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || { echo "FAIL: a missing spec exits 2 (got $rc)" >&2; fails=$((fails + 1)); }

if [ "$fails" -eq 0 ]; then
  echo "scripts/spec-next.py self-tests passed ✓"
else
  echo "$fails spec-next self-test(s) failed ✗" >&2
  exit 1
fi
