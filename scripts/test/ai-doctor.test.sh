#!/usr/bin/env bash
# scripts/test/ai-doctor.test.sh
#
# Self-tests for scripts/ai-doctor.sh (AC-3 of
# IMP-20260610-mechanize-framework-guardrails). Builds a fixture dotfiles
# tree + profile in a temp dir, asserts OK on a healthy profile, FAIL with
# the expected target on a deliberately broken symlink, and OK again after
# repair. HOME is overridden so real tool homes are never touched.
set -euo pipefail

SUT="$(cd "$(dirname "$0")/.." && pwd)/ai-doctor.sh"
LIB="$(cd "$(dirname "$0")/.." && pwd)/lib/profile-links.sh"
# Cases 1-7 are the local profile; a cloud session's own env must not turn
# on the cloud checks for them.
unset CLAUDE_CODE_REMOTE
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
expect() { # $1 desc, $2 expected rc, $3 actual rc
  if [ "$2" -ne "$3" ]; then
    echo "FAIL: $1 (expected rc=$2, got rc=$3)" >&2
    fails=$((fails + 1))
  fi
}

# --- fixture dotfiles tree ---
DF="$TMP/dotfiles"
mkdir -p "$DF/framework/spec-workflows" "$DF/framework/prompts" \
         "$DF/framework/templates/system/claude" "$DF/framework/skills" \
         "$DF/framework/agents" "$DF/framework/upstream"
echo "# b" > "$DF/framework/boundaries.md"
echo "# c" > "$DF/framework/templates/system/claude/CLAUDE.md"
mkdir -p "$DF/docs" && echo "# ap" > "$DF/docs/agent-protocol.md"

P="$DF/profiles/test/claude"
mkdir -p "$P"
ln -s "$DF/framework/templates/system/claude/CLAUDE.md" "$P/CLAUDE.md"
ln -s "$DF/framework/boundaries.md" "$P/boundaries.md"
ln -s "$DF/docs" "$P/docs"
for ref in spec-workflows prompts templates skills agents upstream; do
  ln -s "$DF/framework/$ref" "$P/$ref"
done

export HOME="$TMP/home"
mkdir -p "$HOME/.claude"

# 1. healthy profile passes
set +e
out="$(AI_DOTFILES="$DF" "$SUT" test 2>&1)"; rc=$?
set -e
expect "healthy profile passes" 0 "$rc"

# 2. broken ref symlink fails and names the expected target
rm "$DF/framework/boundaries.md"   # leaves $P/boundaries.md dangling
set +e
out="$(AI_DOTFILES="$DF" "$SUT" test 2>&1)"; rc=$?
set -e
expect "broken symlink fails" 1 "$rc"
echo "$out" | grep -q "boundaries.md" || { echo "FAIL: broken link must be named" >&2; fails=$((fails+1)); }

# 3. repair restores OK
echo "# b" > "$DF/framework/boundaries.md"
set +e
AI_DOTFILES="$DF" "$SUT" test >/dev/null 2>&1; rc=$?
set -e
expect "repaired profile passes" 0 "$rc"

# 3b. a missing docs link fails and is named (BUG-20260916-system-docs-prefix-unresolved)
rm "$P/docs"
set +e
out="$(AI_DOTFILES="$DF" "$SUT" test 2>&1)"; rc=$?
set -e
expect "missing docs link fails" 1 "$rc"
echo "$out" | grep -q "/docs" || { echo "FAIL: missing docs link must be named" >&2; fails=$((fails+1)); }
ln -s "$DF/docs" "$P/docs"

# 4. fast mode ignores ref links (only instruction + manifest)
rm "$DF/framework/boundaries.md"
set +e
AI_DOTFILES="$DF" "$SUT" --fast test >/dev/null 2>&1; rc=$?
set -e
expect "fast mode skips ref checks" 0 "$rc"
echo "# b" > "$DF/framework/boundaries.md"

# 5. manifest mismatch fails
printf 'profile=other\ntarget=%s\n' "$P/CLAUDE.md" > "$HOME/.claude/.active-manifest"
set +e
out="$(AI_DOTFILES="$DF" "$SUT" test 2>&1)"; rc=$?
set -e
expect "manifest profile mismatch fails" 1 "$rc"

# 6. matching manifest with resolving target passes
printf 'profile=test\ntarget=%s\n' "$P/CLAUDE.md" > "$HOME/.claude/.active-manifest"
set +e
AI_DOTFILES="$DF" "$SUT" test >/dev/null 2>&1; rc=$?
set -e
expect "consistent manifest passes" 0 "$rc"

# 7. missing profile dir fails
set +e
AI_DOTFILES="$DF" "$SUT" nosuch >/dev/null 2>&1; rc=$?
set -e
expect "missing profile dir fails" 1 "$rc"

# --- cloud session (IMP-20261025-cloud-sessions AC-2) ---
mkdir -p "$DF/framework/skills/writing-specs" "$DF/scripts/git-hooks"
printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"@AI_DOTFILES@/framework/hooks/stop-build-check.sh"}]}]}}\n' \
  > "$DF/framework/templates/system/claude/hooks.json"
CFG="$TMP/cloud-home/.claude"
mkdir -p "$CFG/skills/harness-skill"
git init -q "$TMP/repo-a"
# shellcheck source=../lib/profile-links.sh
. "$LIB"
ai_links_wire_dir "$DF" "$CFG" claude 2>/dev/null
ai_links_merge_claude_settings "$DF" "$CFG/settings.json" test 2>/dev/null
git -C "$TMP/repo-a" config core.hooksPath "$DF/scripts/git-hooks"
git -C "$TMP/repo-a" remote add origin https://github.com/org/repo-a
# the docs clone holding workspace/, linked into the root as a cloud setup does (FR-13)
git init -q "$TMP/wsdocs"
mkdir -p "$TMP/wsdocs/workspace"
echo "# workspace" > "$TMP/wsdocs/workspace/CLAUDE.md"
git -C "$TMP/wsdocs" config core.hooksPath "$DF/scripts/git-hooks"
git -C "$TMP/wsdocs" remote add origin https://github.com/org/wsdocs  # docs, never also under src/
WSL="$(cd "$(dirname "$0")/.." && pwd)/ai-workspace-link.sh"
AI_DOTFILES="$DF" "$WSL" --cloud "$TMP" >/dev/null 2>&1
cloud() { AI_DOTFILES="$DF" AI_CLOUD_HOME="$CFG" AI_DOCTOR_DOCKER="$1" "$SUT" --fast "${@:2}" test 2>&1; }

# 8. a wired cloud session passes
set +e
cloud true --cloud >/dev/null; rc=$?
set -e
expect "wired cloud session passes" 0 "$rc"

# 9. CLAUDE_CODE_REMOTE=true implies --cloud
set +e
CLAUDE_CODE_REMOTE=true cloud false >/dev/null; rc=$?
set -e
expect "CLAUDE_CODE_REMOTE turns on the cloud checks" 1 "$rc"

# 10. one link, one hook, one repo's hooksPath and Docker missing: each named
rm "$CFG/prompts"
python3 - "$CFG/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["hooks"] = {}
json.dump(d, open(sys.argv[1], "w"))
PY
git -C "$TMP/repo-a" config --unset core.hooksPath
set +e
out="$(cloud false --cloud)"; rc=$?
set -e
expect "broken cloud session fails" 1 "$rc"
for want in "$CFG/prompts" "hook missing: $DF/framework/hooks/stop-build-check.sh" "repo-a: core.hooksPath" "docker daemon"; do
  echo "$out" | grep -qF "$want" || { echo "FAIL: cloud failure not named: $want" >&2; fails=$((fails+1)); }
done

# 10b. a real path standing where a framework link belongs is named, not passed (review finding 6)
rm "$CFG/CLAUDE.md" "$CFG/skills/writing-specs"
echo "harness-owned" > "$CFG/CLAUDE.md"
mkdir "$CFG/skills/writing-specs"
set +e
out="$(cloud true --cloud)"; rc=$?
set -e
expect "a real path in place of a framework link fails" 1 "$rc"
for want in "$CFG/CLAUDE.md (a real path" "$CFG/skills/writing-specs (a real path"; do
  echo "$out" | grep -qF "$want" || { echo "FAIL: real path not named: $want" >&2; fails=$((fails+1)); }
done

# 10c. a real dir the CLI owns (agents/) with the framework entries linked inside passes (review cycle 2 finding 6)
rm -rf "$CFG"
mkdir -p "$CFG/skills/harness-skill" "$CFG/agents" "$DF/framework/agents"
echo "# reviewer" > "$DF/framework/agents/reviewer.md"
echo "# mine" > "$CFG/agents/user-agent.md"
ai_links_wire_dir "$DF" "$CFG" claude 2>/dev/null
ai_links_merge_claude_settings "$DF" "$CFG/settings.json" test 2>/dev/null
git -C "$TMP/repo-a" config core.hooksPath "$DF/scripts/git-hooks"
set +e
out="$(cloud true --cloud)"; rc=$?
set -e
expect "a CLI-owned real dir with framework entries linked inside passes" 0 "$rc"
[ "$rc" -eq 0 ] || echo "$out" >&2
rm "$CFG/agents/reviewer.md"
set +e
out="$(cloud true --cloud)"; rc=$?
set -e
expect "a framework entry missing inside a CLI-owned dir fails" 1 "$rc"
echo "$out" | grep -qF "$CFG/agents/reviewer.md (missing" || { echo "FAIL: missing inner entry not named" >&2; fails=$((fails+1)); }
rm "$CFG/prompts"

# 10d. the workspace root: a removed root link and a removed src link are named (FR-13, AC-7)
rm "$TMP/CLAUDE.md" "$TMP/src/github.com/org/repo-a"
set +e
out="$(cloud true --cloud)"; rc=$?
set -e
expect "a broken workspace root fails" 1 "$rc"
for want in "$TMP/CLAUDE.md (not linked" "$TMP/src/github.com/org/repo-a (missing"; do
  echo "$out" | grep -qF "$want" || { echo "FAIL: workspace failure not named: $want" >&2; fails=$((fails+1)); }
done
AI_DOTFILES="$DF" "$WSL" --cloud "$TMP" >/dev/null 2>&1

# 10e. a second clone holding workspace/CLAUDE.md and no docs link: the ambiguity is named; the
#      link --docs makes passes
git init -q "$TMP/wsdocs2"
mkdir -p "$TMP/wsdocs2/workspace"
echo "# other" > "$TMP/wsdocs2/workspace/CLAUDE.md"
git -C "$TMP/wsdocs2" config core.hooksPath "$DF/scripts/git-hooks"
rm "$TMP/docs"
set +e
out="$(cloud true --cloud)"; rc=$?
set -e
expect "two docs candidates and no docs link fail" 1 "$rc"
echo "$out" | grep -qF "several clones hold workspace/CLAUDE.md" || { echo "FAIL: docs ambiguity not named" >&2; fails=$((fails+1)); }
AI_DOTFILES="$DF" "$WSL" --cloud --docs wsdocs "$TMP" >/dev/null 2>&1
ai_links_wire_dir "$DF" "$CFG" claude 2>/dev/null  # the links 10c removed
set +e
out="$(cloud true --cloud)"; rc=$?
set -e
expect "the docs link --docs made passes beside a second candidate" 0 "$rc"
[ "$rc" -eq 0 ] || echo "$out" >&2
rm -rf "$TMP/wsdocs2"

# 10f. not initialised for the framework: a noted project repo and a noted docs repo, the exit status unchanged (FR-15)
# stdout only: it is what reaches the session at SessionStart
stdout_of() { AI_DOTFILES="$DF" AI_CLOUD_HOME="$CFG" AI_DOCTOR_DOCKER=true "$SUT" --fast --cloud test 2>/dev/null; }
set +e
out="$(stdout_of)"; rc=$?
set -e
expect "a repo without the framework does not fail the doctor" 0 "$rc"
echo "$out" | grep -qF "NOTE $TMP/src/github.com/org/repo-a: not initialised for the AI framework (missing: _canonical.md CLAUDE.md AGENTS.md .github/copilot-instructions.md)" \
  || { echo "FAIL: uninitialised project repo not noted on stdout" >&2; fails=$((fails+1)); }
for f in _canonical.md CLAUDE.md AGENTS.md .github/copilot-instructions.md; do
  mkdir -p "$(dirname "$TMP/repo-a/$f")"; echo x > "$TMP/repo-a/$f"
done
out="$(stdout_of || true)"
echo "$out" | grep -q "repo-a: not initialised" && { echo "FAIL: an initialised repo still noted" >&2; fails=$((fails+1)); }
git init -q "$TMP/emptydocs"
git -C "$TMP/emptydocs" config core.hooksPath "$DF/scripts/git-hooks"
ln -sfn emptydocs "$TMP/docs"
out="$(stdout_of || true)"
echo "$out" | grep -qF "NOTE $TMP/emptydocs: not initialised for the AI framework (no workspace/CLAUDE.md)" \
  || { echo "FAIL: uninitialised docs repo not noted" >&2; fails=$((fails+1)); }
rm -rf "$TMP/emptydocs"
AI_DOTFILES="$DF" "$WSL" --cloud --docs wsdocs "$TMP" >/dev/null 2>&1

# 10g. .mrconfig: a clone at its section passes; a listed repo with no clone is a NOTE; an unsafe section fails (FR-17)
cat > "$TMP/wsdocs/workspace/.mrconfig" <<'MR'
[research/repo-a]
checkout = git clone 'https://github.com/org/repo-a.git' 'repo-a'

[src/github.com/org/missing]
checkout = git clone 'git@github.com:org/missing.git' 'missing'
MR
AI_DOTFILES="$DF" "$WSL" --cloud --docs wsdocs "$TMP" >/dev/null 2>&1
set +e
out="$(stdout_of)"; rc=$?
set -e
expect "a clone at its .mrconfig section passes" 0 "$rc"
echo "$out" | grep -qF "NOTE $TMP/src/github.com/org/missing: listed in .mrconfig, not cloned in this session (github.com/org/missing)" \
  || { echo "FAIL: a listed repo with no clone not noted" >&2; fails=$((fails+1)); }
echo "$out" | grep -qF "(github.com/org/missing) — remind the owner to give the Claude GitHub App access to it and add it to the project's repositories (Project settings)" \
  || { echo "FAIL: the note on a listed repo with no clone names no owner steps" >&2; fails=$((fails+1)); }
rm "$TMP/research/repo-a"
set +e
out="$(cloud true --cloud)"; rc=$?
set -e
expect "a clone missing from its .mrconfig section fails" 1 "$rc"
echo "$out" | grep -qF "$TMP/research/repo-a (missing" || { echo "FAIL: missing section link not named" >&2; fails=$((fails+1)); }
printf "\n[src/../x]\ncheckout = git clone 'https://github.com/org/x' 'x'\n" >> "$TMP/wsdocs/workspace/.mrconfig"
AI_DOTFILES="$DF" "$WSL" --cloud --docs wsdocs "$TMP" >/dev/null 2>&1
set +e
out="$(cloud true --cloud)"; rc=$?
set -e
expect "an unsafe .mrconfig section fails" 1 "$rc"
echo "$out" | grep -qF "FAIL $TMP/wsdocs/workspace/.mrconfig: section [src/../x] is not a plain path" \
  || echo "$out" | grep -qF "FAIL $TMP/docs/workspace/.mrconfig: section [src/../x] is not a plain path" \
  || { echo "FAIL: unsafe section not named" >&2; fails=$((fails+1)); }
rm "$TMP/wsdocs/workspace/.mrconfig" "$TMP/.mrconfig"

# 11. without --cloud the same broken session is not checked
set +e
cloud false >/dev/null; rc=$?
set -e
expect "cloud checks are off locally" 0 "$rc"

if [ "$fails" -ne 0 ]; then
  echo "$fails ai-doctor self-test(s) failed ✗" >&2
  exit 1
fi
echo "scripts/ai-doctor.sh self-tests passed ✓"
