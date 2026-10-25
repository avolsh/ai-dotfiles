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
# line. A guard that denied what it did not understand would be switched off within a day. One exception, in a
# cloud session only: a git write or `gh pr` verb with a word the shell decides (`$`, a backtick, a leading
# glob) is denied, since there the guard is what keeps the agent on its own branch (IMP-20261025-cloud-sessions
# FR-6); a quoted -m or -F value of `git commit` may still hold one.
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
# with a regular expression is how a guard starts denying the wrong things. A pre-pass first does what shlex
# cannot: it drops comments, line continuations and heredoc bodies, and sets each substitution aside to be read
# as a command of its own. It prints one record per line:
#   OPEN                     — something unreadable; the whole command is allowed
#   GIT<TAB><verb>           — a state-changing git verb
#   GH<TAB><verb>            — a `gh pr` verb that opens or changes a PR (cloud session only)
#   UNREAD<TAB><what><TAB><word> — a git write or `gh` command with a word the shell decides (cloud only)
#   UNLEXED                  — a command naming git or gh that does not tokenise (cloud only)
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
            "var", "verify-commit", "count-objects", "rev-list", "for-each-ref", "symbolic-ref", "name-rev",
            "merge-base", "ls-remote", "show-ref", "show-branch", "cherry", "range-diff", "version"}
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
SEPARATORS = {";", "&&", "||", "|", "|&", "&", "\n"} | GROUP
# Redirections that write to the word after them; `2>&1`, `>&2` point at a descriptor, not a file.
REDIRECT = {">", ">>", ">|", ">&", "&>", "&>>"}
# Redirections that read the word after them, which is then no argument of the command.
INPUT = {"<", "<<", "<<<", "<&"}
# Shell words that come before the command they run, so the command is the word after them.
PREFIX = {"!", "time", "coproc", "if", "then", "elif", "else", "while", "until", "do"}

SQ, DQ = chr(39), chr(34)
# What the pre-pass puts where the shell expands: `$` for an expansion outside quotes, which the shell may split
# into several words, QUOTED for one inside double quotes, which stays one word, SUB after either for a
# substitution, and LITERAL for a `$` the shell keeps as it is (quoted with `'"'"'` or escaped).
QUOTED, SUB, LITERAL = "\x01", "\x02", "\x03"
HEREDOC = re.compile("<<(-?)[ \\t]*(?:{q}([^{q}\\n]*){q}|{d}([^{d}\\n]*){d}|([^\\s;&|()<>]+))".format(q=SQ, d=DQ))

def scan(s, i, nested, subs):
    """The command from i as shlex should read it, and where it ends: at the end of s or, nested, after the `)`
    closing a `$(`. Comments, line continuations and heredoc bodies go, and so does the descriptor in front of a
    redirection (`2>&1`) wherever its word starts. A substitution leaves a marker, and its body goes to subs, to
    be read as a command of its own."""
    text, n = [], len(s)
    quote, word_start, pending, depth = None, True, [], 0
    while i < n:
        c = s[i]
        if quote == SQ:
            text.append(LITERAL if c == "$" else c); i += 1
            if c == SQ:
                quote = None
            continue
        if c == "\\":
            if s[i + 1:i + 2] == "\n":
                i += 2; continue  # a line continuation joins the two lines
            # an escaped character, or a backslash that ends the command and stands for itself
            text.append(LITERAL if s[i + 1:i + 2] == "$" else s[i:i + 2] if i + 1 < n else "\\\\")
            i += 2; word_start = False
            continue
        if c == "`" or s.startswith("$(", i):
            if c == "`":
                end = i + 1
                while end < n and s[end] != "`":
                    end += 2 if s[end] == "\\" else 1
                subs.append(s[i + 1:end]); i = end + 1
            else:
                end, closed = scan(s, i + 2, True, [])[1:]
                subs.append(s[i + 2:end - 1] if closed else s[i + 2:]); i = end
            text.append((QUOTED if quote == DQ else "$") + SUB); word_start = False; continue
        if c == "$":
            text.append(QUOTED if quote == DQ else "$"); i += 1; word_start = False; continue
        if quote == DQ:
            text.append(c); i += 1
            if c == DQ:
                quote = None
            continue
        if c in (SQ, DQ):
            quote = c; text.append(c); i += 1; word_start = False; continue
        if nested and c == "(":
            depth += 1
        if nested and c == ")":
            if depth == 0:
                return "".join(text), i + 1, True
            depth -= 1
        if c == "#" and word_start:
            while i < n and s[i] != "\n":
                i += 1
            continue
        if word_start and c.isdigit():
            m = re.match(r"\d+(?=[<>])", s[i:])
            if m:
                i += m.end(); continue
        if s.startswith("<<<", i):
            text.append("<<<"); i += 3; word_start = True; continue
        m = HEREDOC.match(s, i)
        if m:
            delim = next(g for g in m.groups()[1:] if g is not None)
            pending.append((delim.replace(SQ, "").replace(DQ, "").replace("\\", ""), m.group(1) == "-"))
            text.append("<< heredoc"); i = m.end(); word_start = False; continue
        if c == "\n":
            text.append(c); i += 1; word_start = True
            for delim, tabs in pending:  # each body starts on the next line, one after the other
                while i < n:
                    end = s.find("\n", i)
                    line = s[i:] if end < 0 else s[i:end]
                    i = n if end < 0 else end + 1
                    if (line.lstrip("\t") if tabs else line) == delim:
                        break
            pending = []
            continue
        text.append(c); i += 1
        word_start = c in " \t;&|()<>"
    return "".join(text), i, False

def absolute(path, base=None):
    base = base or cwd
    path = path.replace(LITERAL, "$")
    return path if os.path.isabs(path) else os.path.normpath(os.path.join(base, path))

def unread(word):
    """A word whose value the shell decides: an expansion, or a glob at its start, which can expand to an option."""
    return "$" in word or QUOTED in word or word[:1] in ("*", "?", "[")

def shown(word):
    for marker, text in ((QUOTED + SUB, "$(...)"), ("$" + SUB, "$(...)"), (QUOTED, "$"), (LITERAL, "$")):
        word = word.replace(marker, text)
    return word

CLOUD = os.environ.get("CLAUDE_CODE_REMOTE") == "true"
AGENT = "claude/"
GH_PR_WRITE = {"create", "new", "edit", "merge", "ready", "close", "reopen", "revert", "update-branch"}  # `new` is gh'"'"'s alias of create
CHECKOUT_DENY = {"-f", "--force", "--discard-changes", "-m", "--merge"}  # each discards or rewrites local work
PUSH_DENY = {"-f", "--force", "--force-with-lease", "--force-if-includes", "-d", "--delete", "--mirror",
             "--all", "--tags", "--prune"}

def denied(args, options):
    """An argument naming one of options, including the unique abbreviations git accepts (`--no-verif`)."""
    for a in args:
        name = a.split("=", 1)[0]
        if name in options:
            return True
        if name.startswith("--") and len(name) > 2 and any(o.startswith(name) for o in options):
            return True
    return False

def messages(rest):
    """Positions of the -m and -F values of a git commit that the shell keeps one word each: these alone may
    hold an expansion, a commit message written with a heredoc substitution among them."""
    found = set()
    for k, a in enumerate(rest):
        if a in ("--message", "--file"):
            found.add(k + 1)
        elif a.startswith(("--message=", "--file=")):
            found.add(k)
        elif a.startswith("-") and not a.startswith("--"):
            p = next((p for p, ch in enumerate(a) if p and ch in "mF"), None)
            if p is not None:
                found.add(k if p < len(a) - 1 else k + 1)  # `-mtext`, or the word after `-am`
    return {k for k in found if k < len(rest) and "$" not in rest[k]}

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

def read(command, here, nested, env):
    """Prints the findings of one command, or, nested, of the body of a substitution in one. False when the
    command cannot be tokenised."""
    subs = []
    try:
        # A newline ends a command as `;` does, so it is an operator here and not whitespace. The pre-pass has
        # taken the comments out, so a `#` that is left is a character of its word.
        lexer = shlex.shlex(scan(command, 0, False, subs)[0], posix=True, punctuation_chars="();<>|&\n")
        lexer.whitespace_split = True
        lexer.whitespace = " \t\r"
        lexer.commenters = ""
        tokens = list(lexer)
    except Exception:
        # bash runs each line before it reads the next, so a git write ahead of an unclosed quote still runs;
        # in the cloud a command that names git or gh must tokenise
        if CLOUD and re.search(r"(?<![\w.-])(git|gh)(?![\w.-])", command):
            out("UNLEXED"); return True
        return False
    # The lexer keeps a run of operator characters as one token (`)&&`, `((`); split it into its operators,
    # keeping each redirection (`>&`, `&>`, `<<`) whole.
    OPERATOR = r"&>>|&>|>&|<&|>\||\|&|<<<|<<-|<<|>>|&&|\|\||[;&|()<>\n]"
    tokens = [part for t in tokens
              for part in (re.findall(OPERATOR, t) if t and all(c in "();<>|&\n" for c in t) else [t])]

    # An expansion or a glob means the path this reader would resolve is not the path the shell will write
    # to. Outside the cloud the command is then left alone; in the cloud its paths are, while its git and gh
    # words are still read, and one the shell decides denies a git write (FR-6).
    hidden = any("$" in t or QUOTED in t or any(ch in t for ch in "*?[") and not t.startswith("-") for t in tokens)
    if hidden and not CLOUD:
        out("OPEN"); return True
    paths = not hidden and not nested

    segments, current = [], []
    for t in tokens:
        if t in SEPARATORS:
            if current:
                segments.append(current); current = []
        else:
            current.append(t)
    if current:
        segments.append(current)

    # Cloud mode only: a `cd` earlier in the same command moves the repository a later git write lands in, so
    # the branch the cloud exception checks is read there. None once it cannot be followed. Write paths still
    # resolve against the payload cwd, as they always have.
    start = here
    moves = any(t in ("cd", "pushd", "popd") for t in tokens)
    # A `cd` inside a group moves that group alone, which this reader does not track: with both in one command
    # the repository a git write lands in is unknown (FR-6).
    if moves and any(t in GROUP for t in tokens):
        here = None
    moved_by = None  # the word of a `cd` the shell decides, which left the repository unknown

    # A GIT_* variable set anywhere in the command (`export GIT_CONFIG_COUNT=1 …; git commit`) can reconfigure
    # the git that runs after it; shell state does not outlive one command, so the command is all there is.
    # A name the shell decides (`export $K=1`) may be one of them.
    env = env or CLOUD and (any(t.startswith("GIT_") and "=" in t for t in tokens) or
                            any(a in ("export", "declare", "typeset", "readonly", "local") and unread(b)
                                for a, b in zip(tokens, tokens[1:])))

    for seg in segments:
        # Redirections write wherever they point, whatever the command in front of them is.
        i = 0
        while i < len(seg):
            if seg[i] in REDIRECT and i + 1 < len(seg):
                if paths and not (seg[i + 1].isdigit() or seg[i + 1] == "-"):
                    out("PATH", seg[i], absolute(seg[i + 1]))
                i += 2
                continue
            i += 1
        # Drop each redirection and its word, so the words after it still reach the command.
        words, skip = [], False
        for w in seg:
            if skip:
                skip = False; continue
            if w in REDIRECT or w in INPUT:
                skip = True; continue
            words.append(w)
        while words and words[0] in PREFIX:
            flags = words[0] == "time"
            words = words[1:]
            while flags and words and words[0].startswith("-"):
                words = words[1:]  # `time -p`
        if not words:
            continue
        # Leading NAME=value assignments (GIT_CONFIG_COUNT=…, say) can reconfigure git for that one command.
        assigned = 0
        while assigned < len(words) - 1 and "=" in words[assigned] and not words[assigned].startswith("-"):
            assigned += 1
        words = words[assigned:]
        verb = os.path.basename(words[0])
        args = words[1:]

        if verb in ("cd", "pushd"):
            plain = [a for a in args if not a.startswith("-")]
            if plain and unread(plain[0]):
                moved_by = moved_by or plain[0]
            # bare `cd` and `cd -` are not followed
            here = absolute(plain[0], here) if plain and here and not unread(plain[0]) else None
            continue
        if verb == "popd":
            here = None
            continue

        if verb == "gh":
            # `-R/--repo` may stand before `pr` or before its verb; the verb is the second word that is no flag.
            plain, k = [], 0
            while k < len(args):
                if args[k] in ("-R", "--repo"):
                    k += 2; continue
                if not args[k].startswith("-"):
                    plain.append(args[k])
                k += 1
            if CLOUD:
                named = plain[:2] if plain[:1] == ["pr"] else plain[:1]
                hid = next((w for w in named if unread(w)), None)
                if hid is not None:
                    out("UNREAD", "gh", shown(hid))
                elif len(plain) >= 2 and plain[0] == "pr" and plain[1] in GH_PR_WRITE:
                    out("GH", "pr " + plain[1])
            continue

        if verb in OPAQUE:
            continue  # not a finding and not a reason to stop reading the rest

        if verb == "git":
            sub, j, where = None, 0, here
            configured = assigned > 0 or env  # an env var or -c can switch the hooks off for this one command
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
            if sub is None:
                continue
            if CLOUD and unread(sub):
                out("UNREAD", "git", shown(sub)); continue
            if sub in GIT_READ:
                continue
            if sub in GIT_MAYBE:
                readable = GIT_READ_FLAGS.get(sub, set())
                if not rest and sub in GIT_BARE_IS_READ:
                    continue
                if rest and any(r in readable for r in rest):
                    continue
            if CLOUD:
                kept = messages(rest) if sub == "commit" else set()
                hid = next((w for w in args[:j] + [w for k, w in enumerate(rest) if k not in kept] if unread(w)),
                           None)
                if hid is None and where is None:
                    hid = moved_by
                if hid is not None:
                    out("UNREAD", "git " + sub, shown(hid)); continue
                if not configured and cloud_allows(sub, rest, where):
                    continue
            out("GIT", sub)
            continue

        if not paths:
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

    # The body of a substitution runs as a command of its own, in the cloud read as one: a git write there is a
    # git write. A cd anywhere in the command leaves the repository it runs in unknown.
    if CLOUD:
        for body in subs:
            read(body, None if moves else start, True, env)
    return True

if not read(command, cwd, False, False):
    out("OPEN")
')"

[ -n "$findings" ] || exit 0
printf '%s\n' "$findings" | grep -qxF "OPEN" && exit 0

while IFS= read -r finding; do
  [ -n "$finding" ] || continue
  kind="${finding%%	*}"
  rest="${finding#*	}"
  if [ "$kind" = "UNLEXED" ]; then
    echo "Blocked by bash-write-guard: this command names git or gh and does not tokenise (an unclosed quote, say); bash would still run the lines before the error. In a cloud session such a command must be readable (boundaries.md § Never do #10, cloud exception)." >&2
    exit 2
  fi
  if [ "$kind" = "UNREAD" ]; then
    echo "Blocked by bash-write-guard: '${rest%%	*}' depends on '${rest#*	}', whose value the shell decides and this guard cannot read." >&2
    echo "Cloud session: a git write and a gh pr command name their words literally — the branch, the path, the option — a glob starts with ./, and a substitution goes only in a quoted -m or -F value of git commit (boundaries.md § Never do #10, cloud exception)." >&2
    exit 2
  fi
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
