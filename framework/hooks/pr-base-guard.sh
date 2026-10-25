#!/usr/bin/env bash
# framework/hooks/pr-base-guard.sh
#
# PreToolUse guard on the GitHub PR tools (IMP-20261025-cloud-sessions FR-7): the PR half of the cloud
# exception to boundaries.md § Never do #10. In a cloud session (CLAUDE_CODE_REMOTE=true) a PR the agent
# opens or retargets must have as its base the branch the human named for that repo, as recorded under an
# in-progress spec's `branches:` — never `master` or `develop`. Outside a cloud session it does nothing: there
# the agent opens no PR at all, and § Never do #10 says so.
#
# Contract (see framework/hooks/README.md):
#   stdin  — JSON payload; the repo and base are read from .tool_input.repo and .tool_input.base, the
#            working directory from .cwd (optional). A call that names no base (an update of the title,
#            say) is not a base change and is allowed.
#   exit 0 — allow, including a malformed payload.
#   exit 2 — deny; stderr names the base, the repo and the bases the specs record.
#
# Spec trees searched: every ancestor of .cwd owning docs/specs/active, and every repo beside $AI_DOTFILES.
# Only a spec at status in-progress counts: its work is the one a PR carries. Two such specs recording
# different bases for one repo leave the base ambiguous, and the PR is denied until the human settles it.
set -euo pipefail

payload="$(cat || true)"
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
[ -n "$payload" ] || exit 0

workspace=""
[ -n "${AI_DOTFILES:-}" ] && workspace="$(dirname "$AI_DOTFILES")"

verdict="$(printf '%s' "$payload" | AI_PR_WS="$workspace" python3 -c '
import glob, json, os, re, sys

try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit  # a malformed payload allows, as every guard does
ti = d.get("tool_input") or d.get("toolInput") or {}
repo, base = ti.get("repo"), ti.get("base")
if not isinstance(base, str) or not base or not isinstance(repo, str) or not repo:
    raise SystemExit

if base in ("master", "develop"):
    print("DENY\t" + base + "\t" + repo + "\t-\tmaster and develop are reserved for the human")
    raise SystemExit

roots, cwd = [], d.get("cwd") or os.getcwd()
while True:
    if os.path.isdir(os.path.join(cwd, "docs", "specs", "active")):
        roots.append(cwd)
    parent = os.path.dirname(cwd)
    if parent == cwd:
        break
    cwd = parent
ws = os.environ.get("AI_PR_WS")
if ws:
    roots += [os.path.dirname(os.path.dirname(os.path.dirname(p)))
              for p in glob.glob(os.path.join(ws, "*", "docs", "specs", "active"))]

recorded = set()
for root in dict.fromkeys(roots):
    for spec in glob.glob(os.path.join(root, "docs", "specs", "active", "*.md")):
        try:
            text = open(spec, encoding="utf-8").read()
        except OSError:
            continue
        m = re.match(r"---\n(.*?)\n---", text, re.S)
        if not m or not re.search(r"^status:\s*in-progress\s*$", m.group(1), re.M):
            continue
        line = re.search(r"^branches:\s*\{(.*)\}\s*$", m.group(1), re.M)
        if not line:
            continue
        for pair in line.group(1).split(","):
            name, _, value = pair.partition(":")
            if name.strip() == repo and value.strip():
                recorded.add(value.strip())

if len(recorded) > 1:
    print("DENY\t" + base + "\t" + repo + "\t" + ", ".join(sorted(recorded)) + "\tin-progress specs disagree on the base")
elif base not in recorded:
    print("DENY\t" + base + "\t" + repo + "\t" + (", ".join(sorted(recorded)) or "none") + "\tnot the recorded base")
')"

[ -n "$verdict" ] || exit 0
IFS=$'\t' read -r _ base repo recorded reason <<< "$verdict"
echo "Blocked by pr-base-guard: base '$base' for $repo — $reason (recorded: $recorded)." >&2
echo "Ask the human for this repo's base branch, record it under the spec's branches:, and open the PR into it (boundaries.md § Never do #10, cloud exception)." >&2
exit 2
