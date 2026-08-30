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

if [ "$fails" -eq 0 ]; then
  echo "scripts/validate-specs.py self-tests passed ✓"
else
  echo "$fails validate-specs self-test(s) failed ✗" >&2
  exit 1
fi
