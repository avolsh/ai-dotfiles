#!/usr/bin/env bash
# scripts/test/ai-cloud-docker.test.sh
#
# Self-tests for scripts/ai-cloud-docker.sh (AC-2 of
# IMP-20261026-cloud-setup-partial-sessions): Docker is started in the cloud
# only, once, and the run returns after the daemon answers; the daemon.json
# mirror merge; the Claude SessionStart hook runs it before the doctor.
# Never touches the real Docker: stub docker/dockerd and a fixture daemon.json.
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "$0")/lib/test-env.sh"

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
SUT="$SRC/scripts/ai-cloud-docker.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }

# docker answers once the stub dockerd has run and marked the daemon up
STUB="$TMP/stub"
mkdir -p "$STUB"
printf '#!/bin/sh\n[ -e "%s/up" ]\n' "$TMP" > "$STUB/docker"
printf '#!/bin/sh\necho started >> "%s/starts"\n[ -e "%s/never" ] || touch "%s/up"\n' "$TMP" "$TMP" "$TMP" > "$STUB/dockerd"
chmod +x "$STUB/docker" "$STUB/dockerd"
CONF="$TMP/etc/docker/daemon.json"

reset() { rm -f "$TMP/up" "$TMP/starts" "$TMP/never"; }
starts() { [ -f "$TMP/starts" ] && wc -l < "$TMP/starts" | tr -d ' ' || echo 0; }
sut() { # $1 CLAUDE_CODE_REMOTE value, then the script's arguments
  local remote="$1"; shift
  env CLAUDE_CODE_REMOTE="$remote" AI_CLOUD_DOCKER_CONF="$CONF" AI_CLOUD_DOCKER_LOG="$TMP/dockerd.log" \
    AI_CLOUD_DOCKER_WAIT="${WAIT:-5}" PATH="$STUB:$PATH" "$SUT" "$@"
}
mirrors() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("registry-mirrors"), d.get("debug"))' "$CONF"; }

# 1. cloud, daemon down: started once, returns once it answers, nothing on stdout
reset
out="$(sut true 2>/dev/null)" || fail "cloud start rc"
[ "$(starts)" = 1 ] || fail "dockerd started $(starts) times, expected 1"
[ -e "$TMP/up" ] || fail "returned before the daemon answered"
[ -z "$out" ] || fail "stdout not empty (it reaches the SessionStart context): $out"
[ "$(mirrors)" = "['https://mirror.gcr.io'] None" ] || fail "daemon.json not created with the mirror: $(mirrors)"

# 2. cloud, daemon up: nothing started
sut true >/dev/null 2>&1 || fail "cloud up rc"
[ "$(starts)" = 1 ] || fail "dockerd started again while the daemon answered"

# 3. outside the cloud: nothing, unless --force
reset
sut "" >/dev/null 2>&1 || fail "local rc"
[ "$(starts)" = 0 ] || fail "dockerd started outside the cloud"
sut "" --force >/dev/null 2>&1 || fail "--force rc"
[ "$(starts)" = 1 ] || fail "--force did not start dockerd"

# 4. daemon.json: a foreign key kept, the mirror not duplicated, invalid JSON left alone
reset
printf '{"debug": true}\n' > "$CONF"
sut true >/dev/null 2>&1 || fail "foreign daemon.json rc"
[ "$(mirrors)" = "['https://mirror.gcr.io'] True" ] || fail "mirror not merged into an existing daemon.json: $(mirrors)"
reset
sut true >/dev/null 2>&1 || fail "mirrored daemon.json rc"
[ "$(mirrors)" = "['https://mirror.gcr.io'] True" ] || fail "mirror duplicated or key lost: $(mirrors)"
reset
echo 'not json' > "$CONF"
err="$(sut true 2>&1 >/dev/null)" || fail "invalid daemon.json rc"
[ "$(cat "$CONF")" = "not json" ] || fail "invalid daemon.json rewritten"
echo "$err" | grep -q "not valid JSON" || fail "invalid daemon.json not reported"
[ "$(starts)" = 1 ] || fail "dockerd not started beside an invalid daemon.json"

# 5. a daemon that never answers: exit 0 after the wait, reported on stderr
reset
touch "$TMP/never"
err="$(WAIT=1 sut true 2>&1 >/dev/null)" || fail "never-answering rc"
echo "$err" | grep -q "not answering after 1s" || fail "a daemon that never answered not reported"

# 6. the Claude SessionStart hook: one command, the Docker start before the doctor (FR-4)
python3 - "$SRC/framework/templates/system/claude/hooks.json" <<'PY' || fail "SessionStart hook does not start Docker before the doctor"
import json, sys
groups = json.load(open(sys.argv[1]))["hooks"]["SessionStart"]
cmds = [h["command"] for g in groups for h in g["hooks"]]
assert cmds == ["@AI_DOTFILES@/scripts/ai-cloud-docker.sh; @AI_DOTFILES@/scripts/ai-doctor.sh --fast --hook"], cmds
PY

if [ "$fails" -ne 0 ]; then
  echo "$fails ai-cloud-docker test(s) failed ✗" >&2
  exit 1
fi
echo "ai-cloud-docker tests passed ✓"
