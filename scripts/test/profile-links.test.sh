#!/usr/bin/env bash
# scripts/test/profile-links.test.sh
#
# Unit tests for scripts/lib/profile-links.sh (T2 of
# IMP-20260610-stabilize-profile-switching; FR-1, FR-3 / AC-1, AC-3).
# Fixture-only; never touches real tool homes or profiles.
set -euo pipefail

LIB="$(cd "$(dirname "$0")/../lib" && pwd)/profile-links.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }

# shellcheck source=../lib/profile-links.sh
. "$LIB"

# ---------- fixture dotfiles ----------
DF="$TMP/df"
for d in spec-workflows prompts skills agents upstream; do mkdir -p "$DF/framework/$d"; done
mkdir -p "$DF/framework/templates/system/claude" \
         "$DF/framework/templates/system/copilot" \
         "$DF/framework/templates/system/codex" \
         "$DF/framework/skills/writing-specs"
echo "# b" > "$DF/framework/boundaries.md"
echo "# c" > "$DF/framework/templates/system/claude/CLAUDE.md"
echo "# p" > "$DF/framework/templates/system/copilot/copilot-instructions.md"
echo "# a" > "$DF/framework/templates/system/codex/AGENTS.md"
echo "skill" > "$DF/framework/skills/writing-specs/SKILL.md"
printf '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"@AI_DOTFILES@/scripts/ai-doctor.sh --fast"}]}]}}\n' \
  > "$DF/framework/templates/system/claude/hooks.json"
printf '{"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"@AI_DOTFILES@/framework/hooks/spec-status-guard.sh"}]}]}}\n' \
  > "$DF/framework/templates/system/codex/hooks.json"
printf '{"version":1,"hooks":{"preToolUse":[{"type":"command","bash":"@AI_DOTFILES@/framework/hooks/spec-status-guard.sh"}]}}\n' \
  > "$DF/framework/templates/system/copilot/copilot-cli-policy.json"

P="$DF/profiles/test"
mkdir -p "$P/claude" "$P/copilot" "$P/codex"

# 1. full wiring: every ref incl. upstream, instruction, boundaries
ai_links_wire_profile "$DF" "$P" 2>/dev/null || fail "wire_profile rc"
for tool in claude copilot codex; do
  for ref in spec-workflows prompts templates skills agents upstream; do
    [ -L "$P/$tool/$ref" ] || fail "missing ref link: $tool/$ref"
  done
  [ -L "$P/$tool/boundaries.md" ] || fail "missing boundaries link: $tool"
done
[ -L "$P/claude/CLAUDE.md" ] || fail "missing claude instruction link"
[ -L "$P/copilot/copilot-instructions.md" ] || fail "missing copilot instruction link"
[ -L "$P/codex/AGENTS.md" ] || fail "missing codex instruction link"

# 2. rendering: placeholder substituted, valid JSON, real files
for f in "$P/codex/hooks.json" "$P/copilot/hooks/framework-policy.json"; do
  [ -f "$f" ] && [ ! -L "$f" ] || fail "rendered file missing or symlink: $f"
  grep -q "@AI_DOTFILES@" "$f" && fail "placeholder not substituted: $f"
  python3 -c "import json;json.load(open('$f'))" || fail "invalid JSON: $f"
done

# 3. settings merge preserves foreign keys and is idempotent
printf '{"model":"opus","other":{"x":1}}\n' > "$P/claude/settings.json"
ai_links_render_hooks "$DF" "$P" 2>/dev/null
python3 - "$P/claude/settings.json" <<'PY' || exit 1
import json, sys
d = json.load(open(sys.argv[1]))
assert d["model"] == "opus" and d["other"] == {"x": 1}, f"foreign keys lost: {d}"
assert "SessionStart" in d.get("hooks", {}), f"hooks not merged: {d}"
PY
before="$(shasum -a 256 "$P/claude/settings.json")"
ai_links_render_hooks "$DF" "$P" 2>/dev/null
[ "$before" = "$(shasum -a 256 "$P/claude/settings.json")" ] || fail "settings merge not idempotent"

# 4. idempotency of full wiring (run twice, no nesting)
ai_links_wire_profile "$DF" "$P" 2>/dev/null
[ -e "$P/codex/skills/skills" ] && fail "nested skills/skills after re-wire"

# 5. CLI-owned real dir: per-entry fallback, .system preserved (AC-3)
rm "$P/codex/skills"
mkdir -p "$P/codex/skills/.system"
echo "marker" > "$P/codex/skills/.system/marker"
ai_links_wire_tool "$DF" "$P" codex 2>/dev/null
[ -f "$P/codex/skills/.system/marker" ] || fail "CLI-owned .system/marker lost"
[ -L "$P/codex/skills/writing-specs" ] || fail "per-entry skill link missing in real dir"
[ -e "$P/codex/skills/skills" ] && fail "nested skills/skills in real-dir fallback"

# 6. CLI-owned real entry shadowing a framework entry is preserved
rm -f "$P/codex/skills/writing-specs"
mkdir -p "$P/codex/skills/writing-specs"
echo "user-owned" > "$P/codex/skills/writing-specs/SKILL.md"
out="$(ai_links_wire_tool "$DF" "$P" codex 2>&1)"
[ -L "$P/codex/skills/writing-specs" ] && fail "real shadowing entry was clobbered"
grep -q "user-owned" "$P/codex/skills/writing-specs/SKILL.md" || fail "shadowing entry content lost"
echo "$out" | grep -q "kept CLI-owned" || fail "shadowing entry not reported"

# 7. real FILE in the way: reported, never clobbered
rm -f "$P/claude/prompts" 2>/dev/null
echo "real-file-data" > "$P/claude/prompts"
out="$(ai_links_wire_tool "$DF" "$P" claude 2>&1)"
grep -q "real-file-data" "$P/claude/prompts" || fail "real file clobbered"
echo "$out" | grep -q "WARN real path" || fail "real-file conflict not reported"
rm "$P/claude/prompts" && ai_links_wire_tool "$DF" "$P" claude 2>/dev/null

# 8. dangling symlink is repaired
rm "$P/claude/agents"
ln -s "$DF/nonexistent" "$P/claude/agents"
ai_links_wire_tool "$DF" "$P" claude 2>/dev/null
[ -e "$P/claude/agents" ] || fail "dangling ref link not repaired"

# 9. CROSS-SHELL: the library is sourced into the user's zsh by `ai`.
# zsh does not word-split unquoted `$VAR` and aborts on empty `.[!.]*`
# globs — both broke `ai <profile>` while bash-only tests stayed green.
# Re-run full profile wiring under zsh and assert every ref link lands.
if command -v zsh >/dev/null 2>&1; then
  Z="$TMP/zsh-profile"
  mkdir -p "$Z/claude" "$Z/copilot" "$Z/codex/skills/.system"
  echo "marker" > "$Z/codex/skills/.system/marker"   # CLI-owned real dir
  if zsh -c ". '$LIB'; ai_links_wire_profile '$DF' '$Z'" >/dev/null 2>&1; then
    for tool in claude copilot codex; do
      for ref in spec-workflows prompts templates skills agents upstream; do
        # codex/skills is a real dir -> per-entry links inside it, not a dir symlink
        if [ "$tool/$ref" = "codex/skills" ]; then
          [ -L "$Z/codex/skills/writing-specs" ] || fail "zsh: per-entry skill link missing"
        else
          [ -L "$Z/$tool/$ref" ] || fail "zsh: ref link missing $tool/$ref (word-split regression)"
        fi
      done
    done
    [ -f "$Z/codex/skills/.system/marker" ] || fail "zsh: CLI-owned .system clobbered"
  else
    fail "zsh: ai_links_wire_profile returned non-zero (sourced-shell regression)"
  fi
else
  echo "profile-links.test: zsh not found — skipping cross-shell check" >&2
fi

if [ "$fails" -ne 0 ]; then
  echo "$fails profile-links test(s) failed ✗" >&2
  exit 1
fi
echo "scripts/lib/profile-links.sh tests passed ✓"
