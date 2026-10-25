#!/usr/bin/env bash
# scripts/test/ai-install.test.sh
#
# Self-tests for `scripts/ai-install.sh --check` in and out of a cloud session (IMP-20261025-cloud-sessions
# FR-19, AC-10). Fixture HOME only; never touches the real ~/.zshrc.
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "$0")/lib/test-env.sh"

INSTALL="$(cd "$(dirname "$0")/.." && pwd)/ai-install.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }

H="$TMP/home"
mkdir -p "$H"
echo "# someone else's rc" > "$TMP/drifted.zshrc"

# --- cloud session: the default ~/.zshrc is the laptop's, so --check passes and says why ---
out="$(HOME="$H" CLAUDE_CODE_REMOTE=true "$INSTALL" --check 2>&1)" || fail "cloud, default rc: non-zero exit"
echo "$out" | grep -q "cloud session" || fail "cloud, default rc: no note"
[ -e "$H/.zshrc" ] && fail "cloud, default rc: wrote ~/.zshrc"

# --- cloud session, an explicit --rc-file is still checked ---
HOME="$H" CLAUDE_CODE_REMOTE=true "$INSTALL" --check --rc-file "$TMP/drifted.zshrc" >/dev/null 2>&1 \
  && fail "cloud, --rc-file with drift: passed"

# --- laptop: a missing ~/.zshrc is drift ---
HOME="$H" "$INSTALL" --check >/dev/null 2>&1 && fail "laptop, no ~/.zshrc: passed"

# --- laptop: once installed, --check passes ---
HOME="$H" "$INSTALL" --rc-file "$H/.zshrc" >/dev/null
HOME="$H" "$INSTALL" --check >/dev/null 2>&1 || fail "laptop, installed: drift reported"

if [ "$fails" -ne 0 ]; then
  echo "$fails ai-install test(s) failed ✗" >&2
  exit 1
fi
echo "ai-install tests passed ✓"
