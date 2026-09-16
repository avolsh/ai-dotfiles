#!/usr/bin/env bash
# scripts/test/validate-quality-gates.test.sh
#
# Self-tests for scripts/validate-quality-gates.py. Builds throwaway project
# roots whose `_canonical.md` carries one defect each and asserts that only the
# complete table exits 0, and every other one prints exactly one finding naming
# its check and line (IMP-20260916-quality-gates-check AC-1).
set -euo pipefail

VALIDATOR="$(cd "$(dirname "$0")/.." && pwd)/validate-quality-gates.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
rc=0
out=""

# The complete table every defect fixture is derived from. Line numbers below
# are counted against it: the header row is line 7, the first data row line 9.
complete() {
  cat <<'EOF'
# demo

*Last updated: 2026-09-16*

## Build and Run

| # | Step | Kind | Mode | What fails it |
|---|---|---|---|---|
| 1 | `format:check` | format | gate | Prettier would rewrite a file |
| 2 | `lint` | lint | gate | ESLint finds an error |
| 3 | `test` | test | gate | a test fails |
| — | `dup-report` | duplication | report | never; writes `.duplication-report/jscpd-report.json` |
| — | n/a — no dependency audit yet; it is its own IMP | security | — | — |

## Available skills

- none
EOF
}

newproj() { # $1 name, stdin: _canonical.md -> echoes the project root
  local d="$TMP/$1"
  mkdir -p "$d"
  cat > "$d/_canonical.md"
  printf '%s' "$d"
}
run() { # $1 project root — sets $out and $rc (not in a subshell, keeps $rc)
  set +e
  out="$(python3 "$VALIDATOR" "$1" 2>/dev/null)"; rc=$?
  set -e
}
# $1 desc, $2 root, $3 expected line, $4 expected check
expect_one() {
  run "$2"
  local n
  n="$(printf '%s' "$out" | grep -c . || true)"
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: $1 (expected non-zero exit, got 0)" >&2; fails=$((fails + 1)); return
  fi
  if [ "$n" -ne 1 ]; then
    echo "FAIL: $1 (expected exactly one finding, got $n)" >&2
    printf '%s\n' "$out" >&2; fails=$((fails + 1)); return
  fi
  if ! printf '%s' "$out" | grep -q -- "^$2/_canonical.md:$3:$4:"; then
    echo "FAIL: $1 (expected '$2/_canonical.md:$3:$4:…', got '$out')" >&2
    fails=$((fails + 1))
  fi
}

# ---------- complete table passes, n/a — <reason> with `—` Mode included ----------
p="$(complete | newproj complete)"
run "$p"
if [ "$rc" -ne 0 ] || [ -n "$out" ]; then
  echo "FAIL: complete table (expected rc=0 and no output, got rc=$rc: $out)" >&2
  fails=$((fails + 1))
fi

# ---------- FR-1: section, table, columns ----------
p="$(complete | sed 's/^## Build and Run$/## Build/' | newproj nosection)"
expect_one "FR-1 no Build and Run section" "$p" 1 section_missing

p="$(complete | sed -e 's/ | Kind | Mode |/ | Type | Mode |/' | newproj nokind)"
expect_one "FR-1 no Kind column" "$p" 7 column_missing

p="$(complete | grep -v '^|' | newproj notable)"
expect_one "FR-1 section without a table" "$p" 5 table_missing

# ---------- FR-2: required kinds ----------
p="$(complete | grep -v '| security |' | newproj nosecurity)"
expect_one "FR-2 security missing" "$p" 7 kind_missing

p="$(complete | sed 's/^| 2 | `lint` | lint | gate | ESLint finds an error |$/| — | n\/a — to be decided | lint | — | — |/' | newproj lintseed)"
expect_one "FR-2 lint still to be decided" "$p" 10 kind_undecided

# ---------- FR-3: vocabularies and numbering ----------
p="$(complete | sed 's/| test | gate |/| test | sometimes |/' | newproj badmode)"
expect_one "FR-3 Mode = sometimes" "$p" 11 mode_unknown

p="$(complete | sed 's/| test | gate |/| unit | gate |/' | newproj badkind)"
expect_one "FR-3 unknown Kind" "$p" 11 kind_unknown

p="$(complete | sed 's/^| — | `dup-report`/| 3 | `dup-report`/' | newproj numberedreport)"
expect_one "FR-3 report row numbered 3" "$p" 12 report_numbered

p="$(complete | sed 's/^| 3 | `test`/| — | `test`/' | newproj unnumberedgate)"
expect_one "FR-3 gate row numbered —" "$p" 11 gate_unnumbered

# ---------- FR-4: duplication names its report ----------
p="$(complete | sed 's/never; writes `.duplication-report\/jscpd-report.json`/never/' | newproj duppath)"
expect_one "FR-4 duplication without a report path" "$p" 12 duplication_no_report

if [ "$fails" -eq 0 ]; then
  echo "scripts/validate-quality-gates.py self-tests passed ✓"
else
  echo "$fails validate-quality-gates self-test(s) failed ✗" >&2
  exit 1
fi
