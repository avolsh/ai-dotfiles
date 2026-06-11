#!/usr/bin/env bash
# framework/hooks/secrets-scan.sh
#
# Secret guard (FR-1b, IMP-20260610-mechanize-framework-guardrails):
# blocks commits that contain secrets or forbidden env files
# (boundaries.md § Never do #1).
#
# Modes:
#   secrets-scan.sh <file>...   — scan the given worktree files
#   secrets-scan.sh             — scan the staged changes of the repo in $PWD
#
# exit 0 — clean; exit 1 — findings listed on stderr as path[:line]: reason.
set -euo pipefail

PATTERNS='-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|xox[bpars]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}'
# Value must not start with `$` — variable references and command
# substitutions (e.g. token="$(security ...)") are not hardcoded literals.
ASSIGN_PATTERN='(api[_-]?key|secret|token|password)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'$][^"'"'"']{7,}'

fail=0

is_forbidden_name() {
  # .env, .env.*, .dev.vars are never committed; samples/templates are fine.
  local base; base="$(basename "$1")"
  case "$base" in
    *.example|*.template|*.sample) return 1 ;;
    .env|.env.*|.dev.vars) return 0 ;;
  esac
  return 1
}

scan_stream() { # $1 = label for findings
  local label="$1" hits
  hits="$(grep -I -n -E -e "$PATTERNS" - 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | sed "s|^|$label:|; s|\$| : secret pattern|" >&2
    fail=1
  fi
}

scan_assignments() { # $1 = label, stdin = content
  local label="$1" hits
  hits="$(grep -I -n -i -E -e "$ASSIGN_PATTERN" - 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | sed "s|^|$label:|; s|\$| : hardcoded credential assignment|" >&2
    fail=1
  fi
}

if [ "$#" -gt 0 ]; then
  for f in "$@"; do
    [ -f "$f" ] || continue
    if is_forbidden_name "$f"; then
      echo "$f : forbidden env file (never commit .env / .env.* / .dev.vars)" >&2
      fail=1
      continue
    fi
    scan_stream "$f" < "$f"
    scan_assignments "$f" < "$f"
  done
else
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if is_forbidden_name "$f"; then
      echo "$f : forbidden env file (never commit .env / .env.* / .dev.vars)" >&2
      fail=1
      continue
    fi
    scan_stream "$f" < <(git show ":$f" 2>/dev/null || true)
    scan_assignments "$f" < <(git show ":$f" 2>/dev/null || true)
  done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
fi

exit "$fail"
