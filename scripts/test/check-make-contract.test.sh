#!/usr/bin/env bash
# scripts/test/check-make-contract.test.sh
#
# Self-tests for scripts/check-make-contract.py. Builds throwaway repositories:
# one conforming Makefile per tier set, one defect per failure rule, the
# consumed-library exemption, targets from includes and pattern rules, and a
# multi-component tree. Each defect must exit 1 with exactly one finding naming
# its rule and target; each conforming repo must exit 0 (make contract
# § Conformance check).
set -euo pipefail

CHECK="$(cd "$(dirname "$0")/.." && pwd)/check-make-contract.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
rc=0
out=""

CORE="help clean build docs-check quality-gates-check sync-agents sync-agents-check"
CODE="format lint typecheck test run dup-report audit deps-install deps-update env-local"

# $1 tiers, $2 targets to omit (space-separated), stdin: extra Makefile lines
makefile() {
  local tiers="$1" omit=" ${2:-} " t targets="$CORE"
  [ "$tiers" = "core code" ] && targets="$CORE $CODE"
  printf 'SHELL := /bin/sh\nMAKE_CONTRACT_TIERS := %s\n' "$tiers"
  cat
  for t in $targets; do
    case "$omit" in *" $t "*) continue ;; esac
    printf '%s:\n\t@echo %s\n' "$t" "$t"
  done
}
LF='Makefile text eol=lf
*.mk text eol=lf
*.sh text eol=lf
'
# $1 name, $2 tiers, $3 omit; stdin: extra lines -> echoes the repo root
repo() {
  local d="$TMP/$1"
  mkdir -p "$d"
  makefile "$2" "${3:-}" > "$d/Makefile"
  printf '%s' "$LF" > "$d/.gitattributes"
  printf '%s' "$d"
}
run() {
  set +e
  out="$(python3 "$CHECK" "$1" 2>&1)"; rc=$?
  set -e
}
expect_ok() { # $1 desc, $2 root
  run "$2"
  if [ "$rc" -ne 0 ] || ! printf '%s' "$out" | grep -q 'conforms$'; then
    echo "FAIL: $1 (expected exit 0 + conforms, got $rc: $out)" >&2; fails=$((fails + 1))
  else echo "ok: $1"; fi
}
expect_one() { # $1 desc, $2 root, $3 expected 'rule target' prefix
  run "$2"
  local n
  n="$(printf '%s\n' "$out" | grep -Ec '^make-contract: (rule-[1-6]|declarations) ' || true)"
  if [ "$rc" -ne 1 ] || [ "$n" -ne 1 ] || ! printf '%s' "$out" | grep -q "^make-contract: $3 — "; then
    echo "FAIL: $1 (expected exit 1 + one '$3' finding, got $rc: $out)" >&2; fails=$((fails + 1))
  else echo "ok: $1"; fi
}

# Conforming, one per tier set.
expect_ok "core conforms" "$(repo core-ok core </dev/null)"
expect_ok "core code conforms" "$(repo code-ok 'core code' </dev/null)"
run "$TMP/code-ok"
printf '%s' "$out" | grep -q '^make-contract: core code, 17 targets, conforms$' \
  || { echo "FAIL: success line (got: $out)" >&2; fails=$((fails + 1)); }

# declarations
d="$(repo no-tiers core </dev/null)"; sed -i.bak '/MAKE_CONTRACT_TIERS/d' "$d/Makefile"
expect_one "missing tiers declaration" "$d" "declarations MAKE_CONTRACT_TIERS"
# rule 1
expect_one "missing lint" "$(repo r1 'core code' lint </dev/null)" "rule-1 lint"
# rule 2
expect_one "required not defined" "$(printf 'MAKE_CONTRACT_REQUIRED := docker-build\n' | repo r2 core)" \
  "rule-2 docker-build"
# rule 3: alias and retired name
expect_one "defines clear" "$(printf 'clear:\n\t@echo x\n' | repo r3a core)" "rule-3 clear"
expect_one "defines retired name" "$(printf 'MAKE_CONTRACT_RETIRED := wipe\nwipe:\n\t@echo x\n' | repo r3b core)" \
  "rule-3 wipe"
# rule 4: both spellings
expect_one "calls make clear" "$(printf 'deps-fix:\n\tmake clear\n' | repo r4a core)" "rule-4 deps-fix"
expect_one "calls \$(MAKE) nope" "$(printf 'deps-fix:\n\t$(MAKE) -s nope\n' | repo r4b core)" "rule-4 deps-fix"
expect_ok "echo mentions make" "$(printf 'deps-fix:\n\t@echo "make sure deps exist; then make build"\n' | repo r4d core)"
d="$(printf 'deps-fix:\n\tcd sub && $(MAKE) lint\n' | repo r4e core)"; mkdir -p "$d/sub"
makefile 'core code' lint </dev/null > "$d/sub/Makefile"
expect_one "cd into a directory, then make" "$d" "rule-1 \[sub\] lint"
expect_ok "calls \$(MAKE) clean" "$(printf 'deps-fix:\n\t$(MAKE) clean\n' | repo r4c core)"
# rule 5 + consumed-library exemption
expect_one "missing _dev script" "$(printf 'wipe-tmp:\n\t_dev/clear.sh\n' | repo r5a core)" "rule-5 wipe-tmp"
expect_one "bash runs missing script" "$(printf 'wipe-tmp:\n\t@bash ./_dev/clear.sh --all\n' | repo r5e core)" "rule-5 wipe-tmp"
expect_one "chmod names missing script" "$(printf 'wipe-tmp:\n\tchmod a+x _dev/clear.sh\n' | repo r5f core)" "rule-5 wipe-tmp"
expect_ok "echo only mentions a script" "$(printf 'wipe-tmp:\n\t@echo "use _dev/local.sh instead"\n' | repo r5g core)"
d="$(printf 'wipe-tmp:\n\t_dev/clean.sh\n' | repo r5b core)"; mkdir -p "$d/_dev"; : > "$d/_dev/clean.sh"
expect_ok "existing _dev script" "$d"
d="$(printf 'wipe-tmp:\n\t_lib/shared/_dev/clean.sh\n' | repo r5c core)"
git -C "$d" init -q; printf '_lib/\n' > "$d/.gitignore"
expect_ok "git-ignored library not yet installed" "$d"
expect_one "missing directory that is not a library" "$(printf 'wipe-tmp:\n\ttools/_dev/foo.sh\n' | repo r5h core)" \
  "rule-5 wipe-tmp"
d="$(printf 'wipe-tmp:\n\tsrc/lib/_dev/clean.sh\n' | repo r5d core)"; mkdir -p "$d/src/lib"
expect_one "installed library missing script" "$d" "rule-5 wipe-tmp"
# rule 6
d="$(repo r6a core </dev/null)"; sed -i.bak '/^SHELL/d' "$d/Makefile"
expect_one "no SHELL := /bin/sh" "$d" "rule-6 SHELL"
d="$(repo r6b core </dev/null)"; printf 'Makefile text eol=lf\n*.sh text eol=lf\n' > "$d/.gitattributes"
expect_one ".gitattributes without *.mk" "$d" "rule-6 .gitattributes"
d="$(repo r6c core </dev/null)"; rm "$d/.gitattributes"
run "$d"
[ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c 'rule-6 .gitattributes')" -eq 3 ] \
  && echo "ok: no .gitattributes" || { echo "FAIL: no .gitattributes ($rc: $out)" >&2; fails=$((fails + 1)); }

# Targets from an include and from a pattern rule count.
d="$(printf 'include targets.mk\n%%-check:\n\t@echo $@\n' | repo inc core 'build docs-check sync-agents-check')"
printf 'build:\n\t@echo build\n' > "$d/targets.mk"
expect_ok "include + pattern rule" "$d"

# Multi-component: the root delegates with $(MAKE) -C; the component is checked too.
d="$(printf 'svc-build:\n\t$(MAKE) -C services/api build\n' | repo multi 'core code')"
mkdir -p "$d/services/api"
makefile 'core code' lint </dev/null > "$d/services/api/Makefile"
expect_one "component missing lint" "$d" "rule-1 \[services/api\] lint"
makefile 'core code' </dev/null > "$d/services/api/Makefile"
run "$d"
[ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c 'conforms$')" -eq 2 ] \
  && echo "ok: multi-component conforms" || { echo "FAIL: multi-component ($rc: $out)" >&2; fails=$((fails + 1)); }

# Exit 2 when make cannot run.
d="$(repo broken core </dev/null)"; printf 'this is not make\n' >> "$d/Makefile"
run "$d"
[ "$rc" -eq 2 ] && echo "ok: broken Makefile exits 2" || { echo "FAIL: broken Makefile ($rc: $out)" >&2; fails=$((fails + 1)); }

if [ "$fails" -ne 0 ]; then echo "check-make-contract: $fails failure(s)" >&2; exit 1; fi
echo "check-make-contract: all tests passed"
