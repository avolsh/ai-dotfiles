#!/usr/bin/env bash
# scripts/test/validate-specs.test.sh
#
# Self-tests for scripts/validate-specs.py. Builds throwaway spec corpora in a
# temp dir and asserts which findings the validator reports, so checks that must
# fire on malformed input can be proven without planting malformed specs in the
# real corpus (IMP-20260826 FR-7..FR-9).
set -euo pipefail

VALIDATOR="$(cd "$(dirname "$0")/.." && pwd)/validate-specs.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
rc=0
out=""
expect() { # $1 desc, $2 expected rc, $3 actual rc
  if [ "$2" -ne "$3" ]; then
    echo "FAIL: $1 (expected rc=$2, got rc=$3)" >&2
    fails=$((fails + 1))
  fi
}
assert_reports() { # $1 desc, $2 output, $3 grep pattern
  if ! printf '%s' "$2" | grep -q -- "$3"; then
    echo "FAIL: $1 (no finding matching '$3')" >&2
    fails=$((fails + 1))
  fi
}
assert_silent() { # $1 desc, $2 output, $3 grep pattern
  if printf '%s' "$2" | grep -q -- "$3"; then
    echo "FAIL: $1 (unexpected finding matching '$3')" >&2
    fails=$((fails + 1))
  fi
}

# A project the validator can be pointed at: `main` takes an optional path and
# walks up from it, so a temp corpus is validated instead of ai-dotfiles' own.
newproj() { # $1 name -> echoes the project root
  local d="$TMP/$1"
  mkdir -p "$d/docs/specs/active" "$d/docs/specs/archived"
  printf '%s' "$d"
}
run() { # $1 project root — sets $out (findings) and $rc (exit code).
  # Not called in a command substitution: that would run it in a subshell and
  # lose $rc, which is exactly what the first cut of this harness got wrong.
  set +e
  out="$(python3 "$VALIDATOR" "$1/docs/specs" 2>/dev/null)"; rc=$?
  set -e
}

# A schema-complete IMP spec; extra front-matter lines come from stdin.
mkspec() { # $1 root, $2 filename, [extra front-matter on stdin]
  local f="$1/docs/specs/active/$2"
  {
    echo "---"
    echo "id: ${2%.md}"
    echo "type: IMP"
    echo "date: 2026-08-26"
    echo "status: specify"
    echo "owner: alex"
    echo "risk: low"
    echo "affected-repos:"
    echo "  - demo"
    echo "affected-docs: []"
    echo "affected-code: []"
    echo "skills:"
    echo "  - writing-specs"
    echo "model-suggestion: default"
    cat
    echo "---"
    echo "# ${2%.md}"
    echo "*Last updated: 2026-08-26*"
  } > "$f"
}

# ---------- FR-7: the renamed field is type-checked ----------
p="$(newproj listfields)"
mkspec "$p" "IMP-20260826-bare-domain-refs.md" <<'EOF'
domain-refs: REQ-PCE-001
EOF
run "$p"; rc7=$rc
expect "FR-7 a corpus with a bare-string domain-refs exits non-zero" 1 "$rc7"
assert_reports "FR-7 domain-refs must be type-checked as a list" "$out" "field 'domain-refs' must be a list"

# The retired name must not be type-checked any more.
p="$(newproj oldfield)"
mkspec "$p" "IMP-20260826-bare-cites-reqs.md" <<'EOF'
cites-reqs: REQ-PCE-001
EOF
run "$p"
assert_silent "FR-7 cites-reqs is no longer a known list field" "$out" "field 'cites-reqs' must be a list"

# ---------- AC-4: a BUG spec written from the template validates ----------
p="$(newproj bugtemplate)"
tpl="$(cd "$(dirname "$0")/../.." && pwd)/framework/spec-workflows/templates/BUG-TEMPLATE.md"
sed -e 's/BUG-YYYYMMDD-<kebab-case-title>/BUG-20260826-demo/' \
    -e 's/^date: YYYY-MM-DD/date: 2026-08-26/' \
    -e 's/<github-handle>/alex/' \
    -e 's/^severity: .*/severity: low/' \
    -e 's/<repo-name>/demo/' \
    -e 's|^  - <path>|  - src/demo.ts|' \
    -e 's/<project-testing-skill>/test-driven-development/' \
    -e 's/^# BUG-YYYYMMDD-<title>/# BUG-20260826-demo/' \
    -e 's/^\*Last updated: YYYY-MM-DD\*/*Last updated: 2026-08-26*/' \
    "$tpl" > "$p/docs/specs/active/BUG-20260826-demo.md"
run "$p"
assert_silent "AC-4 a filled BUG template reports no missing affected-docs" "$out" "required field 'affected-docs' missing"
# IMP-20260829 AC-5 — the same template, judged against the whole schema
# rather than one field: a BUG written from it must not be born invalid.
assert_silent "AC-5 a filled BUG template is missing no required field" "$out" "schema_missing_field"

# ---------- FR-8: REQ-ID collisions inside one domain baseline ----------
mkbaseline() { # $1 root, $2 filename, [body on stdin]
  mkdir -p "$1/docs/domain"
  { echo "# ${2%.md}"; echo "*Last updated: 2026-08-26*"; echo; cat; } > "$1/docs/domain/$2"
}

p="$(newproj reqids)"
mkspec "$p" "IMP-20260826-anchor.md" </dev/null
mkbaseline "$p" "demo.md" <<'EOF'
## Functional Requirements

- **MUST** do the first thing. *(REQ-DEMO-001)*
- **MUST** do a second thing, unrelated. *(REQ-DEMO-001; added by IMP-20260826-demo)*
- **MUST** do a third thing, correctly numbered. *(REQ-DEMO-002)*
EOF
run "$p"
expect "FR-8 a baseline with a duplicate REQ-ID exits non-zero" 1 "$rc"
assert_reports "FR-8 the duplicate is reported with its file" "$out" "docs/domain/demo.md"
assert_reports "FR-8 the duplicate is reported with its ID" "$out" "REQ-DEMO-001"
assert_silent "FR-8 a correctly numbered ID is not reported" "$out" "REQ-DEMO-002"

# A citation is not a definition: an ID named in prose, in backticks, or in a
# cross-baseline reference must not count as a second claim on the number.
p="$(newproj reqcites)"
mkspec "$p" "IMP-20260826-anchor.md" </dev/null
mkbaseline "$p" "cites.md" <<'EOF'
## Functional Requirements

- **MUST** persist metadata using the lifecycle defined by `REQ-SP-001`. *(REQ-DEMO-010)*
- **MUST** reuse the resolver REQ-DEMO-010 introduced, without redefining it. *(REQ-DEMO-011)*
EOF
run "$p"
expect "FR-8 a baseline whose repeats are citations is clean" 0 "$rc"

# Tombstones and supersession annotations are history, not definitions —
# docs/req-id-lifecycle.md requires the retired ID to stay in the file.
p="$(newproj reqhistory)"
mkspec "$p" "IMP-20260826-anchor.md" </dev/null
mkbaseline "$p" "history.md" <<'EOF'
## Functional Requirements

- **MUST** *(retired)* do the old thing. *(REQ-DEMO-020 superseded by REQ-DEMO-021)*
- **MUST** do the replacement thing. *(REQ-DEMO-020; amended by IMP-20260826-demo)*
EOF
run "$p"
expect "FR-8 a superseded annotation is not a second definition" 0 "$rc"

# A project with no docs/domain/ at all is a no-op, not a crash — ai-dotfiles
# has none, and the validator runs there on every `make check`.
p="$(newproj nodomain)"
mkspec "$p" "IMP-20260826-anchor.md" </dev/null
run "$p"
expect "FR-8 a project without docs/domain/ validates cleanly" 0 "$rc"

# ---------- FR-9: an inventory the guard cannot read ----------
# spec-status-guard.sh resolves affected-code/-docs from the project root that
# owns docs/specs/active. A path written any other way leases nothing.
p="$(newproj inventory)"
mkdir -p "$p/src" "$p/framework/hooks"
mkspec "$p" "IMP-20260826-workspace-relative.md" <<'EOF'
EOF
python3 - "$p/docs/specs/active/IMP-20260826-workspace-relative.md" <<'PYEOF'
import pathlib, sys
f = pathlib.Path(sys.argv[1])
f.write_text(f.read_text().replace(
    "affected-code: []",
    "affected-code:\n  - env/ai-dotfiles/framework/hooks/spec-status-guard.sh"))
PYEOF
run "$p"
expect "AC-6 a workspace-relative inventory path exits non-zero" 1 "$rc"
assert_reports "AC-6 the unresolvable path is named" "$out" "env/ai-dotfiles/framework/hooks/spec-status-guard.sh"

# The guard's own normalization applies: annotations, ellipses and trailing
# slashes are stripped before the path is judged, so a planned-but-absent file
# under an existing tree is a lease the guard can see.
p="$(newproj inventory_ok)"
mkdir -p "$p/src" "$p/framework/hooks"
mkspec "$p" "IMP-20260826-resolvable.md" <<'EOF'
EOF
python3 - "$p/docs/specs/active/IMP-20260826-resolvable.md" <<'PYEOF'
import pathlib, sys
f = pathlib.Path(sys.argv[1])
f.write_text(f.read_text().replace(
    "affected-code: []",
    "affected-code:\n  - src/does-not-exist-yet.ts (new)\n  - src/...\n  - framework/hooks/"))
PYEOF
run "$p"
expect "FR-9 annotated, elliptical and trailing-slash paths under an existing tree are clean" 0 "$rc"

# Only active specs hold leases: spec-status-guard.sh reads docs/specs/active/
# and nothing else, so an archived spec's inventory is inert. This also keeps
# cross-repo entries — which have no project-root-relative form — out of the
# findings without depending on a sibling repo being present on disk.
p="$(newproj inventory_archived)"
mkdir -p "$p/src"
mkspec "$p" "IMP-20260826-anchor.md" </dev/null
cat > "$p/docs/specs/archived/IMP-20260101-archived.md" <<'EOF'
---
id: IMP-20260101-archived
type: IMP
date: 2026-01-01
status: done
owner: alex
risk: low
affected-repos:
  - demo
affected-docs:
  - src/github.com/tobeverse/other-repo/docs/design-system.md
affected-code: []
skills:
  - writing-specs
model-suggestion: default
---
# IMP-20260101-archived
*Last updated: 2026-01-01*
EOF
run "$p"
expect "FR-9 an archived spec's inventory is not judged" 0 "$rc"
assert_silent "FR-9 no finding for the archived cross-repo path" "$out" "inventory_path_unresolvable"

# ---------- FR-1..FR-3: english_only tells quoted data from foreign prose ----------
# Drawn from tobevisit-content's real findings (IMP-20260829): a Ukrainian corpus
# cannot describe itself if quoting its own subject is a finding, and a glyph is
# not a language. What must still fail is a sentence written in another script.

# AC-1 — quoted domain data: an inline-code run and a fenced block.
p="$(newproj enquoted)"
mkspec "$p" "IMP-20260829-quoted-data.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260829-quoted-data.md" <<'EOF'

## Summary

The geography example writes `Берестейський проспект`, and the languages fixture
restores the `Українська` endonym.

```json
{ "weekdayDescriptions": ["понеділок: 10:00-18:00"] }
```
EOF
run "$p"
assert_silent "AC-1 domain data in backticks is not a finding" "$out" "english_only"
expect "AC-1 a spec quoting its own corpus validates cleanly" 0 "$rc"

# AC-2 — glyphs: outside every letter category, so outside the rule.
p="$(newproj englyphs)"
mkspec "$p" "IMP-20260829-glyphs.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260829-glyphs.md" <<'EOF'

## Summary

The queue renders ⏳ while a job waits, the map pin is 📍, an unchecked box is ⬜,
the download affordance is ⤓, and the nav still uses emoji (🏳️🔤🏷️📝).
EOF
run "$p"
assert_silent "AC-2 bare glyphs and emoji are not a language" "$out" "english_only"
expect "AC-2 a spec quoting UI glyphs validates cleanly" 0 "$rc"

# AC-3 — the counter-example. Narrowing the check must not retire it: an
# unquoted run of non-Latin letters in prose is what the rule was written for.
p="$(newproj enprose)"
mkspec "$p" "IMP-20260829-foreign-prose.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260829-foreign-prose.md" <<'EOF'

## Summary

Ця специфікація написана українською мовою, а не англійською.
EOF
run "$p"
expect "AC-3 prose in another language exits non-zero" 1 "$rc"
assert_reports "AC-3 the finding names the file" "$out" "IMP-20260829-foreign-prose.md"
assert_reports "AC-3 the finding is an english_only one" "$out" "english_only"
assert_reports "AC-3 the excerpt is carried in the message" "$out" "специфікація"

# ---------- FR-1..FR-3: two active specs aimed at the same file ----------
# The 2026-08-26 batch, reconstructed. `mkspec` already emits `affected-docs: []`;
# the parser takes the last assignment of a key, so the heredoc below overrides it.

# AC-1 — the pair that was missed: two specs against what the <=5 cap counts,
# sharing two affected-docs entries, naming neither the other.
p="$(newproj overlapbare)"
mkspec "$p" "IMP-20260826-plan-file-count-realism.md" <<'EOF'
affected-docs:
  - docs/authoring-steps.md
  - docs/writing-specs.md
EOF
mkspec "$p" "IMP-20260826-decomposition-and-staleness-procedures.md" <<'EOF'
affected-docs:
  - docs/authoring-steps.md
  - docs/writing-specs.md
  - docs/spec-lifecycle.md
EOF
run "$p"
expect "AC-1 an undeclared collision exits non-zero" 1 "$rc"
assert_reports "AC-1 the finding is an overlap one" "$out" "active_spec_overlap"
assert_reports "AC-1 the finding names the other spec id" "$out" "IMP-20260826-decomposition-and-staleness-procedures"
assert_reports "AC-1 the finding names the first shared path" "$out" "docs/authoring-steps.md"
# FR-3 — every shared path, not just the first: one finding must carry both.
assert_reports "FR-3 the finding names every shared path" "$out" "docs/authoring-steps.md, docs/writing-specs.md"

# FR-1 — affected-code is an inventory too, and collides the same way.
p="$(newproj overlapcode)"
mkspec "$p" "IMP-20260826-a.md" <<'EOF'
affected-code:
  - scripts/validate-specs.py
EOF
mkspec "$p" "IMP-20260826-b.md" <<'EOF'
affected-code:
  - scripts/validate-specs.py
EOF
run "$p"
assert_reports "FR-1 a shared affected-code path collides too" "$out" "scripts/validate-specs.py"

# AC-2 — the legitimate pair: three shared affected-docs entries, declared by
# `siblings:` on one and `depends-on:` on the other. A declared relationship is
# the Split check's own output, so the check must stay silent on it.
p="$(newproj overlaplinked)"
mkspec "$p" "IMP-20260826-ui-surface-closure-evidence.md" <<'EOF'
affected-docs:
  - docs/spec-lifecycle.md
  - docs/authoring-steps.md
  - docs/acceptance-criteria-patterns.md
  - docs/rule-canonical-map.md
EOF
mkspec "$p" "IMP-20260826-decomposition-and-staleness-procedures.md" <<'EOF'
affected-docs:
  - docs/authoring-steps.md
  - docs/spec-lifecycle.md
  - docs/rule-canonical-map.md
siblings:
  - IMP-20260826-ui-surface-closure-evidence
depends-on:
  - IMP-20260826-ui-surface-closure-evidence
EOF
run "$p"
assert_silent "AC-2 a declared relationship reports no overlap" "$out" "active_spec_overlap"
expect "AC-2 the linked pair validates cleanly" 0 "$rc"

# FR-2 — "in either direction": the declaration sits on one spec only, and the
# other names nothing. Reading the pair from the undeclared side must be silent.
p="$(newproj overlaponeway)"
mkspec "$p" "IMP-20260826-declared.md" <<'EOF'
affected-docs:
  - docs/writing-specs.md
siblings:
  - IMP-20260826-silent
EOF
mkspec "$p" "IMP-20260826-silent.md" <<'EOF'
affected-docs:
  - docs/writing-specs.md
EOF
run "$p"
assert_silent "FR-2 a one-sided siblings: entry silences both directions" "$out" "active_spec_overlap"

# OS-4 — an archived spec is inert: only docs/specs/active/ holds a lease.
p="$(newproj overlaparchived)"
mkspec "$p" "IMP-20260826-live.md" <<'EOF'
affected-docs:
  - docs/writing-specs.md
EOF
mv "$p/docs/specs/active/IMP-20260826-live.md" "$p/docs/specs/archived/"
mkspec "$p" "IMP-20260830-alone.md" <<'EOF'
affected-docs:
  - docs/writing-specs.md
EOF
run "$p"
assert_silent "OS-4 an active spec does not collide with an archived one" "$out" "active_spec_overlap"

# ---------- FR-10: a Figma frame reference under ## Design carries a two-part ID ----------
# The alt text is the only part of a Figma frame that lives in the repository,
# so it is where a superseded one-part ID reaches the corpus.

FIGMA_ASSET="https://www.figma.com/api/mcp/asset/1234"
FIGMA_NODE="https://www.figma.com/design/KEY?node-id=51-2"

# AC-4 — a one-part ID under ## Design is rejected.
p="$(newproj frameidold)"
mkspec "$p" "IMP-20260902-old-frame-id.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260902-old-frame-id.md" <<EOF

## Design

[![[W-59] Ingestion · Step 1 — Console · month exhausted]($FIGMA_ASSET)]($FIGMA_NODE)
EOF
run "$p"
expect "FR-10 a one-part frame ID exits non-zero" 1 "$rc"
assert_reports "FR-10 the finding is a frame-id one" "$out" "figma_frame_id"
assert_reports "FR-10 the finding names the offending ID" "$out" "W-59"

# AC-4 — the two-part form passes.
p="$(newproj frameidnew)"
mkspec "$p" "IMP-20260902-new-frame-id.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260902-new-frame-id.md" <<EOF

## Design

[![[W-11.03] Ingestion · Step 1 — Console · month exhausted]($FIGMA_ASSET)]($FIGMA_NODE)
EOF
run "$p"
assert_silent "FR-10 a two-part frame ID reports nothing" "$out" "figma_frame_id"
expect "FR-10 the two-part spec validates cleanly" 0 "$rc"

# FR-10 — a Figma embed whose alt carries no ID tag at all is a frame reference too.
p="$(newproj frameidnone)"
mkspec "$p" "IMP-20260902-no-frame-id.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260902-no-frame-id.md" <<EOF

## Design

[![Ingestion console]($FIGMA_ASSET)]($FIGMA_NODE)
EOF
run "$p"
assert_reports "FR-10 a Figma embed with no ID tag is reported" "$out" "figma_frame_id"

# FR-10 — a non-Figma image under ## Design is not a frame reference.
p="$(newproj frameidplain)"
mkspec "$p" "IMP-20260902-plain-image.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260902-plain-image.md" <<'EOF'

## Design

![Pipeline overview](./diagrams/pipeline.svg)
EOF
run "$p"
assert_silent "FR-10 a plain image is left alone" "$out" "figma_frame_id"

# FR-10 — scope is ## Design; prose quoting an old ID elsewhere is untouched.
p="$(newproj frameidscope)"
mkspec "$p" "IMP-20260902-out-of-design.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260902-out-of-design.md" <<EOF

## Current State

[![[W-59] Ingestion · Step 1 — Console]($FIGMA_ASSET)]($FIGMA_NODE)

## Design

Skipped — no UI surface.
EOF
run "$p"
assert_silent "FR-10 an embed outside ## Design is out of scope" "$out" "figma_frame_id"

# FR-7 — archived specs keep the IDs they were written with.
p="$(newproj frameidarchived)"
mkspec "$p" "IMP-20260820-archived-frame-id.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260820-archived-frame-id.md" <<EOF

## Design

[![[W-59] Ingestion · Step 1 — Console]($FIGMA_ASSET)]($FIGMA_NODE)
EOF
mv "$p/docs/specs/active/IMP-20260820-archived-frame-id.md" "$p/docs/specs/archived/"
run "$p"
assert_silent "FR-7 an archived spec's one-part ID is never reported" "$out" "figma_frame_id"

# IMP-20260914 FR-14 — a breakpoint suffix and a behaviour ID are both two-part
# frame references; neither is mistaken for a superseded one-part ID.
p="$(newproj frameidresponsive)"
mkspec "$p" "IMP-20260914-responsive-frame-id.md" </dev/null
cat >> "$p/docs/specs/active/IMP-20260914-responsive-frame-id.md" <<EOF

## Design

[![[W-03.02] Places — List · Map view · lg]($FIGMA_ASSET)]($FIGMA_NODE)

[![[B-01.03] Header search · Step 3 — Filter open · base]($FIGMA_ASSET)]($FIGMA_NODE)
EOF
run "$p"
assert_silent "FR-14 a breakpoint-suffixed and a behaviour frame ID report nothing" "$out" "figma_frame_id"
expect "FR-14 the responsive spec validates cleanly" 0 "$rc"

# ---------- IMP-20260914-spec-traceability-checks ----------
# Dated after the cut-off so the checks judge it; the body comes from stdin.
mktrace() { # $1 root, $2 filename, $3 type, $4 status, [$5 date]
  local f="$1/docs/specs/active/$2"
  {
    echo "---"
    echo "id: ${2%.md}"
    echo "type: $3"
    echo "date: ${5:-2027-01-01}"
    echo "status: $4"
    echo "owner: alex"
    echo "risk: low"
    echo "affected-repos:"
    echo "  - demo"
    echo "affected-docs: []"
    echo "affected-code: []"
    echo "skills:"
    echo "  - writing-specs"
    echo "model-suggestion: default"
    echo "---"
    echo "# ${2%.md}"
    echo "*Last updated: 2026-09-15*"
    cat
  } > "$f"
}
requirements_1_3() {
  cat <<'EOF'

## Requirements

- FR-1: The system MUST do one.
- FR-2: The system MUST do two.
- FR-3: The system MUST do three.

## Acceptance Criteria
EOF
}

# FR-1 / AC-1 — an FR no AC cites is named at the line it is defined on.
p="$(newproj traceuncited)"
{ requirements_1_3; cat <<'EOF'

### AC-1: One (FR-1)

Evidence: test

### AC-2: Two (`FR-2`)

Evidence: test
EOF
} | mktrace "$p" "CR-20270101-uncited.md" CR specify
run "$p"
fr3_line="$(grep -n '^- FR-3:' "$p/docs/specs/active/CR-20270101-uncited.md" | cut -d: -f1)"
assert_reports "AC-1 an FR no AC cites is named at its line" "$out" "CR-20270101-uncited.md:$fr3_line:traceability_fr_uncited:.*FR-3"
[ "$(printf '%s\n' "$out" | grep -c traceability_)" -eq 1 ] || {
  echo "FAIL: AC-1 exactly one traceability finding (got: $out)" >&2; fails=$((fails + 1)); }

p="$(newproj tracerange)"
{ requirements_1_3; printf '\n### AC-1: All (FR-1 – FR-3)\n\nEvidence: test\n'; } \
  | mktrace "$p" "CR-20270101-range.md" CR specify
run "$p"
assert_silent "AC-1 a range citation covers every FR in it" "$out" "traceability_"

p="$(newproj traceres)"
{ requirements_1_3; printf '\n### AC-1: One (FR-1)\n'; } \
  | mktrace "$p" "RES-20270101-exempt.md" RES specify
run "$p"
assert_silent "AC-1 a RES spec is exempt" "$out" "traceability_"

# FR-2 / AC-2 — a citation of an undefined FR is named at the AC's line.
p="$(newproj tracedangling)"
{ requirements_1_3; printf '\n### AC-1: All (FR-1 – FR-3)\n\n### AC-2: Ghost (FR-9)\n\nEvidence: test\n'; } \
  | mktrace "$p" "CR-20270101-dangling.md" CR specify
run "$p"
ac2_line="$(grep -n '^### AC-2' "$p/docs/specs/active/CR-20270101-dangling.md" | cut -d: -f1)"
assert_reports "AC-2 a dangling FR citation is named at the AC's line" "$out" "CR-20270101-dangling.md:$ac2_line:traceability_fr_dangling:.*FR-9"

# FR-5 — a spec dated before the cut-off is not judged.
p="$(newproj tracehistory)"
{ requirements_1_3; printf '\n### AC-1: One (FR-1)\n\n### AC-2: Ghost (FR-9)\n'; } \
  | mktrace "$p" "CR-20260801-history.md" CR specify 2026-08-01
run "$p"
assert_silent "FR-5 a spec dated before the cut-off is not judged" "$out" "traceability_"

# FR-3 / AC-3 — from `plan` on, every FR is cited by a task row directly; a
# row citing only AC-2 (which cites FR-2) does not cover FR-2.
tasks_omit_fr2() {
  requirements_1_3
  cat <<'EOF'

### AC-1: One and three (FR-1, FR-3)

### AC-2: Two (FR-2)

## Tasks

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Build one and three (FR-1, FR-3; AC-1) | `a.py` | — | — | tdd | fast | ☐ pending |
| T2 | Build two (AC-2) | `b.py` | — | T1 | tdd | fast | ☐ pending |
EOF
}
p="$(newproj tracetasks)"
tasks_omit_fr2 | mktrace "$p" "CR-20270101-tasks.md" CR plan
run "$p"
fr2_line="$(grep -n '^- FR-2:' "$p/docs/specs/active/CR-20270101-tasks.md" | cut -d: -f1)"
assert_reports "AC-3 at plan, an FR no task cites directly is named" "$out" "CR-20270101-tasks.md:$fr2_line:traceability_fr_no_task:.*FR-2"
[ "$(printf '%s\n' "$out" | grep -c traceability_)" -eq 1 ] || {
  echo "FAIL: AC-3 exactly one traceability finding at plan (got: $out)" >&2; fails=$((fails + 1)); }

p="$(newproj tracetasksspecify)"
tasks_omit_fr2 | mktrace "$p" "CR-20270101-tasks.md" CR specify
run "$p"
assert_silent "AC-3 the same body at specify reports no task coverage" "$out" "traceability_"

# FR-4 / AC-3 — at `done`, every AC has a Closure Evidence row.
closure_omits_ac2() {
  requirements_1_3
  cat <<'EOF'

### AC-1: One and three (FR-1, FR-3)

### AC-2: Two (FR-2)

## Tasks

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Build everything (FR-1 – FR-3; AC-1, AC-2) | `a.py` | — | — | tdd | fast | ☑ done |

## Closure Evidence

| AC | Evidence |
|---|---|
| AC-1 | `a.test.py` green. |
| Review | Not required — risk low. |
EOF
}
p="$(newproj traceclosure)"
closure_omits_ac2 | mktrace "$p" "CR-20270101-closure.md" CR done
mv "$p/docs/specs/active/CR-20270101-closure.md" "$p/docs/specs/archived/"
run "$p"
ac2_def_line="$(grep -n '^### AC-2' "$p/docs/specs/archived/CR-20270101-closure.md" | cut -d: -f1)"
assert_reports "AC-3 at done, an AC with no Closure Evidence row is named" "$out" "CR-20270101-closure.md:$ac2_def_line:traceability_ac_no_evidence:.*AC-2"
[ "$(printf '%s\n' "$out" | grep -c traceability_)" -eq 1 ] || {
  echo "FAIL: AC-3 exactly one traceability finding at done (got: $out)" >&2; fails=$((fails + 1)); }

for st in specify in-progress; do
  p="$(newproj "traceclosure$st")"
  closure_omits_ac2 | mktrace "$p" "CR-20270101-closure.md" CR "$st"
  run "$p"
  assert_silent "AC-3 the same body at $st reports no closure coverage" "$out" "traceability_ac_no_evidence"
done

# ---------- IMP-20260914-mandatory-review-for-high-risk ----------
# A high-tier spec at `done`, dated on the cut-off so the check judges it.
# $3 is the risk tier; the Closure Evidence body comes from stdin.
mkreview() { # $1 root, $2 filename, $3 risk, [$4 date]
  local f="$1/docs/specs/active/$2"
  {
    echo "---"
    echo "id: ${2%.md}"
    echo "type: CR"
    echo "date: ${4:-2026-09-16}"
    echo "status: done"
    echo "owner: alex"
    echo "risk: $3"
    echo "affected-repos:"
    echo "  - demo"
    echo "affected-docs: []"
    echo "affected-code: []"
    echo "skills:"
    echo "  - writing-specs"
    echo "model-suggestion: default"
    echo "---"
    echo "# ${2%.md}"
    echo "*Last updated: 2026-09-16*"
    echo ""
    echo "## Requirements"
    echo ""
    echo "- FR-1: The system MUST do one."
    echo ""
    echo "## Acceptance Criteria"
    echo ""
    echo "### AC-1: One (FR-1)"
    echo ""
    echo "Evidence: test"
    echo ""
    echo "## Tasks"
    echo ""
    echo "| # | Description | Status |"
    echo "|---|---|---|"
    echo "| T1 | One (FR-1; AC-1) | done |"
    echo ""
    echo "## Closure Evidence"
    echo ""
    echo "| AC | Evidence |"
    echo "|---|---|"
    echo "| AC-1 | test |"
    cat
  } > "$f"
}

review_ok() { # a complete three-finding review
  cat <<'EOF'

### Review

RESULT: 3 findings / 2 applied / 1 rejected — run 2026-09-16 against `a1b2c3d^..e4f5a6b`, sub-agent.

| # | Finding | Disposition |
|---|---|---|
| 1 | `a.py:1` → FR-1 violated: one — contract | applied — `a.py:2` |
| 2 | `b.py:3` → FR-1 violated: two — coverage | applied — `b.py:4` |
| 3 | `c.py:5` → FR-1 violated: three — altitude | rejected — out of scope here |
EOF
}

review_missing_disposition() { # row 2's Disposition cell is empty
  cat <<'EOF'

### Review

RESULT: 3 findings / 2 applied / 1 rejected — run 2026-09-16 against `a1b2c3d^..e4f5a6b`, sub-agent.

| # | Finding | Disposition |
|---|---|---|
| 1 | `a.py:1` → FR-1 violated: one — contract | applied — `a.py:2` |
| 2 | `b.py:3` → FR-1 violated: two — coverage |  |
| 3 | `c.py:5` → FR-1 violated: three — altitude | rejected — out of scope here |
EOF
}

review_waived() {
  cat <<'EOF'

### Review

RESULT: WAIVED — by alexvolsh 2026-09-16: shipping ahead of the release freeze. No reviewer run.
EOF
}

review_waived_no_reason() {
  cat <<'EOF'

### Review

RESULT: WAIVED — by alexvolsh 2026-09-16. No reviewer run.
EOF
}

# AC-1 — a high-tier spec at `done` with no `### Review` at all.
p="$(newproj reviewmissing)"
printf '' | mkreview "$p" "CR-20270101-noreview.md" high
run "$p"
assert_reports "AC-1 a high-tier done spec with no ### Review is named" "$out" "CR-20270101-noreview.md:.*:review_missing:"
[ "$(printf '%s\n' "$out" | grep -c 'review_')" -eq 1 ] || {
  echo "FAIL: AC-1 exactly one review finding (got: $out)" >&2; fails=$((fails + 1)); }

# AC-1 — the same body at medium risk is not judged.
p="$(newproj reviewmedium)"
printf '' | mkreview "$p" "CR-20270101-noreview.md" medium
run "$p"
assert_silent "AC-1 the same spec at risk: medium is silent" "$out" "review_"

# AC-1 — severity, not risk, can put a spec in the tier.
p="$(newproj reviewseverity)"
printf '' | mkreview "$p" "CR-20270101-sev.md" medium
sed -i.bak 's/^risk: medium$/risk: medium\nseverity: critical/' "$p/docs/specs/active/CR-20270101-sev.md"
rm -f "$p/docs/specs/active/CR-20270101-sev.md.bak"
run "$p"
assert_reports "AC-1 severity: critical puts a medium-risk spec in the tier" "$out" "CR-20270101-sev.md:.*:review_missing:"

# FR-6 — a spec dated before the cut-off is not judged.
p="$(newproj reviewcutoff)"
printf '' | mkreview "$p" "CR-20260101-old.md" high 2026-09-15
run "$p"
assert_silent "FR-6 a spec dated before the cut-off is not judged" "$out" "review_"

# FR-6 — earlier statuses are silent.
for st in specify plan in-progress; do
  p="$(newproj "reviewstatus$st")"
  printf '' | mkreview "$p" "CR-20270101-noreview.md" high
  sed -i.bak "s/^status: done$/status: $st/" "$p/docs/specs/active/CR-20270101-noreview.md"
  rm -f "$p/docs/specs/active/CR-20270101-noreview.md.bak"
  run "$p"
  assert_silent "FR-6 a high-tier spec at $st is silent" "$out" "review_"
done

# AC-2 — a complete review is silent; one empty Disposition is named by row.
p="$(newproj reviewcomplete)"
review_ok | mkreview "$p" "CR-20270101-review.md" high
run "$p"
assert_silent "AC-2 a fully dispositioned review is silent" "$out" "review_"

p="$(newproj reviewundisp)"
review_missing_disposition | mkreview "$p" "CR-20270101-review.md" high
run "$p"
disp_line="$(grep -n 'two — coverage' "$p/docs/specs/active/CR-20270101-review.md" | cut -d: -f1)"
assert_reports "AC-2 an empty Disposition cell is named at its row" "$out" "CR-20270101-review.md:$disp_line:review_no_disposition:.*2"
[ "$(printf '%s\n' "$out" | grep -c 'review_')" -eq 1 ] || {
  echo "FAIL: AC-2 exactly one review finding (got: $out)" >&2; fails=$((fails + 1)); }

# FR-2 — the run header carries date, range and harness, or the result is flagged.
p="$(newproj reviewheader)"
{ cat <<'EOF'

### Review

RESULT: PASS — looks fine to me

EOF
} | mkreview "$p" "CR-20270101-header.md" high
run "$p"
assert_reports "FR-2 a PASS with no run header is named" "$out" "CR-20270101-header.md:.*:review_header_incomplete:"

p="$(newproj reviewpassok)"
{ cat <<'EOF'

### Review

RESULT: PASS — run 2026-09-16 against `a1b2c3d^..e4f5a6b`, empty-context session.

EOF
} | mkreview "$p" "CR-20270101-pass.md" high
run "$p"
assert_silent "FR-2 a complete PASS needs no findings table" "$out" "review_"

# FR-9 — a declared count that disagrees with the table means a truncated reply.
p="$(newproj reviewcount)"
{ cat <<'EOF'

### Review

RESULT: 3 findings / 1 applied / 0 rejected — run 2026-09-16 against `a1b2c3d^..e4f5a6b`, sub-agent.

| # | Finding | Disposition |
|---|---|---|
| 1 | `a.py:1` → FR-1 violated: one — contract | applied — `a.py:2` |
EOF
} | mkreview "$p" "CR-20270101-count.md" high
run "$p"
assert_reports "FR-9 a declared count the table contradicts is named" "$out" "CR-20270101-count.md:.*:review_count_mismatch:.*3 finding"
[ "$(printf '%s\n' "$out" | grep -c 'review_')" -eq 1 ] || {
  echo "FAIL: FR-9 exactly one review finding for a count mismatch (got: $out)" >&2; fails=$((fails + 1)); }

# AC-5 — a waiver naming a human and a reason is silent; without a reason it is not.
p="$(newproj reviewwaived)"
review_waived | mkreview "$p" "CR-20270101-waived.md" high
run "$p"
assert_silent "AC-5 a complete waiver is silent" "$out" "review_"

p="$(newproj reviewwaivedbad)"
review_waived_no_reason | mkreview "$p" "CR-20270101-waived.md" high
run "$p"
assert_reports "AC-5 a waiver with no reason is named" "$out" "CR-20270101-waived.md:.*:review_waiver_incomplete:"
[ "$(printf '%s\n' "$out" | grep -c 'review_')" -eq 1 ] || {
  echo "FAIL: AC-5 exactly one review finding for a bare waiver (got: $out)" >&2; fails=$((fails + 1)); }

# Review cycle 1 findings — regressions the cold review caught.

# F1 — an escaped pipe inside a Finding cell must not shift the columns.
p="$(newproj reviewescapedpipe)"
{ cat <<'EOF'

### Review

RESULT: 1 findings / 1 applied / 0 rejected — run 2026-09-16 against `a1b2c3d^..e4f5a6b`, sub-agent.

| # | Finding | Disposition |
|---|---|---|
| 1 | `a.py:1` → FR-1 violated: `severity: high \| critical` is misread — bugs | applied — `a.py:2` |
EOF
} | mkreview "$p" "CR-20270101-pipe.md" high
run "$p"
assert_silent "F1 an escaped pipe in a Finding cell does not shift the Disposition" "$out" "review_"

# F2 — `RESULT:` must be the first non-blank line of the sub-section.
p="$(newproj reviewprosefirst)"
{ cat <<'EOF'

### Review

The reviewer was happy with this one.

RESULT: PASS — run 2026-09-16 against `a1b2c3d^..e4f5a6b`, sub-agent.
EOF
} | mkreview "$p" "CR-20270101-prose.md" high
run "$p"
assert_reports "F2 prose before the RESULT: line is named" "$out" "CR-20270101-prose.md:.*:review_no_result:"

# F3 — the tier is set by risk and severity alone; no type is exempt.
p="$(newproj reviewres)"
printf '' | mkreview "$p" "RES-20270101-spike.md" high
sed -i.bak 's/^type: CR$/type: RES/' "$p/docs/specs/active/RES-20270101-spike.md"
rm -f "$p/docs/specs/active/RES-20270101-spike.md.bak"
run "$p"
assert_reports "F3 a high-risk RES spec is judged like any other type" "$out" "RES-20270101-spike.md:.*:review_missing:"

# F5 — a worked example in `## Design` must not be read as the section itself.
# Before the fix, `_h2_section_lines` matched the fenced `## Closure Evidence`
# heading inside Design and never reached the real section, so a spec with no
# `### Review` at all passed by borrowing the example's.
p="$(newproj reviewfencedexample)"
{ cat <<'EOF'
EOF
} | mkreview "$p" "CR-20270101-fenced.md" high
python3 - "$p/docs/specs/active/CR-20270101-fenced.md" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1]); s = f.read_text()
example = """
## Design

The shape a closure record takes:

```markdown
## Closure Evidence

| AC | Evidence |
|---|---|
| AC-1 | test |

### Review

RESULT: PASS — run 2026-09-16 against `a^..b`, sub-agent.
```
"""
f.write_text(s.replace("\n## Closure Evidence", example + "\n## Closure Evidence", 1))
PY
run "$p"
assert_reports "F5 a fenced Closure Evidence example is not read as the section" "$out" "CR-20270101-fenced.md:.*:review_missing:"

if [ "$fails" -eq 0 ]; then
  echo "scripts/validate-specs.py self-tests passed ✓"
else
  echo "$fails validate-specs self-test(s) failed ✗" >&2
  exit 1
fi
