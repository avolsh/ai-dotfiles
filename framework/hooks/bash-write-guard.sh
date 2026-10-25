#!/usr/bin/env bash
# framework/hooks/bash-write-guard.sh
#
# PreToolUse guard on `Bash` (IMP-20260929-guarded-writes-through-bash): the shell is the unguarded door to
# everything the file tools are guarded from. It refuses two things:
#   - a write to a path no active spec governs, by the same decision `spec-status-guard.sh` makes (FR-1)
#   - a state-changing git verb anywhere in the command, per boundaries.md § Never do #10 (FR-3) — except, in a
#     cloud session (CLAUDE_CODE_REMOTE=true), the writes its cloud exception allows on the agent's own
#     `claude/*` branch (IMP-20261025-cloud-sessions FR-6)
#   - in a cloud session, a `gh pr` verb that opens or changes a PR: PRs go through the GitHub tools, whose base
#     `pr-base-guard.sh` checks (FR-7)
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
#   GH<TAB><verb>            — a `gh pr` verb that opens or changes a PR (cloud session only)
#   PATH<TAB><verb><TAB><abs>— a write and the file it lands on
findings="$(printf '%s' "$payload" | python3 -c '
import json, os, re, shlex, subprocess, sys

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
# `(…)` and `{ …; }` group commands, so their brackets end one command and start the next as a separator does.
GROUP = {"(", ")", "{", "}"}
SEPARATORS = {";", "&&", "||", "|", "&", "\n"} | GROUP

try:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    out("OPEN"); raise SystemExit
# The lexer keeps a run of operator characters as one token (`)&&`, `((`); split it into its operators.
tokens = [part for t in tokens
          for part in (re.findall(r"&&|\|\||>>|[;&|()<>]", t) if t and all(c in "();<>|&" for c in t) else [t])]

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

def absolute(path, base=None):
    base = base or cwd
    return path if os.path.isabs(path) else os.path.normpath(os.path.join(base, path))

# Cloud mode only: a `cd` earlier in the same command moves the repository a later git write lands in, so the
# branch the cloud exception checks is read there. None once it cannot be followed. Write paths still resolve
# against the payload cwd, as they always have.
here = cwd
# A `cd` inside a group moves that group alone, which this reader does not track: with both in one command the
# repository a git write lands in is unknown (FR-6).
if any(t in GROUP for t in tokens) and any(t in ("cd", "pushd", "popd") for t in tokens):
    here = None

CLOUD = os.environ.get("CLAUDE_CODE_REMOTE") == "true"
AGENT = "claude/"
GH_PR_WRITE = {"create", "new", "edit", "merge", "ready", "close", "reopen", "revert", "update-branch"}  # `new` is gh'"'"'s alias of create
CHECKOUT_DENY = {"-f", "--force", "--discard-changes", "-m", "--merge"}  # each discards or rewrites local work
PUSH_DENY = {"-f", "--force", "--force-with-lease", "--force-if-includes", "-d", "--delete", "--mirror",
             "--all", "--tags", "--prune"}

# A GIT_* variable set anywhere in the command (`export GIT_CONFIG_COUNT=1 …; git commit`) can reconfigure the
# git that runs after it; shell state does not outlive one command, so the command is all there is to read.
GIT_ENV = CLOUD and any(t.startswith("GIT_") and "=" in t for t in tokens)

def denied(args, options):
    """An argument naming one of options, including the unique abbreviations git accepts (`--no-verif`)."""
    for a in args:
        name = a.split("=", 1)[0]
        if name in options:
            return True
        if name.startswith("--") and len(name) > 2 and any(o.startswith(name) for o in options):
            return True
    return False

def current_branch(where):
    try:
        r = subprocess.run(["git", "-C", where, "branch", "--show-current"], capture_output=True, text=True,
                           timeout=5)
    except Exception:
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""

def cloud_allows(sub, rest, where):
    """boundaries.md § Never do #10, cloud exception: the writes allowed on the agent branch."""
    if sub in ("checkout", "switch"):
        # Creating the agent branch from the human base, never tracking it. -B and -C are absent on purpose:
        # they reset a branch that already exists, unpushed commits and all.
        if denied(rest, CHECKOUT_DENY):
            return False
        for k, a in enumerate(rest):
            if a in ("-b", "-c") and k + 1 < len(rest):
                return rest[k + 1].startswith(AGENT) and "--no-track" in rest
        return False
    if where is None:
        return False  # a `cd` this reader could not follow: the branch is unknown
    branch = current_branch(where)
    if not branch.startswith(AGENT):
        return False
    if sub == "add":
        return True
    if sub == "commit":
        # --no-verify / -n skip the pre-commit backstop, the only secrets check on this path.
        short = [a for a in rest if a.startswith("-") and not a.startswith("--")]
        return not denied(rest, {"--amend", "--no-verify"}) and not any("n" in a[1:] for a in short)
    if sub == "fetch":
        return not any(":" in a for a in rest if not a.startswith("-"))
    if sub == "pull":
        if any(":" in a for a in rest if not a.startswith("-")):
            return False  # `pull origin X:X` writes the local branch X
        return "--ff-only" in rest and not any(a in ("-r", "--rebase") or a.startswith("--rebase=") for a in rest)
    if sub == "push":
        if denied(rest, PUSH_DENY) or any(a.startswith("--force") for a in rest):
            return False
        plain = [a for a in rest if not a.startswith("-")]
        refspecs = plain[1:]  # the first is the remote
        if not refspecs:
            return False  # a bare push goes wherever push.default says; name the branch
        for spec in refspecs:
            if spec.startswith(("+", ":")):
                return False  # a forced update, or an empty source: `:claude/x` deletes the remote branch
            dst = spec.split(":", 1)[-1]
            if dst.startswith("refs/heads/"):
                dst = dst[len("refs/heads/"):]
            if dst != branch:
                return False
        return True
    return False

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
    # Leading NAME=value assignments (GIT_CONFIG_COUNT=…, say) can reconfigure git for that one command.
    assigned = 0
    while CLOUD and assigned < len(words) - 1 and "=" in words[assigned] and not words[assigned].startswith("-"):
        assigned += 1
    words = words[assigned:]
    verb = os.path.basename(words[0])
    args = words[1:]

    if verb in ("cd", "pushd"):
        plain = [a for a in args if not a.startswith("-")]
        here = absolute(plain[0], here) if plain and here else None  # bare `cd` and `cd -` are not followed
        continue
    if verb == "popd":
        here = None
        continue

    if verb == "gh":
        if CLOUD and len(args) >= 2 and args[0] == "pr" and args[1] in GH_PR_WRITE:
            out("GH", "pr " + args[1])
        continue

    if verb in OPAQUE:
        continue  # not a finding and not a reason to stop reading the rest

    if verb == "git":
        sub, j, where = None, 0, here
        configured = assigned > 0 or GIT_ENV  # an env var or -c can switch the hooks off for this one command
        while j < len(args):  # skip the pre-command options that carry a value
            if args[j] == "-c" or args[j].startswith("--config-env"):
                configured = True
            if args[j] == "-C" and j + 1 < len(args):
                where = absolute(args[j + 1], where) if where else None
            if args[j].startswith(("--git-dir", "--work-tree")):
                where = None  # another repository than the one the branch is read from
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
        if CLOUD and not configured and cloud_allows(sub, rest, where):
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
  if [ "$kind" = "GH" ]; then
    echo "Blocked by bash-write-guard: 'gh $rest' — in a cloud session a PR is opened or changed through the GitHub tools, whose base pr-base-guard checks (boundaries.md § Never do #10, cloud exception)." >&2
    exit 2
  fi
  if [ "$kind" = "GIT" ]; then
    echo "Blocked by bash-write-guard: 'git $rest' changes repository state, which is the human's to run (boundaries.md § Never do #10)." >&2
    echo "Reading commands — status, log, diff, show, branch --show-current — are unrestricted. Say what you would run and wait." >&2
    if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
      echo "Cloud session: only add, commit, fetch, pull --ff-only and a named push of your own claude/* branch, and creating that branch with -b or -c and --no-track, are allowed (boundaries.md § Never do #10, cloud exception)." >&2
    fi
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
