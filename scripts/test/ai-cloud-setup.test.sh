#!/usr/bin/env bash
# scripts/test/ai-cloud-setup.test.sh
#
# Self-tests for scripts/ai-cloud-setup.sh (AC-1 of
# IMP-20261025-cloud-sessions). Copies the dotfiles tree into a fixture
# workspace beside two git repos, gives it a harness-shaped ~/.claude, runs
# the setup twice and asserts the wiring, what survives, and idempotency.
# Never touches the real ~/.claude, repos or Docker: the Docker step runs
# against stub docker/dockerd and a fixture daemon.json.
set -euo pipefail
# shellcheck source=/dev/null
. "$(dirname "$0")/lib/test-env.sh"

SRC="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fails=0
fail() { echo "FAIL: $1" >&2; fails=$((fails + 1)); }

# --- fixture workspace: the dotfiles clone and two repos beside it ---
WS="$TMP/ws"
DF="$WS/ai-dotfiles"
mkdir -p "$DF"
cp -R "$SRC/framework" "$SRC/scripts" "$SRC/docs" "$DF/"
mkdir -p "$DF/profiles/personal"
cp "$SRC/profiles/personal/profile.env" "$DF/profiles/personal/"
# both hold workspace/CLAUDE.md, so only --docs can say which one is the docs repo
for r in repo-a repo-b; do
  git init -q "$WS/$r"
  git -C "$WS/$r" remote add origin "https://github.com/org/$r"
  mkdir -p "$WS/$r/workspace"
  echo "# $r" > "$WS/$r/workspace/CLAUDE.md"
done
mkdir -p "$WS/not-a-repo"

# --- a harness-shaped ~/.claude: its own key, its own skills ---
CFG="$TMP/home/.claude"
mkdir -p "$CFG/skills/session-start-hook" "$CFG/skills/writing-specs"
echo "harness" > "$CFG/skills/session-start-hook/SKILL.md"
echo "harness-owned" > "$CFG/skills/writing-specs/SKILL.md"
printf '{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"harness-stop"}]}]}}\n' \
  > "$CFG/settings.json"

run() { HOME="$TMP/home" AI_CLOUD_HOME="$CFG" "$DF/scripts/ai-cloud-setup.sh" --no-docker "${@:---docs=repo-b}" personal >/dev/null 2>&1; }

# 1. usage error without a profile, or with a --docs that names no docs clone
if "$DF/scripts/ai-cloud-setup.sh" >/dev/null 2>&1; then fail "no profile accepted"; fi
if run --docs not-a-repo; then fail "a --docs naming no docs clone accepted"; fi
[ -e "$WS/docs" ] && fail "a refused --docs still linked docs"

# 2. first run wires everything
run || fail "first run rc"
for e in CLAUDE.md boundaries.md docs spec-workflows prompts templates agents upstream; do
  [ -L "$CFG/$e" ] && [ -e "$CFG/$e" ] || fail "missing or broken link: $e"
done
[ -f "$CFG/docs/agent-protocol.md" ] || fail "<system>/docs does not resolve"
[ -d "$CFG/skills" ] && [ ! -L "$CFG/skills" ] || fail "harness skills dir replaced"
[ -L "$CFG/skills/systematic-debugging" ] || fail "framework skill not linked per entry"
grep -q harness "$CFG/skills/session-start-hook/SKILL.md" || fail "harness skill lost"
[ -L "$CFG/skills/writing-specs" ] && fail "harness-owned entry clobbered"
grep -q harness-owned "$CFG/skills/writing-specs/SKILL.md" || fail "harness-owned content lost"

python3 - "$CFG/settings.json" "$DF" <<'PY' || fail "settings merge"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["model"] == "opus", "foreign key lost"
assert d["env"] == {"AI_DOTFILES": sys.argv[2], "AI_PROFILE": "personal"}, d["env"]
stop = [h["command"] for g in d["hooks"]["Stop"] for h in g["hooks"]]
assert stop[0] == "harness-stop", f"harness hook moved or lost: {stop}"
assert any(c.endswith("stop-build-check.sh") for c in stop), stop
for ev in ("PreToolUse", "PostToolUse", "SessionStart"):
    assert d["hooks"].get(ev), f"{ev} not merged"
assert "@AI_DOTFILES@" not in json.dumps(d), "placeholder left"
PY

for r in repo-a repo-b; do
  [ "$(git -C "$WS/$r" config core.hooksPath)" = "$DF/scripts/git-hooks" ] || fail "core.hooksPath unset: $r"
done
[ -d "$WS/not-a-repo/.git" ] && fail "non-repo touched"
[ "$(readlink "$WS/docs")" = "repo-b" ] || fail "--docs not passed to the workspace link"
grep -q repo-b "$WS/CLAUDE.md" 2>/dev/null || fail "root CLAUDE.md not linked from the named docs clone"

# 3. second run changes nothing
before="$(cd "$CFG" && find . -print0 | sort -z | xargs -0 ls -ld | awk '{print $1, $NF}'; cat "$CFG/settings.json")"
run || fail "second run rc"
after="$(cd "$CFG" && find . -print0 | sort -z | xargs -0 ls -ld | awk '{print $1, $NF}'; cat "$CFG/settings.json")"
[ "$before" = "$after" ] || fail "second run changed ~/.claude"

# 4. the Docker step: mirror added to a missing, a foreign and an already-mirrored daemon.json (review finding 7)
STUB="$TMP/stub"
mkdir -p "$STUB"
printf '#!/bin/sh\nexit 1\n' > "$STUB/docker"                       # daemon not answering
printf '#!/bin/sh\ntouch "%s/dockerd-started"\n' "$TMP" > "$STUB/dockerd"
chmod +x "$STUB/docker" "$STUB/dockerd"
CONF="$TMP/etc/docker/daemon.json"
docker_run() {
  rm -f "$TMP/dockerd-started"
  HOME="$TMP/home" AI_CLOUD_HOME="$CFG" AI_CLOUD_DOCKER_CONF="$CONF" AI_CLOUD_DOCKER_LOG="$TMP/dockerd.log" \
    PATH="$STUB:$PATH" "$DF/scripts/ai-cloud-setup.sh" personal >/dev/null 2>&1
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$TMP/dockerd-started" ] && break; sleep 0.1; done
}
mirrors() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("registry-mirrors"), d.get("debug"))' "$CONF"; }
docker_run || fail "docker run rc (no daemon.json)"
[ "$(mirrors)" = "['https://mirror.gcr.io'] None" ] || fail "daemon.json not created with the mirror: $(mirrors)"
[ -e "$TMP/dockerd-started" ] || fail "dockerd not started"
printf '{"debug": true}\n' > "$CONF"
docker_run || fail "docker run rc (foreign daemon.json)"
[ "$(mirrors)" = "['https://mirror.gcr.io'] True" ] || fail "mirror not merged into an existing daemon.json: $(mirrors)"
docker_run || fail "docker run rc (mirrored daemon.json)"
[ "$(mirrors)" = "['https://mirror.gcr.io'] True" ] || fail "mirror duplicated or key lost: $(mirrors)"

if [ "$fails" -ne 0 ]; then
  echo "$fails ai-cloud-setup test(s) failed ✗" >&2
  exit 1
fi
echo "ai-cloud-setup tests passed ✓"
