#!/usr/bin/env bash
# scripts/ai-cloud-docker.sh
#
# Start Docker in a Claude Code cloud session, for the contract and integration
# suites (IMP-20261026-cloud-setup-partial-sessions FR-3). ai-cloud-setup.sh runs
# it at setup; the Claude SessionStart hook runs it before the doctor at every
# start and resume, because a resumed container keeps its files but not its
# processes, and the environment's Setup script does not run again.
#
# Anonymous Docker Hub pulls from the shared egress address return 429;
# mirror.gcr.io serves the library images. The mirror is added to a daemon.json
# already there, keeping its other keys; one that is not valid JSON is left alone.
# dockerd is started in a session of its own with every stream redirected, so it
# outlives the hook that started it and holds none of the hook's output open.
#
# Usage: ai-cloud-docker.sh [--force]
#        Does nothing outside a cloud session (CLAUDE_CODE_REMOTE=true) unless
#        --force. Always exits 0: a daemon that never answers is the doctor's to
#        report, and stdout stays empty for the SessionStart context.
# Env:   AI_CLOUD_DOCKER_CONF the daemon.json path, AI_CLOUD_DOCKER_LOG dockerd's
#        log, AI_CLOUD_DOCKER_WAIT the seconds to wait for it (default 10).
set -uo pipefail

_err() { printf 'ai-cloud-docker: %s\n' "$*" >&2; }

force=0
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    *) _err "unknown argument '$arg'"; exit 0 ;;
  esac
done
[ "$force" -eq 1 ] || [ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
command -v dockerd >/dev/null 2>&1 || exit 0
docker info >/dev/null 2>&1 && exit 0

DOCKER_CONF="${AI_CLOUD_DOCKER_CONF:-/etc/docker/daemon.json}"
mkdir -p "$(dirname "$DOCKER_CONF")"
python3 - "$DOCKER_CONF" <<'PY' >&2 || _err "$DOCKER_CONF is not valid JSON; registry mirror not added"
import json, os, sys
path, mirror = sys.argv[1], "https://mirror.gcr.io"
conf = json.load(open(path)) if os.path.exists(path) else {}
mirrors = conf.setdefault("registry-mirrors", [])
if mirror not in mirrors:
    mirrors.append(mirror)
    with open(path, "w") as fh:
        json.dump(conf, fh, indent=2)
        fh.write("\n")
PY

log="${AI_CLOUD_DOCKER_LOG:-/var/log/dockerd.log}"
if command -v setsid >/dev/null 2>&1; then
  setsid nohup dockerd > "$log" 2>&1 < /dev/null &
else
  nohup dockerd > "$log" 2>&1 < /dev/null &
fi

wait_s="${AI_CLOUD_DOCKER_WAIT:-10}"
for _ in $(seq 1 $((wait_s * 4))); do
  docker info >/dev/null 2>&1 && exit 0
  sleep 0.25
done
_err "dockerd started but not answering after ${wait_s}s; its log: $log"
exit 0
