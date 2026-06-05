#!/usr/bin/env python3
"""lint-rules.py — verbatim canonical-rule duplicate detector.

Reads `docs/rule-canonical-map.md`, extracts each rule's canonical file and
list of verbatim "phrases observed". For every phrase, searches all
`framework/**/*.md` + `docs/**/*.md` files (minus allowlist) for verbatim
occurrences. Reports any occurrence outside the canonical file as drift.

Drift catches both directions:
  - re-introducing a now-removed linking-site phrasing (D3 work undone)
  - copy-pasting a canonical-file phrasing into a new non-canonical site

Allowlist (always exempt):
  - docs/specs/**                  specs may quote rules in their bodies
  - docs/rule-canonical-map.md     the map itself contains canonical text
  - docs/improvements-log.md       lessons may quote rules

Output format mirrors `validate-specs.py`: `path:lineno:check:message`.
Exit non-zero on any finding.

Per spec IMP-20260514-dedup-rule-statements FR-5, stdlib only.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


MAP_PATH = Path("docs/rule-canonical-map.md")
ALLOWLIST_PREFIXES = (
    "docs/specs/",
    "docs/rule-canonical-map.md",
    "docs/improvements-log.md",
)
SEARCH_GLOBS = ("framework/**/*.md", "docs/**/*.md")


@dataclass(frozen=True)
class Rule:
    """A single canonical rule entry parsed from the map."""

    rule_id: str  # e.g. "R1"
    canonical_file: str  # POSIX-relative path, e.g. "framework/boundaries.md"
    phrases: tuple[str, ...]


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    check: str
    message: str

    def render(self, root: Path) -> str:
        return f"{self.path.relative_to(root).as_posix()}:{self.line}:{self.check}:{self.message}"


# ---------------------------------------------------------------------------
# Map parser
# ---------------------------------------------------------------------------

# Section split: each rule entry starts with `### R<N> —`
_SECTION_RE = re.compile(r"^### (R\d+)\b", re.MULTILINE)

# Canonical location row inside a section table:
#   | **Canonical location** | `framework/boundaries.md § Never do #2` |
_CANONICAL_RE = re.compile(
    r"\*\*Canonical location\*\*\s*\|\s*`([^`]+)`"
)

# Verbatim phrases listed under "Verbatim phrases observed":
#   - <source>: *"..."*
# Capture content between *" and "* greedily but excluding the closing "*.
_PHRASE_RE = re.compile(r'\*"((?:[^"]|"(?!\*))+)"\*')


def parse_map(map_text: str) -> list[Rule]:
    """Extract Rule entries from the canonical map."""
    rules: list[Rule] = []
    parts = _SECTION_RE.split(map_text)
    # parts: [preamble, R1, body1, R2, body2, ...]
    for i in range(1, len(parts), 2):
        rule_id = parts[i]
        body = parts[i + 1]
        m_loc = _CANONICAL_RE.search(body)
        if not m_loc:
            continue
        # Canonical-location may be a path with ` § <suffix>`; keep only path.
        loc_raw = m_loc.group(1)
        canonical_file = loc_raw.split(" § ")[0].strip()
        phrases = tuple(_PHRASE_RE.findall(body))
        if not phrases:
            continue
        rules.append(Rule(rule_id=rule_id, canonical_file=canonical_file, phrases=phrases))
    return rules


# ---------------------------------------------------------------------------
# Agent contract phrases (parsed from framework/agents/*.md)
# Added by IMP-20260514-framework-subagents Task S6 (FR-7).
# ---------------------------------------------------------------------------


_AGENT_DESCRIPTION_RE = re.compile(r"^description:\s*(.+)$", re.MULTILINE)


def parse_agents(root: Path) -> list[Rule]:
    """Return one Rule per agent in framework/agents/, with the agent's
    `description:` field as the tracked phrase. The canonical_file is the
    agent's own file — any verbatim appearance of the description text
    elsewhere is drift.

    README.md is skipped: it is the contract document, not an agent.
    Its registry-table descriptions are paraphrases, not verbatim
    duplicates of the agents' `description:` fields.
    """
    rules: list[Rule] = []
    agents_dir = root / "framework" / "agents"
    if not agents_dir.is_dir():
        return rules
    for path in sorted(agents_dir.glob("*.md")):
        if path.name == "README.md":
            continue
        text = path.read_text(encoding="utf-8")
        m = _AGENT_DESCRIPTION_RE.search(text)
        if not m:
            continue
        description = m.group(1).strip()
        # Strip surrounding quotes if present (YAML scalar form).
        if len(description) >= 2 and description[0] == description[-1] and description[0] in {"'", '"'}:
            description = description[1:-1]
        if not description:
            continue
        canonical_file = path.relative_to(root).as_posix()
        rules.append(
            Rule(
                rule_id=f"AGENT-{path.stem}",
                canonical_file=canonical_file,
                phrases=(description,),
            )
        )
    return rules


# ---------------------------------------------------------------------------
# Drift detection
# ---------------------------------------------------------------------------


def find_repo_root(start: Path) -> Path:
    """Walk up until docs/specs/ is found, mirroring validate-specs.py."""
    cur = start.resolve()
    for candidate in [cur, *cur.parents]:
        if (candidate / "docs" / "specs").is_dir():
            return candidate
    raise SystemExit(f"lint-rules: no docs/specs/ ancestor found starting at {start}")


def discover_files(root: Path) -> list[Path]:
    """All .md files under framework/ and docs/, allowlist-filtered."""
    out: list[Path] = []
    for pattern in SEARCH_GLOBS:
        for path in root.glob(pattern):
            rel = path.relative_to(root).as_posix()
            if any(rel.startswith(p) for p in ALLOWLIST_PREFIXES):
                continue
            out.append(path)
    return sorted(out)


def find_drift(root: Path, rules: list[Rule]) -> list[Finding]:
    """Search each non-allowlisted file for verbatim phrase occurrences
    outside the phrase's canonical file."""
    findings: list[Finding] = []
    files = discover_files(root)
    for path in files:
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        for rule in rules:
            if rel == rule.canonical_file:
                continue  # canonical owner is allowed to contain the phrases
            for phrase in rule.phrases:
                if phrase not in text:
                    continue
                # Locate line number for the first occurrence.
                for lineno, line in enumerate(text.splitlines(), start=1):
                    if phrase in line:
                        snippet = phrase if len(phrase) <= 50 else phrase[:47] + "..."
                        findings.append(
                            Finding(
                                path=path,
                                line=lineno,
                                check="rule_duplicate",
                                message=(
                                    f"{rule.rule_id} verbatim text outside canonical "
                                    f"{rule.canonical_file!r}: {snippet!r}"
                                ),
                            )
                        )
                        break
    return findings


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main(argv: list[str]) -> int:
    here = Path(__file__).resolve().parent
    root = find_repo_root(here)
    map_path = root / MAP_PATH
    if not map_path.is_file():
        print(f"lint-rules: canonical map not found at {MAP_PATH}", file=sys.stderr)
        return 2
    rules = parse_map(map_path.read_text(encoding="utf-8"))
    if not rules:
        print("lint-rules: parsed 0 rules from map (parser bug?)", file=sys.stderr)
        return 2

    # Append agent-description rules (one per agent in framework/agents/).
    agent_rules = parse_agents(root)
    rules.extend(agent_rules)

    findings = find_drift(root, rules)
    for f in findings:
        print(f.render(root))

    n_phrases = sum(len(r.phrases) for r in rules)
    n_agents = len(agent_rules)
    n_canonical = len(rules) - n_agents
    if findings:
        print(
            f"\nlint-rules: {len(findings)} finding(s) across "
            f"{n_canonical} canonical rule(s) + {n_agents} agent(s), "
            f"{n_phrases} phrase(s) tracked.",
            file=sys.stderr,
        )
        return 1
    print(
        f"lint-rules: OK ({n_canonical} canonical rule(s) + {n_agents} agent(s); "
        f"{n_phrases} phrase(s) tracked).",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
