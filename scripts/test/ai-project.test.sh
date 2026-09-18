#!/usr/bin/env bash
# scripts/test/ai-project.test.sh
#
# Self-test for scripts/ai-project.sh (T1 of
# IMP-20260914-quality-gates-contract; FR-5 / AC-2): scaffolding a scratch
# directory yields a _canonical.md whose § Build and Run table seeds a
# `n/a — to be decided` row for every required quality kind.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }

(cd "$TMP" && AI_DOTFILES="$ROOT" "$ROOT/scripts/ai-project.sh") >/dev/null 2>&1 \
  || fail "ai-project exited non-zero"

CANON="$TMP/_canonical.md"
[ -f "$CANON" ] || { fail "_canonical.md not scaffolded"; echo "ai-project.test: $fails failure(s)" >&2; exit 1; }

# Only the § Build and Run section counts.
section="$(awk '/^## Build and Run$/{on=1; next} /^## /{on=0} on' "$CANON")"
[ -n "$section" ] || fail "§ Build and Run missing"

grep -qE '^\| # \| Step \| Kind \| Mode \| What fails it \|$' <<<"$section" \
  || fail "table header lacks Kind / Mode columns"

for kind in format lint duplication security; do
  grep -qE "^\| — \| n/a — to be decided \| $kind \| — \| — \|$" <<<"$section" \
    || fail "no seeded n/a row for required kind: $kind"
done

# Architecture profile (CR-20260914-design-decisions-and-architecture-profile
# FR-1 / AC-1): every profile item is seeded `unrecorded`.
PROFILE="$TMP/docs/architecture/profile.md"
if [ -f "$PROFILE" ]; then
  for item in "Architectural style" "Domain modelling" "Code organisation" \
              "Programming paradigm" "Error model" "Immutability" "Concurrency" \
              "Integration style"; do
    grep -qE "^\| $item \| .* \| unrecorded \| .* \|$" "$PROFILE" \
      || fail "profile item not seeded unrecorded: $item"
  done
  grep -qE '^\| Last src verified \|' "$PROFILE" || fail "profile lacks Last src verified row"
  grep -qE '^## Contradictions$' "$PROFILE" || fail "profile lacks ## Contradictions"
else
  fail "docs/architecture/profile.md not scaffolded"
fi

# Scaffolding twice never overwrites (existing contract of ai-project).
echo "sentinel" > "$CANON"
(cd "$TMP" && AI_DOTFILES="$ROOT" "$ROOT/scripts/ai-project.sh") >/dev/null 2>&1 \
  || fail "second ai-project run exited non-zero"
[ "$(cat "$CANON")" = "sentinel" ] || fail "second run overwrote _canonical.md"

if [ "$fails" -ne 0 ]; then
  echo "ai-project.test: $fails failure(s)" >&2
  exit 1
fi
echo "ai-project.test: OK"
