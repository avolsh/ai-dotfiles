#!/usr/bin/env python3
"""check-make-contract.py — checks a repository's Makefile against the make contract.

Implements docs/make-contract.md § Conformance check. Targets and variables come
from the database make itself builds (`make -pRrq -f Makefile :`), so targets
defined through includes or pattern rules count; the Makefile text is never
parsed. With components, every Makefile named in the root's `$(MAKE) -C <path>`
recipes is checked the same way.

Fails (exit 1) when:
  1. a target of a declared tier is missing;
  2. a name in MAKE_CONTRACT_REQUIRED is not defined;
  3. a naming-rule-3 alias, or a name in MAKE_CONTRACT_RETIRED, is defined;
  4. a recipe calls `make <t>` / `$(MAKE) <t>` for a target the Makefile does not define;
  5. a recipe runs a `_dev/*.sh` path that does not exist (paths inside a
     consumed library — a git-ignored directory deps-install has not fetched yet — are exempt);
  6. SHELL is not /bin/sh, or .gitattributes does not set eol=lf for
     Makefile, *.mk and *.sh.
A missing or invalid MAKE_CONTRACT_TIERS fails as `declarations`.

Output: one line per finding, `make-contract: <rule> <target> — <detail>`; on
success `make-contract: <tiers>, <n> targets, conforms`. Exit 2 when make
itself cannot run. Standard library only.

Usage: check-make-contract.py [repo-root]   (default: current directory)
"""

from __future__ import annotations

import fnmatch
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

TIERS = {
    "core": ("help", "clean", "build", "docs-check", "quality-gates-check", "sync-agents", "sync-agents-check"),
    "code": ("format", "lint", "typecheck", "test", "run", "dup-report", "audit", "deps-install", "deps-update",
             "env-local"),
}
VALID_TIER_SETS = ("core", "core code")
# Naming rule 3: second names for a tier action.
ALIASES = ("clear", "purge", "dev", "start", "serve", "admin", "check")
LF_PATTERNS = ("Makefile", "*.mk", "*.sh")

TARGET_RE = re.compile(r"^([^\s#][^=]*?)::?(?:\s|$)")
MAKE_WORDS = ("make", "$(MAKE)", "${MAKE}")
DEV_SCRIPT_RE = re.compile(r"^(?:\./)?(?:[^\s'\";()]*/)?_dev/[^\s'\";()]+\.sh$")
# A script is run when it is the command word, or the operand of one of these.
SCRIPT_RUNNERS = ("sh", "bash", "zsh", "source", ".", "exec", "chmod")
COMMAND_SPLIT_RE = re.compile(r"&&|\|\||[;|&]")
VAR_REF_RE = re.compile(r"\$[({]([A-Za-z_][A-Za-z0-9_]*)[)}]")


class MakeUnavailable(Exception):
    pass


@dataclass
class Database:
    variables: dict[str, str] = field(default_factory=dict)  # makefile-origin only
    targets: dict[str, list[str]] = field(default_factory=dict)  # explicit target -> recipe lines
    patterns: list[str] = field(default_factory=list)

    def defines(self, name: str) -> bool:
        if name in self.targets:
            return True
        return any(fnmatch.fnmatchcase(name, p.replace("%", "*")) for p in self.patterns)


@dataclass(frozen=True)
class Finding:
    rule: str
    target: str
    detail: str

    def render(self, component: str) -> str:
        where = f"[{component}] " if component else ""
        return f"make-contract: {self.rule} {where}{self.target} — {self.detail}"


def read_database(directory: Path) -> Database:
    try:
        proc = subprocess.run(["make", "-pRrq", "-f", "Makefile", ":"], cwd=directory,
                              capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise MakeUnavailable(str(exc)) from exc
    errors = [line for line in proc.stderr.splitlines()
              if "***" in line and "No rule to make target" not in line]
    if "# Make data base" not in proc.stdout or errors:
        raise MakeUnavailable("; ".join(errors) or "make printed no database")
    return parse_database(proc.stdout)


def parse_database(text: str) -> Database:
    db = Database()
    section = ""
    lines = text.splitlines()
    origin = ""
    prev = ""
    current: list[str] | None = None
    for line in lines:
        if line.startswith("# Variables"):
            section = "vars"
        elif line.startswith("# Implicit Rules"):
            section = "implicit"
        elif line.startswith("# Files"):
            section = "files"
        elif line.startswith(("# VPATH", "# Pattern-specific", "# Directories", "# finished")):
            section = ""
        if section == "vars":
            if line.startswith("# "):
                origin = line
            else:
                m = re.match(r"^([A-Za-z_.][\w.-]*)\s*(?::{1,2}=|\?=|\+=|=)\s?(.*)$", line)
                if m and origin.startswith("# makefile (from"):  # bare "# makefile" is make's own default
                    db.variables[m.group(1)] = m.group(2).strip()
            continue
        if line.startswith("\t"):
            if current is not None:
                current.append(line[1:])
            continue
        if line.startswith("#"):
            if line.strip():
                prev = line
            continue
        current = None
        m = TARGET_RE.match(line)
        if m and section in ("implicit", "files") and not re.match(r"^[^:]*:{1,2}=", line):
            names = m.group(1).split()
            if section == "implicit":
                db.patterns.extend(n for n in names if "%" in n)
            elif prev != "# Not a target:":
                recipe: list[str] = []
                for name in names:
                    if not name.startswith(".") and "%" not in name:
                        db.targets.setdefault(name, recipe)
                current = recipe
        if line.strip():
            prev = line
    return db


def expand(text: str, variables: dict[str, str]) -> str:
    for _ in range(5):
        new = VAR_REF_RE.sub(lambda m: variables.get(m.group(1), m.group(0)) if m.group(1) != "MAKE" else m.group(0),
                             text)
        if new == text:
            break
        text = new
    return text


def command_words(recipe_line: str) -> list[list[str]]:
    """The words of each shell command in a recipe line, split on ; && || | &, without make's @+- prefix."""
    commands = []
    for command in COMMAND_SPLIT_RE.split(recipe_line):
        command = command.strip().lstrip("@+-").strip()
        try:
            words = shlex.split(command)
        except ValueError:
            words = command.split()
        while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):
            words = words[1:]  # leading VAR=value assignments
        if words:
            commands.append(words)
    return commands


def make_calls(recipe_line: str) -> list[tuple[str | None, list[str]]]:
    """Every make invocation in a recipe line as (directory or None, goal targets).

    Only `make` / `$(MAKE)` as the command word counts, so `echo "make build"` is not a call. A `cd <dir>`
    earlier in the same line, or `-C <dir>`, makes it a call into that directory.
    """
    calls = []
    cwd = None
    for words in command_words(recipe_line):
        if words[0] == "cd":
            cwd = words[1] if len(words) > 1 else None
            continue
        if words[0] not in MAKE_WORDS:
            continue
        directory, goals, i = cwd, [], 1
        while i < len(words):
            word = words[i]
            if word in ("-C", "-f", "-I", "-o", "-W", "-j", "--directory", "--file"):
                if word in ("-C", "--directory") and i + 1 < len(words):
                    directory = words[i + 1] if directory is None else f"{directory}/{words[i + 1]}"
                i += 2
                continue
            if word.startswith("-C") and len(word) > 2:
                directory = word[2:]
            elif not word.startswith("-") and "=" not in word:
                goals.append(word)
            i += 1
        calls.append((directory, goals))
    return calls


def run_scripts(recipe_line: str) -> list[str]:
    """`_dev/*.sh` paths a recipe line runs (as the command, or via sh/bash/source/chmod), not ones it mentions."""
    scripts = []
    for words in command_words(recipe_line):
        if words[0] in SCRIPT_RUNNERS:
            operands = [w for w in words[1:] if not w.startswith("-") and "+" not in w]
            candidates = operands[-1:] if words[0] == "chmod" else operands[:1]
        else:
            candidates = words[:1]
        scripts.extend(c for c in candidates if DEV_SCRIPT_RE.match(c))
    return scripts


def git_ignored(directory: Path, path: str) -> bool:
    """True when git ignores `path` — the mark of a library that deps-install fetches (e.g. `_lib/<name>`)."""
    try:
        proc = subprocess.run(["git", "check-ignore", "-q", "--no-index", path], cwd=directory,
                              capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return proc.returncode == 0


def gitattributes_lf(root: Path) -> list[str]:
    """Patterns of LF_PATTERNS that .gitattributes does not pin to eol=lf."""
    path = root / ".gitattributes"
    lf: set[str] = set()
    if path.is_file():
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            parts = raw.split("#", 1)[0].split()
            if len(parts) >= 2 and "eol=lf" in parts[1:]:
                lf.add(parts[0])
    if "*" in lf:
        return []
    return [p for p in LF_PATTERNS if p not in lf]


def check(directory: Path, repo_root: Path, db: Database) -> tuple[list[Finding], list[Path], str]:
    findings: list[Finding] = []
    components: list[Path] = []
    tiers = " ".join(db.variables.get("MAKE_CONTRACT_TIERS", "").split())
    if tiers not in VALID_TIER_SETS:
        findings.append(Finding("declarations", "MAKE_CONTRACT_TIERS",
                                f"is {tiers or 'unset'!r}; expected 'core' or 'core code'"))
    for tier in (tiers.split() if tiers in VALID_TIER_SETS else []):
        for target in TIERS[tier]:
            if not db.defines(target):
                findings.append(Finding("rule-1", target, f"{tier}-tier target is not defined"))
    for name in db.variables.get("MAKE_CONTRACT_REQUIRED", "").split():
        if not db.defines(name):
            findings.append(Finding("rule-2", name, "listed in MAKE_CONTRACT_REQUIRED but not defined"))
    retired = db.variables.get("MAKE_CONTRACT_RETIRED", "").split()
    for name in dict.fromkeys([*ALIASES, *retired]):
        if name in db.targets:
            why = "retired by MAKE_CONTRACT_RETIRED" if name in retired else "second name for a tier action"
            findings.append(Finding("rule-3", name, f"is defined; it is a {why}"))
    for target, recipe in sorted(db.targets.items()):
        for line in recipe:
            line = expand(line, db.variables)
            for sub_dir, goals in make_calls(line):
                if sub_dir is not None:
                    if "$" not in sub_dir:
                        path = (directory / sub_dir).resolve()
                        if path != directory.resolve() and path not in components:
                            components.append(path)
                    continue
                for goal in goals:
                    if "$" not in goal and not db.defines(goal):
                        findings.append(Finding("rule-4", target, f"recipe calls undefined target '{goal}'"))
            for script in run_scripts(line):
                if "$" in script:
                    continue
                path = directory / script
                prefix = script.split("_dev/", 1)[0].rstrip("/")
                if prefix and prefix != "." and not (directory / prefix).is_dir() and git_ignored(directory, prefix):
                    continue  # inside a consumed library that deps-install has not fetched yet
                if not path.is_file():
                    findings.append(Finding("rule-5", target, f"recipe runs missing script '{script}'"))
    if db.variables.get("SHELL") != "/bin/sh":
        findings.append(Finding("rule-6", "SHELL", f"is {db.variables.get('SHELL', 'unset')!r}; set SHELL := /bin/sh"))
    if directory.resolve() == repo_root.resolve():
        for pattern in gitattributes_lf(repo_root):
            findings.append(Finding("rule-6", ".gitattributes", f"does not set eol=lf for {pattern}"))
    return findings, components, tiers


def main(argv: list[str]) -> int:
    root = Path(argv[1] if len(argv) > 1 else ".").resolve()
    if not (root / "Makefile").is_file():
        print(f"make-contract: declarations Makefile — no Makefile in {root}")
        return 1
    queue, seen, failed = [root], set(), False
    while queue:
        directory = queue.pop(0)
        if directory in seen:
            continue
        seen.add(directory)
        component = "" if directory == root else str(directory.relative_to(root)) if directory.is_relative_to(
            root) else str(directory)
        if not (directory / "Makefile").is_file():
            continue  # a -C directory without its own Makefile delegates nothing to check
        try:
            db = read_database(directory)
        except MakeUnavailable as exc:
            print(f"make-contract: make cannot run in {directory}: {exc}", file=sys.stderr)
            return 2
        findings, components, tiers = check(directory, root, db)
        queue.extend(components)
        for finding in findings:
            print(finding.render(component))
        if findings:
            failed = True
        else:
            where = f"[{component}] " if component else ""
            count = sum(1 for t in db.targets if not (directory / t).is_file())
            print(f"make-contract: {where}{tiers}, {count} targets, conforms")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
