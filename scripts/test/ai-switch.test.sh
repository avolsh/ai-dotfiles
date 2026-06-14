#!/usr/bin/env bash
# scripts/test/ai-switch.test.sh
#
# Characterization suite for scripts/ai-switch.sh (T1 of
# IMP-20260610-stabilize-profile-switching; FR-5, FR-12 baseline).
#
# Runs the REAL scripts against a hermetic fixture (own HOME, own
# AI_DOTFILES, stubbed launchctl/security on PATH) — real tool homes and
# the real Keychain are never touched.
#
# Asserts, after every sequence (init→switch, switch×2 same/other profile,
# switch→reset, reset→switch, double init):
#   * session-preservation invariants per tool — planted Claude / Codex /
#     Copilot session state stays byte-identical (sqlite/db by checksum);
#   * the atomic-rename scenario merges CLI-written real files back into
#     the shared home (never stranded or deleted);
#   * `.claude.json` JSON-merge keeps home and profile keys.
#
# Doctor-green assertions are present but BASELINE-gated: with
# AI_SWITCH_TEST_STRICT=0 (default until T3) the suite documents today's
# known failure — a plain switch drops init-only refs (`upstream`, D1) —
# and fails only if that baseline changes shape. With
# AI_SWITCH_TEST_STRICT=1 (T3+) ai-doctor must exit 0 after every active
# sequence.
#
# FR-12 guard: the bodies of the ten shared-state functions must match the
# baseline hashes recorded at T1 (pre-refactor HEAD).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SWITCH="$REPO/scripts/ai-switch.sh"
INIT="$REPO/scripts/ai-profile-init.sh"
DOCTOR="$REPO/scripts/ai-doctor.sh"
# STRICT=1 (default since T3): ai-doctor must exit 0 after every active
# sequence. STRICT=0 re-enables the pre-T3 characterization baseline.
STRICT="${AI_SWITCH_TEST_STRICT:-1}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }
expect_rc() { [ "$2" -eq "$3" ] || fail "$1 (expected rc=$2, got rc=$3)"; }

# ---------- stubs: keep launchctl / security away from the real system ----------
mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/launchctl"
printf '#!/bin/sh\nexit 1\n' > "$TMP/bin/security"
chmod +x "$TMP/bin/launchctl" "$TMP/bin/security"
export PATH="$TMP/bin:$PATH"

# ---------- fixture dotfiles tree + two profiles ----------
DF="$TMP/dotfiles"
for d in spec-workflows prompts skills agents upstream; do mkdir -p "$DF/framework/$d"; done
mkdir -p "$DF/framework/templates/system/claude" \
         "$DF/framework/templates/system/copilot" \
         "$DF/framework/templates/system/codex"
echo "# boundaries" > "$DF/framework/boundaries.md"
echo "# claude"  > "$DF/framework/templates/system/claude/CLAUDE.md"
echo "# copilot" > "$DF/framework/templates/system/copilot/copilot-instructions.md"
echo "# codex"   > "$DF/framework/templates/system/codex/AGENTS.md"

for p in test1 test2; do
  mkdir -p "$DF/profiles/$p/claude" "$DF/profiles/$p/copilot" "$DF/profiles/$p/codex"
  printf 'export AI_PROFILE=%s\n' "$p" > "$DF/profiles/$p/profile.env"
done

# The switch sources the wiring library from $AI_DOTFILES — mirror it.
mkdir -p "$DF/scripts/lib"
cp "$REPO/scripts/lib/profile-links.sh" "$DF/scripts/lib/"

# ---------- fixture HOME with planted per-tool session state ----------
export HOME="$TMP/home"
RC="$HOME/.zshrc"
mkdir -p "$HOME/.claude/projects/p1" "$HOME/.codex/sessions" "$HOME/.copilot/session-state"
touch "$RC"

plant() { printf '%s' "$2" > "$1"; }
plant "$HOME/.claude/projects/p1/session.jsonl" 'claude-session-data'
plant "$HOME/.claude/history.jsonl"             'claude-history'
plant "$HOME/.claude/.credentials.json"         "$(printf '{"token":"%s"}' claude-cred)"
plant "$HOME/.codex/sessions/r1.jsonl"          'codex-rollout-data'
plant "$HOME/.codex/history.jsonl"              'codex-history'
plant "$HOME/.codex/auth.json"                  "$(printf '{"token":"%s"}' codex-auth)"
printf 'SQLITE-FAKE-\x00\x01\x02-goals' > "$HOME/.codex/goals_1.sqlite"
plant "$HOME/.codex/.codex-global-state.json"   '{"g":1}'
plant "$HOME/.copilot/session-state/s1"         'copilot-session-data'
printf 'SQLITE-FAKE-\x00\x03\x04-store' > "$HOME/.copilot/session-store.db"
plant "$HOME/.copilot/command-history-state.json" '{"h":1}'
plant "$HOME/.copilot/config.json"              '{"c":1}'
plant "$HOME/.claude.json"                      '{"home_key":1}'

SESSION_FILES=(
  "$HOME/.claude/projects/p1/session.jsonl" "$HOME/.claude/history.jsonl"
  "$HOME/.claude/.credentials.json"
  "$HOME/.codex/sessions/r1.jsonl" "$HOME/.codex/history.jsonl"
  "$HOME/.codex/auth.json" "$HOME/.codex/goals_1.sqlite"
  "$HOME/.codex/.codex-global-state.json"
  "$HOME/.copilot/session-state/s1" "$HOME/.copilot/session-store.db"
  "$HOME/.copilot/command-history-state.json" "$HOME/.copilot/config.json"
)

checksum_sessions() {
  local f
  for f in "${SESSION_FILES[@]}"; do
    [ -e "$f" ] || { echo "MISSING $f"; continue; }
    shasum -a 256 "$f"
  done
}
BASELINE_SUMS="$(checksum_sessions)"

assert_sessions() { # $1 = sequence label
  local now
  now="$(checksum_sessions)"
  if [ "$now" != "$BASELINE_SUMS" ]; then
    fail "session state changed after '$1':"
    diff <(printf '%s\n' "$BASELINE_SUMS") <(printf '%s\n' "$now") >&2 || true
  fi
}

run_switch() { AI_DOTFILES="$DF" bash "$SWITCH" --rc-file "$RC" "$@" >/dev/null 2>&1; }
run_init()   { AI_DOTFILES="$DF" bash "$INIT" "$1" >/dev/null 2>&1; }

run_doctor() { # $1 profile, $2 sequence label, $3 expect_active (1) or detached-ok (0)
  local out rc
  set +e
  out="$(AI_DOTFILES="$DF" bash "$DOCTOR" "$1" 2>&1)"; rc=$?
  set -e
  if [ "$STRICT" = "1" ]; then
    if [ "$3" = "1" ] && [ $rc -ne 0 ]; then
      fail "STRICT: doctor not green after '$2': $out"
    fi
  else
    # Baseline (pre-T3): a plain switch is KNOWN to drop init-only refs
    # (D1, `upstream`). Document the failure class; fail only if the
    # baseline silently changes shape.
    if [ "$3" = "1" ] && [ $rc -ne 0 ]; then
      echo "$out" | grep -q "upstream" || fail "baseline drift after '$2' — doctor fails for a new reason: $out"
    fi
  fi
}

# =========================================================================
# Sequence 1: init → switch
run_init test1 || fail "init test1"
expect_rc "switch test1 after init" 0 "$(run_switch test1; echo $?)"
assert_sessions "init→switch"
run_doctor test1 "init→switch" 1

# Sequence 2: switch → switch (same profile)
expect_rc "re-switch test1" 0 "$(run_switch test1; echo $?)"
assert_sessions "switch→switch(same)"
run_doctor test1 "switch→switch(same)" 1

# Sequence 3: switch to the other profile
run_init test2 || fail "init test2"
expect_rc "switch test2" 0 "$(run_switch test2; echo $?)"
assert_sessions "switch→switch(other)"
run_doctor test2 "switch→switch(other)" 1

# Manifest lifecycle (FR-4 / AC-4): present and consistent after a switch
for tool in claude copilot codex; do
  m="$HOME/.$tool/.active-manifest"
  [ -f "$m" ] || { fail "manifest missing after switch: $m"; continue; }
  grep -q '^profile=test2$' "$m" || fail "manifest profile wrong: $m"
  tgt="$(sed -n 's/^target=//p' "$m" | head -1)"
  [ -e "$tgt" ] || fail "manifest target does not resolve: $tgt"
done

# Sequence 4: switch → reset
expect_rc "reset" 0 "$(run_switch --reset; echo $?)"
assert_sessions "switch→reset"
for tool in claude copilot codex; do
  [ -e "$HOME/.$tool/.active-manifest" ] && fail "manifest not removed on reset: .$tool"
done

# Sequence 5: reset → switch
expect_rc "switch after reset" 0 "$(run_switch test1; echo $?)"
assert_sessions "reset→switch"
run_doctor test1 "reset→switch" 1

# Sequence 6: double init (idempotency; no nested links)
run_init test1 || fail "double init"
[ -e "$DF/profiles/test1/claude/skills/skills" ] && fail "nested skills/skills after double init"
assert_sessions "double-init"

# =========================================================================
# Atomic-rename scenario: a CLI replaced a shared-state symlink in the
# profile with a real file holding new data; the next switch must merge it
# back into the home, never strand or delete it.
if [ -L "$DF/profiles/test1/claude/history.jsonl" ]; then
  rm "$DF/profiles/test1/claude/history.jsonl"
  printf 'claude-history+NEW-SESSION' > "$DF/profiles/test1/claude/history.jsonl"
  expect_rc "switch after atomic-rename" 0 "$(run_switch test1; echo $?)"
  grep -q "NEW-SESSION" "$HOME/.claude/history.jsonl" \
    || fail "atomic-rename: new data not merged back into home history.jsonl"
  [ -L "$DF/profiles/test1/claude/history.jsonl" ] \
    || fail "atomic-rename: profile entry not re-linked"
  # restore planted content for any later assertions
  printf 'claude-history' > "$HOME/.claude/history.jsonl"
else
  fail "precondition: profile history.jsonl is not a symlink after switch"
fi

# .claude.json merge: home keys preserved, profile keys folded in
rm -f "$DF/profiles/test1/claude/.claude.json"
printf '{"profile_key":2}' > "$DF/profiles/test1/claude/.claude.json"
expect_rc "switch with real profile .claude.json" 0 "$(run_switch test1; echo $?)"
python3 - "$HOME/.claude.json" <<'PY' || exit 1
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("home_key") == 1, f"home key lost: {d}"
assert d.get("profile_key") == 2, f"profile key not merged: {d}"
PY
[ $? -eq 0 ] || fail ".claude.json merge lost keys"

# =========================================================================
# FR-12 guard: shared-state engine bodies are byte-identical to the
# baseline recorded at T1 (pre-refactor HEAD).
declare -A FR12_HASHES=(
  [_ai_link_shared_state]=c313eb6299f9aaeb926b6658692556e82d05ce24193439a2237f3dc503b383f4
  [_ai_link_shared_state_for_tool]=7f15d84a18595b776fe1221dabb332519076b9f4a92edd66e4ed637af427abcb
  [_ai_link_shared_state_source]=06a1bf7cdd8ca6d2aeb56fb4a21de70975b4997a194c49ae4deddbc5ffc4db2b
  [_ai_restore_shared_state]=3c96d893dda1ff9cc500a13003499602ab29b83977d4b2f269f070e2caabd77e
  [_ai_restore_shared_state_for_tool]=605344c7102bd0bbd57efcddbc88e0ab6d49d2236db9f0935224b0c465083c9d
  [_ai_restore_path]=45320ae1b5631bb99ee756800a95bfa70167368496a1a68f8c35e1ca0be36162
  [_ai_merge_json_into]=1722175c8d1e32d190c38049e92563d55331c041876e1e490925db4085f9551c
  [_ai_sync_claude_keychain]=646b6f6fc29467b12b8522a2625d988915cfb854dbe738863ced7d40c9f652b7
  [_ai_sync_claude_keychain_back]=585b6c12449c12d4e40a6e0214ab61eadb460edc5ed2b354dc962996ba34b491
  [_ai_guard_running]=e07a527d491760782e5b885170dfdac9d6a5633d4bd1e03b1b14b1ad685bfdd8
)
for fn in "${!FR12_HASHES[@]}"; do
  actual="$(awk "/^${fn}\(\) \{/,/^\}/" "$SWITCH" | shasum -a 256 | cut -d' ' -f1)"
  [ "$actual" = "${FR12_HASHES[$fn]}" ] \
    || fail "FR-12 violation: $fn body changed (expected ${FR12_HASHES[$fn]}, got $actual)"
done

if [ "$fails" -ne 0 ]; then
  echo "$fails ai-switch characterization test(s) failed ✗" >&2
  exit 1
fi
echo "scripts/ai-switch.sh characterization tests passed ✓ (STRICT=$STRICT)"
