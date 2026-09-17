#!/usr/bin/env bash
# scripts/test/lifecycle-mutations.test.sh
#
# Mutation and edge fixtures for scripts/validate-specs.py: one minimal violating
# project per finding id that validate-specs.test.sh never triggers, plus edge
# cases for links, inventory, traceability and status. Each project must make the
# validator emit the intended id, so a check that silently stops firing fails here.
# Ported from RES-20260914-declarative-lifecycle-schema (IMP-20260917 FR-6).
set -euo pipefail

VALIDATOR="$(cd "$(dirname "$0")/.." && pwd)/validate-specs.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

newproj() { local d="$TMP/$1"; mkdir -p "$d/docs/specs/active" "$d/docs/specs/archived"; printf '%s' "$d"; }

# mkspec root dir filename  [front-matter overrides "key: value" lines on stdin; "-key" drops a default]
mkspec() {
  local root="$1" dir="$2" name="$3" f="$1/docs/specs/$2/$3"
  local over; over="$(cat)"
  python3 - "$f" "${name%.md}" "$over" <<'PY'
import sys
path, stem, over = sys.argv[1], sys.argv[2], sys.argv[3]
fm = {"id": stem, "type": "IMP", "date": "2026-09-01", "status": "specify", "owner": "alex", "risk": "low",
      "affected-repos": ["demo"], "affected-docs": [], "affected-code": [], "skills": ["writing-specs"],
      "model-suggestion": "default"}
stamp = "*Last updated: 2026-09-16*"
body = ""
for line in over.splitlines():
    if not line.strip():
        continue
    if line.startswith("-"):
        fm.pop(line[1:].strip(), None); continue
    if line.startswith("STAMP="):
        stamp = line[6:]; continue
    if line.startswith("BODY="):
        body += line[5:].replace("\\n", "\n") + "\n"; continue
    k, _, v = line.partition(":")
    v = v.strip()
    fm[k.strip()] = [x.strip() for x in v[1:-1].split(",") if x.strip()] if v.startswith("[") else v
out = ["---"]
for k, v in fm.items():
    if isinstance(v, list):
        out.append(f"{k}: []" if not v else f"{k}:")
        out += [f"  - {x}" for x in v]
    else:
        out.append(f"{k}: {v}")
out += ["---", f"# {stem}", stamp, "", body]
open(path, "w").write("\n".join(out))
PY
}

mkagent() { # root name, front-matter body on stdin
  mkdir -p "$1/framework/agents"
  { echo "---"; cat; echo "---"; echo "# $2"; } > "$1/framework/agents/$2.md"
}

expect_id() { # root id
  local out
  out="$(python3 "$VALIDATOR" "$1/docs/specs" 2>/dev/null || true)"
  if ! printf '%s\n' "$out" | grep -q ":$2:"; then
    echo "FAIL: $(basename "$1"): $2 not emitted (got: $(printf '%s' "$out" | cut -d: -f3 | sort -u | tr '\n' ' '))" >&2
    fails=$((fails + 1))
  fi
}

p=$(newproj naming);      printf '' | mkspec "$p" active "imp-bad-name.md";                          expect_id "$p" naming_pattern
p=$(newproj idparity);    echo "id: IMP-20260901-other" | mkspec "$p" active "IMP-20260901-x.md";    expect_id "$p" filename_id_parity
p=$(newproj cond);        echo "-risk" | mkspec "$p" active "IMP-20260901-x.md";                     expect_id "$p" schema_conditional
p=$(newproj condbug);     printf 'type: BUG\n-risk\n' | mkspec "$p" active "BUG-20260901-x.md";      expect_id "$p" schema_conditional
p=$(newproj enumtype);    echo "type: FEAT" | mkspec "$p" active "IMP-20260901-x.md";                expect_id "$p" schema_enum
p=$(newproj enumstatus);  echo "status: review" | mkspec "$p" active "IMP-20260901-x.md";            expect_id "$p" schema_enum
p=$(newproj enummodel);   echo "model-suggestion: huge" | mkspec "$p" active "IMP-20260901-x.md";    expect_id "$p" schema_enum
p=$(newproj enumrisk);    echo "risk: extreme" | mkspec "$p" active "IMP-20260901-x.md";             expect_id "$p" schema_enum
p=$(newproj enumsev);     printf 'type: BUG\n-risk\nseverity: meh\n' | mkspec "$p" active "BUG-20260901-x.md"; expect_id "$p" schema_enum
p=$(newproj missing);     printf -- '-owner\n-skills\n' | mkspec "$p" active "IMP-20260901-x.md";    expect_id "$p" schema_missing_field
p=$(newproj closedfmt);   printf 'status: done\nclosed: soon\n' | mkspec "$p" archived "IMP-20260901-x.md"; expect_id "$p" schema_date_format

p=$(newproj cycle)
echo "depends-on: [IMP-20260901-b]" | mkspec "$p" active "IMP-20260901-a.md"
echo "depends-on: [IMP-20260901-a]" | mkspec "$p" active "IMP-20260901-b.md"
expect_id "$p" deps_cycle
p=$(newproj rule10)
printf 'status: plan\ndepends-on: [IMP-20260901-b]\n' | mkspec "$p" active "IMP-20260901-a.md"
printf '' | mkspec "$p" active "IMP-20260901-b.md"
expect_id "$p" deps_rule_10

p=$(newproj frbad);   echo "STAMP=*Last updated: 2026-13-45*" | mkspec "$p" active "IMP-20260901-x.md"; expect_id "$p" freshness_bad_date
p=$(newproj frmiss);  echo "STAMP=" | mkspec "$p" active "IMP-20260901-x.md";                        expect_id "$p" freshness_missing_stamp
p=$(newproj frstale); echo "STAMP=*Last updated: 2026-01-01*" | mkspec "$p" active "IMP-20260901-x.md"; expect_id "$p" freshness_stale

p=$(newproj trivremoved); printf 'risk: trivial\ndate: 2026-09-17\n' | mkspec "$p" active "IMP-20260917-x.md"; expect_id "$p" trivial_lane_removed

res() { printf -- '-risk\ntype: RES\nmodel-suggestion: deep\nhypothesis: it works\nkill-criteria: ≤8 hours\ncode-location: research/x/\n'; }
p=$(newproj ressrc);   { res; echo "code-location: repo/src/spike"; } | mkspec "$p" active "RES-20260901-x.md";        expect_id "$p" res_code_location_in_src
p=$(newproj resmixed); { res; echo "kill-criteria: 3 iterations or 4 hours"; } | mkspec "$p" active "RES-20260901-x.md"; expect_id "$p" res_kill_criteria_mixed_shape
p=$(newproj resshape); { res; echo "kill-criteria: when bored"; } | mkspec "$p" active "RES-20260901-x.md";         expect_id "$p" res_kill_criteria_unknown_shape
p=$(newproj resdang);  { res; printf 'status: done\nclosed: 2026-09-10\noutcome: promoted-to-IMP-20260901-nope\n'; } | mkspec "$p" archived "RES-20260901-x.md"; expect_id "$p" res_outcome_dangling_promotion
p=$(newproj resinv);   { res; printf 'status: done\nclosed: 2026-09-10\noutcome: maybe\n'; } | mkspec "$p" archived "RES-20260901-x.md"; expect_id "$p" res_outcome_invalid

p=$(newproj reviewbad)
{ printf 'type: CR\ndate: 2026-09-16\nstatus: done\nclosed: 2026-09-16\nrisk: high\n'
  echo 'BODY=## Requirements\n\n- FR-1: The system MUST do one.\n\n## Acceptance Criteria\n\n### AC-1: One (FR-1)\n\nEvidence: test\n\n## Tasks\n\n| # | Description | Status |\n|---|---|---|\n| T1 | One (FR-1; AC-1) | done |\n\n## Closure Evidence\n\n| AC | Evidence |\n|---|---|\n| AC-1 | test |\n\n### Review\n\nRESULT: looks fine to me\n'
} | mkspec "$p" archived "CR-20260916-x.md"
expect_id "$p" review_bad_result

p=$(newproj agentmiss);  printf 'name: rev\ndescription: d\n' | mkagent "$p" rev;                                    expect_id "$p" agent_schema_missing_field
p=$(newproj agentname);  printf 'name: other\ndescription: d\nmodel-suggestion: deep\ntools-allowed:\n  - Read\n' | mkagent "$p" rev; expect_id "$p" agent_filename_name_parity
p=$(newproj agentenum);  printf 'name: rev\ndescription: d\nmodel-suggestion: huge\ntools-allowed:\n  - Read\n' | mkagent "$p" rev; expect_id "$p" agent_schema_enum
p=$(newproj agenttype);  printf 'name: rev\ndescription: d\nmodel-suggestion: deep\ntools-allowed: Read\n' | mkagent "$p" rev; expect_id "$p" agent_schema_type
p=$(newproj agentempty); printf 'name: rev\ndescription: d\nmodel-suggestion: deep\ntools-allowed: []\n' | mkagent "$p" rev; expect_id "$p" agent_schema_empty

# ---- Edge cases ----

p=$(newproj edgecycle3)
echo "depends-on: [IMP-20260901-b]" | mkspec "$p" active "IMP-20260901-a.md"
echo "depends-on: [IMP-20260901-c]" | mkspec "$p" active "IMP-20260901-b.md"
printf 'depends-on: [IMP-20260901-a, IMP-20260901-zz]\nsiblings: [IMP-20260901-a]\n' | mkspec "$p" active "IMP-20260901-c.md"
expect_id "$p" deps_cycle

p=$(newproj edgelinks); mkdir -p "$p/docs/specs/active/sub"; touch "$p/docs/specs/active/sub/there.md"
echo 'BODY=[ok](sub/there.md#frag) [q](sub/there.md?x=1) [anchor](#top) [web](https://x.y) [bad](nope.md#a)\n```\n[in fence](missing.md)\n```\n[t](sub/gone.md "title")' | mkspec "$p" active "IMP-20260901-x.md"
expect_id "$p" link_broken

p=$(newproj edgeinventory); mkdir -p "$p/src"
printf 'affected-code: [src/a.py (new), src/..., ../elsewhere/x.py, <placeholder>, lib/y.py/]\n' | mkspec "$p" active "IMP-20260901-x.md"
printf 'affected-code: [src/a.py, lib/y.py]\n' | mkspec "$p" active "IMP-20260901-y.md"
printf 'affected-code: [src/a.py]\nsiblings: [IMP-20260901-x]\n' | mkspec "$p" active "IMP-20260901-z.md"
printf 'status: done\nclosed: 2026-09-10\naffected-code: [src/a.py, nowhere/b.py]\n' | mkspec "$p" archived "IMP-20260902-w.md"
expect_id "$p" inventory_path_unresolvable
expect_id "$p" active_spec_overlap

p=$(newproj edgetrace)
{ printf 'date: 2026-09-16\nstatus: done\nclosed: 2026-09-16\n'
  echo 'BODY=## Requirements\n\n- FR-1: one\n- **FR-2**: two\n| FR-3 | three |\n\n```\n- FR-9: in a fence\n```\n\n## Acceptance Criteria\n\n### AC-1: covers FR-1 – FR-2\n### AC-3: cites FR-7 (FR-4)\n\n## Tasks\n\n| # | Description |\n|---|---|\n| T1 | FR-1, AC-1 |\n| T2 | only AC-3 |\n\n## Closure Evidence\n\n| AC | Evidence |\n|---|---|\n| AC-1 – AC-2 | test |\n\n### Review\n\n| AC-3 | not evidence |'
} | mkspec "$p" archived "IMP-20260916-x.md"
expect_id "$p" traceability_fr_dangling
expect_id "$p" traceability_fr_uncited
expect_id "$p" traceability_fr_no_task
expect_id "$p" traceability_ac_no_evidence

p=$(newproj edgestatus)
echo 'BODY=## Tasks\n\n| a | b |\n|---|---|' | mkspec "$p" active "IMP-20260901-x.md"
printf 'status: plan\n' | mkspec "$p" archived "IMP-20260901-y.md"
printf -- '-status\n' | mkspec "$p" archived "IMP-20260901-z.md"
expect_id "$p" status_tasks_table
expect_id "$p" status_location
# A fenced example table under `## Tasks` is not a Tasks table (IMP-20260917 D4 #3).
p=$(newproj edgestatusfence)
echo 'BODY=## Tasks\n\n```\n| a | b |\n|---|---|\n```' | mkspec "$p" active "IMP-20260901-x.md"
if python3 "$VALIDATOR" "$p/docs/specs" 2>/dev/null | grep -q ":status_tasks_table:"; then
  echo "FAIL: edgestatusfence: fenced table reported as status_tasks_table" >&2
  fails=$((fails + 1))
fi


# ---- A broken schema fails loudly (IMP-20260917 AC-2) ----
# A copy of the validator beside a mutated lifecycle.yaml; exit 2 naming the rule, never a clean run.
SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$SCRIPTS/../framework/spec-workflows/lifecycle.yaml"
broken_schema() { # $1 desc, $2 python edit over `s` (the schema text), $3 expected stderr pattern
  local d="$TMP/tree-$RANDOM"
  mkdir -p "$d/scripts" "$d/framework/spec-workflows"
  cp "$SCRIPTS/validate-specs.py" "$SCRIPTS/speclib.py" "$SCRIPTS/lifecycle_engine.py" "$SCRIPTS/yamlite.py" "$d/scripts/"
  python3 - "$SCHEMA" "$d/framework/spec-workflows/lifecycle.yaml" "$2" <<'PY'
import sys
s = orig = open(sys.argv[1]).read()
exec(sys.argv[3])
if s == orig:
    sys.exit("fixture edit matched nothing in lifecycle.yaml")
open(sys.argv[2], "w").write(s)
PY
  local p; p=$(newproj "schema-$RANDOM"); printf '' | mkspec "$p" active "IMP-20260901-x.md"
  local err rc=0
  err="$(python3 "$d/scripts/validate-specs.py" "$p/docs/specs" 2>&1 >/dev/null)" || rc=$?
  if [ "$rc" -ne 2 ] || ! printf '%s' "$err" | grep -q -- "$3"; then
    echo "FAIL: $1 (rc=$rc, stderr: $(printf '%s' "$err" | tail -1))" >&2
    fails=$((fails + 1))
  fi
}
broken_schema "unknown op" \
  's = s.replace("when: {not: {matches: [$doc.name, $naming_re]}}", "when: {not: {matchez: [$doc.name, $naming_re]}}")' \
  "naming_pattern: unknown op 'matchez'"
broken_schema "unknown lane" \
  's = s.replace("  - id: res_hypothesis_empty\n    lane: research", "  - id: res_hypothesis_empty\n    lane: researc")' \
  "res_hypothesis_empty: unknown lane 'researc'"
broken_schema "plug-in without implementation" \
  's = s.replace("fn: check_log_closed,", "fn: check_log_closure,")' \
  "'check_log_closure' has no implementation"
broken_schema "implemented plug-in not named" \
  's = s.replace("  - {fn: check_log_closed, args: [root], ids: [log_closed_missing]}\n", "")' \
  "'check_log_closed' is implemented but not named"

if [ "$fails" -ne 0 ]; then echo "lifecycle-mutations: $fails failure(s)" >&2; exit 1; fi
echo "lifecycle-mutations: all ids emitted ✓"
