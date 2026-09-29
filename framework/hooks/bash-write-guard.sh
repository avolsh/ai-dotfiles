#!/usr/bin/env bash
# framework/hooks/bash-write-guard.sh
#
# PreToolUse guard on `Bash` (IMP-20260929-guarded-writes-through-bash): the shell is the unguarded door to
# everything the file tools are guarded from. It refuses two things:
#   - a write to a path no active spec governs, by the same decision `spec-status-guard.sh` makes (FR-1)
#   - a state-changing git verb anywhere in the command, per boundaries.md § Never do #10 (FR-3)
#
# It is a backstop for convenience, not a sandbox: an agent that means to evade it can write a script and run
# it. So it FAILS OPEN (FR-4) — anything it cannot read confidently is allowed, and recall remains the first
# line. A guard that denied what it did not understand would be switched off within a day.
#
# Contract (see framework/hooks/README.md):
#   stdin  — JSON payload; the command is read from .tool_input.command | .tool_input.script | .command,
#            the working directory from .cwd (optional).
#   exit 0 — allow, including every unreadable command.
#   exit 2 — deny; stderr names the verb, the path and the governing spec, and states the allow conditions.
set -euo pipefail

payload="$(cat || true)"
[ -n "$payload" ] || exit 0

. "$(dirname "$0")/lib/spec-lease.sh"

# The reader lives in python3 because `shlex` tokenises a command the way the shell does, and guessing at that
# with a regular expression is how a guard starts denying the wrong things. It prints one record per line:
#   OPEN                     — something unreadable; the whole command is allowed
#   GIT<TAB><verb>           — a state-changing git verb
#   PATH<TAB><verb><TAB><abs>— a write and the file it lands on
findings="$(printf '%s' "$payload" | python3 -c '
import json, os, shlex, sys

def out(*parts):
    print("\t".join(parts))

try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit  # a malformed payload allows, as every guard does

ti = d.get("tool_input") or d.get("toolInput") or {}
if not ti and isinstance(d.get("toolArgs"), str):
    try:
        ti = json.loads(d["toolArgs"]) or {}
    except Exception:
        ti = {}
command = ti.get("command") or ti.get("script") or d.get("command") or ""
cwd = d.get("cwd") or os.getcwd()
if not isinstance(command, str) or not command.strip():
    raise SystemExit

# Anything that defers the real work to another program takes the paths out of reach of this reader.
OPAQUE = {"eval", "exec", "xargs", "env", "sudo", "ssh", "docker", "make", "npm", "npx", "pnpm", "yarn",
          "bash", "sh", "zsh", "dash", "python", "python3", "perl", "ruby", "node", "deno", "awk", "find"}

GIT_READ = {"status", "log", "diff", "show", "rev-parse", "describe", "cat-file", "ls-files", "ls-tree",
            "blame", "shortlog", "grep", "check-ignore", "check-attr", "whatchanged", "bisect", "help",
            "var", "verify-commit", "count-objects", "rev-list", "for-each-ref", "symbolic-ref", "name-rev"}
# Subcommands whose read and write forms differ only by a flag or an argument.
GIT_MAYBE = {"branch", "tag", "stash", "config", "remote", "worktree", "notes", "reflog", "submodule"}
GIT_READ_FLAGS = {"branch": {"--show-current", "-l", "--list", "-a", "--all", "-r", "--remotes", "-v", "-vv",
                             "--verbose", "--contains", "--merged", "--no-merged", "--points-at"},
                  "tag": {"-l", "--list", "--contains", "--points-at", "-n"},
                  "stash": {"list", "show"},
                  "config": {"--get", "--get-all", "--get-regexp", "-l", "--list"},
                  "remote": {"-v", "--verbose", "show", "get-url"},
                  "worktree": {"list"},
                  "notes": {"list", "show"},
                  "reflog": {"show"},
                  "submodule": {"status", "summary"}}
# Subcommands whose bare form lists rather than writes. `stash` is deliberately absent: `git stash` with no
# arguments stashes the working tree, which is how a human'"'"'s own stash was once applied and dropped.
GIT_BARE_IS_READ = {"branch", "tag", "config", "remote", "worktree", "notes", "reflog", "submodule"}

# Where each write verb keeps the path it writes. "all": every non-flag argument; "last": the final one.
WRITE_VERBS = {"cp": "last", "mv": "last", "install": "last", "ln": "last",
               "rm": "all", "mkdir": "all", "touch": "all", "rmdir": "all", "tee": "all"}
SEPARATORS = {";", "&&", "||", "|", "&", "\n"}

try:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    out("OPEN"); raise SystemExit

# An unexpanded variable, a substitution or a glob means the path this reader would resolve is not the path
# the shell will write to, so the command is left alone.
for t in tokens:
    if any(ch in t for ch in ("$", "`")) or any(ch in t for ch in "*?[") and not t.startswith("-"):
        out("OPEN"); raise SystemExit

segments, current = [], []
for t in tokens:
    if t in SEPARATORS:
        if current:
            segments.append(current); current = []
    else:
        current.append(t)
if current:
    segments.append(current)

def absolute(path):
    return path if os.path.isabs(path) else os.path.normpath(os.path.join(cwd, path))

for seg in segments:
    if not seg:
        continue
    # Redirections write wherever they point, whatever the command in front of them is.
    i = 0
    while i < len(seg):
        if seg[i] in (">", ">>") and i + 1 < len(seg):
            out("PATH", seg[i], absolute(seg[i + 1]))
            i += 2
            continue
        i += 1
    words = [w for w in seg if w not in (">", ">>")]
    # Drop the redirection targets so they are not read as arguments of the command.
    trimmed, skip = [], False
    for w in seg:
        if skip:
            skip = False; continue
        if w in (">", ">>"):
            skip = True; continue
        trimmed.append(w)
    words = trimmed
    if not words:
        continue
    verb = os.path.basename(words[0])
    args = words[1:]

    if verb in OPAQUE:
        continue  # not a finding and not a reason to stop reading the rest

    if verb == "git":
        sub, j = None, 0
        while j < len(args):  # skip the pre-command options that carry a value
            if args[j] in ("-C", "-c", "--git-dir", "--work-tree", "--namespace"):
                j += 2; continue
            if args[j].startswith("-"):
                j += 1; continue
            sub = args[j]; rest = args[j + 1:]; break
        else:
            rest = []
        if sub is None or sub in GIT_READ:
            continue
        if sub in GIT_MAYBE:
            readable = GIT_READ_FLAGS.get(sub, set())
            if not rest and sub in GIT_BARE_IS_READ:
                continue
            if rest and any(r in readable for r in rest):
                continue
        out("GIT", sub)
        continue

    if verb == "sed" and any(a == "-i" or a.startswith("-i") for a in args):
        # Both `sed -i s/x/y/ f` and the BSD `sed -i "" s/x/y/ f` end with the file; taking only the last
        # argument misses a multi-file rewrite, which is a miss the fail-open contract accepts.
        tail = [a for a in args if not a.startswith("-")]
        if tail:
            out("PATH", "sed -i", absolute(tail[-1]))
        continue

    if verb in WRITE_VERBS:
        plain = [a for a in args if not a.startswith("-")]
        if not plain:
            continue
        targets = plain[-1:] if WRITE_VERBS[verb] == "last" else plain
        for t in targets:
            out("PATH", verb, absolute(t))
')"

[ -n "$findings" ] || exit 0
printf '%s\n' "$findings" | grep -qxF "OPEN" && exit 0

while IFS= read -r finding; do
  [ -n "$finding" ] || continue
  kind="${finding%%	*}"
  rest="${finding#*	}"
  if [ "$kind" = "GIT" ]; then
    echo "Blocked by bash-write-guard: 'git $rest' changes repository state, which is the human's to run (boundaries.md § Never do #10)." >&2
    echo "Reading commands — status, log, diff, show, branch --show-current — are unrestricted. Say what you would run and wait." >&2
    exit 2
  fi
  verb="${rest%%	*}"
  path="${rest#*	}"
  if ! spec_lease_decide "$path"; then
    echo "Blocked by bash-write-guard: '$verb' writes '$SPEC_LEASE_REL', governed by $(basename "$SPEC_LEASE_SPEC") at status '$SPEC_LEASE_STATUS' (spec tree: $SPEC_LEASE_ROOT/docs/specs/active)." >&2
    spec_lease_allow_conditions >&2
    exit 2
  fi
done <<< "$findings"

exit 0
