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

if [ "$fails" -eq 0 ]; then
  echo "scripts/validate-specs.py self-tests passed ✓"
else
  echo "$fails validate-specs self-test(s) failed ✗" >&2
  exit 1
fi
