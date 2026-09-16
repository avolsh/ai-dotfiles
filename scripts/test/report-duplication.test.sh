#!/usr/bin/env bash
# scripts/test/report-duplication.test.sh
#
# Self-tests for scripts/report-duplication.js, summarising hand-written jscpd reports with
# `--from-report` so no detector runs. Ported from tobevisit-content's jest test when the script was
# promoted here (tobevisit-web IMP-20260916-quality-gates-adoption FR-4), plus the group rule that
# became an argument: `--split` and `--scan-root`.
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/report-duplication.js"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
rc=0
out=""
err=""

# $1 project dir, $2 scan root, rest: files under the scan root
tree() {
  local d="$1" root="$2"
  shift 2
  for f in "$@"; do
    mkdir -p "$(dirname "$d/$root/$f")"
    printf 'export {};\n' > "$d/$root/$f"
  done
}
# $1 project dir, stdin: `first|second|lines` per clone — writes $1/report.json
report() {
  node -e '
    const lines = require("fs").readFileSync(0, "utf8").trim().split("\n").filter(Boolean);
    const duplicates = lines.map((l) => { const [a, b, n] = l.split("|"); return {firstFile: {name: a}, secondFile: {name: b}, lines: Number(n)}; });
    const duplicatedLines = duplicates.reduce((s, c) => s + c.lines, 0);
    require("fs").writeFileSync(process.argv[1], JSON.stringify({duplicates, statistics: {total: {clones: duplicates.length, duplicatedLines, percentage: 1.5, sources: 7}}}));
  ' "$1/report.json"
}
run() { # $1 project dir, rest: arguments — sets $out, $err, $rc
  local d="$1"
  shift
  set +e
  out="$(cd "$d" && node "$SCRIPT" "$@" 2>"$TMP/stderr")"; rc=$?
  err="$(cat "$TMP/stderr")"
  set -e
}
# $1 desc, $2 group, $3 expected "<lines> lines  <clones> clones" regex
expect_row() {
  if ! printf '%s\n' "$out" | grep -Eq "^  $2 +$3\$"; then
    echo "FAIL: $1 (no row '$2 … $3' in:)" >&2
    printf '%s\n' "$out" >&2; fails=$((fails + 1))
  fi
}
expect_text() { # $1 desc, $2 fixed text
  if ! printf '%s\n' "$out" | grep -Fq -- "$2"; then
    echo "FAIL: $1 (expected '$2' in:)" >&2
    printf '%s\n' "$out" >&2; fails=$((fails + 1))
  fi
}
expect_rc() { # $1 desc, $2 rc
  if [ "$rc" -ne "$2" ]; then
    echo "FAIL: $1 (expected exit $2, got $rc; stderr: $err)" >&2; fails=$((fails + 1))
  fi
}

# A content-shaped tree: bounded contexts under `contexts`, split with `--split contexts`.
content() {
  local d="$TMP/$1"
  tree "$d" src composition-root.ts app/page.tsx shared/entity.ts scripts/tool.js workflows/step-01.ts \
    contexts/place-catalog/domain/index.ts contexts/geo-reference/domain/index.ts
  printf '%s' "$d"
}

# ---------- a clone spanning two split groups counts under both ----------
d="$(content cross)"
printf '%s\n' "contexts/place-catalog/domain/a.ts|contexts/geo-reference/domain/b.ts|30" | report "$d"
run "$d" --split contexts --from-report report.json
expect_rc "cross-group clone" 0
expect_row "cross-group clone, first half" "src/contexts/place-catalog" "30 lines  1 clones"
expect_row "cross-group clone, second half" "src/contexts/geo-reference" "30 lines  1 clones"
expect_text "cross-group clone counted as spanning" "1 clones span two groups"

# ---------- a clone inside one group counts once ----------
d="$(content inside)"
printf '%s\n' "src/app/a.tsx|src/app/b.tsx|12" | report "$d"
run "$d" --split contexts --from-report report.json
expect_row "same-group clone" "src/app" "12 lines  1 clones"
expect_text "same-group clone not spanning" "0 clones span two groups"

# ---------- every group on disk is printed; files directly under the root go to (root) ----------
d="$(content ondisk)"
printf '%s\n' "composition-root.ts|scripts/tool.js|6" | report "$d"
run "$d" --split contexts --from-report report.json
expect_row "root file group" "src \\(root\\)" "6 lines  1 clones"
expect_row "scripts group" "src/scripts" "6 lines  1 clones"
for g in src/shared src/workflows src/contexts/place-catalog; do
  expect_row "empty group $g still printed" "$g" "0 lines  0 clones"
done

# ---------- the summary line comes from the report totals ----------
d="$(content summary)"
printf '%s\n' "shared/a.ts|shared/b.ts|9" | report "$d"
run "$d" --split contexts --from-report report.json
expect_text "summary line" "[SUMMARY] make dup-report — 1 clones, 9 duplicated lines (1.50%) in 7 files"

# ---------- without --split, a directory with subdirectories is one group ----------
d="$(content nosplit)"
printf '%s\n' "contexts/place-catalog/domain/a.ts|contexts/geo-reference/domain/b.ts|30" | report "$d"
run "$d" --from-report report.json
expect_row "unsplit contexts is one group" "src/contexts" "30 lines  1 clones"
expect_text "unsplit clone inside one group" "0 clones span two groups"
if printf '%s\n' "$out" | grep -q "src/contexts/place-catalog"; then
  echo "FAIL: unsplit run still printed a per-context group" >&2; fails=$((fails + 1))
fi

# ---------- --scan-root names the groups and strips its own prefix ----------
d="$TMP/scanroot"
tree "$d" lib/code index.ts ui/button.tsx
printf '%s\n' "lib/code/ui/a.tsx|ui/b.tsx|7" | report "$d"
run "$d" --scan-root lib/code --from-report report.json
expect_row "scan-root prefixed path" "lib/code/ui" "7 lines  1 clones"
expect_row "scan-root root group" "lib/code \\(root\\)" "0 lines  0 clones"

# ---------- refusals exit 2, never a clean-looking summary ----------
d="$(content notjscpd)"
printf '{"something":"else"}' > "$d/report.json"
run "$d" --from-report report.json
expect_rc "not a jscpd report" 2
if ! printf '%s' "$err" | grep -q "is not a jscpd JSON report"; then
  echo "FAIL: not a jscpd report (stderr: $err)" >&2; fails=$((fails + 1))
fi

run "$d" --group contexts --from-report report.json
expect_rc "unknown argument" 2

run "$d" --split
expect_rc "--split without a value" 2

d="$TMP/noroot"
mkdir -p "$d"
printf '%s\n' "a.ts|b.ts|5" | report "$d"
run "$d" --from-report report.json
expect_rc "scan root missing" 2

if [ "$fails" -eq 0 ]; then
  echo "scripts/report-duplication.js self-tests passed ✓"
else
  echo "$fails report-duplication self-test(s) failed ✗" >&2
  exit 1
fi
