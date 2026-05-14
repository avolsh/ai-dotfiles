#!/usr/bin/env python3
"""validate-specs.py — deterministic spec-corpus validator.

Implements the check classes mandated by IMP-20260514-spec-validator. Each
check class is a function named `check_<name>(specs)` returning a list of
Finding objects. The main entry point discovers specs under
`docs/specs/{active,archived}/`, runs every registered check, prints
findings as `path:lineno:check:message`, and exits non-zero when any
finding is emitted.

Design decisions (per spec FR-7 — stdlib only):

- YAML front-matter is parsed by a deliberately-minimal inline parser
  (`_parse_front_matter`). It handles only the subset present in the
  framework's spec front-matter schema:
    * `key: scalar` (string, int, bool literal)
    * `key:` followed by 2-space-indented `- item` list entries
    * `key: []` empty-list shorthand
    * `# comment` lines and blank lines
  Anything else is reported as a parser finding rather than crashing.
  This keeps the validator zero-dependency without pulling PyYAML.

- The repository root is auto-detected by walking up from the script
  location until a `docs/specs/` directory is found.

Task scope (F1): scaffolding + ONE production check class
(`check_filename_pattern`). Stubs for the remaining seven classes are
present and registered, but return [] until F2-F4 fill them in. This
keeps the harness shape stable and the dispatch table honest.
"""

from __future__ import annotations

import datetime as _dt
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable


# ---------------------------------------------------------------------------
# Domain types
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Spec:
    """A spec file on disk, with its parsed front-matter and body text."""

    path: Path
    front_matter: dict[str, object]
    body: str  # raw body without front-matter
    front_matter_end_line: int  # 1-indexed line where '---' closes


@dataclass(frozen=True)
class Finding:
    """A single validation problem. Rendered as path:line:check:message."""

    path: Path
    line: int
    check: str
    message: str

    def render(self, root: Path) -> str:
        rel = self.path.relative_to(root)
        return f"{rel}:{self.line}:{self.check}:{self.message}"


# ---------------------------------------------------------------------------
# Minimal YAML front-matter parser (zero deps per FR-7)
# ---------------------------------------------------------------------------


_SCALAR_BOOLS = {"true": True, "false": False, "yes": True, "no": False}


def _coerce_scalar(raw: str) -> object:
    """Coerce a YAML scalar string to Python: bool / int / string."""
    raw = raw.strip()
    if not raw:
        return ""
    low = raw.lower()
    if low in _SCALAR_BOOLS:
        return _SCALAR_BOOLS[low]
    if raw.lstrip("-").isdigit():
        return int(raw)
    # Strip matching surrounding quotes
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in {"'", '"'}:
        return raw[1:-1]
    return raw


def _parse_front_matter(
    text: str, path: Path
) -> tuple[dict[str, object], str, int, list[Finding]]:
    """Return (front_matter, body, end_line, parser_findings).

    end_line is the 1-indexed line number of the closing '---' fence.
    parser_findings carries any non-fatal parser complaints.
    """
    findings: list[Finding] = []
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        findings.append(
            Finding(path, 1, "front_matter_missing", "no opening '---' fence")
        )
        return {}, text, 0, findings

    # Find closing fence
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        findings.append(
            Finding(path, len(lines), "front_matter_missing", "no closing '---' fence")
        )
        return {}, text, 0, findings

    fm_lines = lines[1:end]
    body = "\n".join(lines[end + 1 :])
    fm: dict[str, object] = {}
    current_key: str | None = None
    current_list: list[object] | None = None

    for offset, raw in enumerate(fm_lines, start=2):  # +2 = past opening fence
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        # List item under current_key
        if raw.startswith("  - ") or raw.startswith("- "):
            if current_list is None:
                findings.append(
                    Finding(path, offset, "front_matter_parse", "list item without key")
                )
                continue
            item = raw.lstrip()[2:].strip()
            current_list.append(_coerce_scalar(item))
            continue
        # key: value or key:
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$", raw)
        if not m:
            findings.append(
                Finding(path, offset, "front_matter_parse", f"unparseable line: {raw!r}")
            )
            current_list = None
            continue
        key, value = m.group(1), m.group(2)
        if value == "" or value == "[]":
            current_key = key
            current_list = [] if value == "" else []
            fm[key] = current_list
            continue
        fm[key] = _coerce_scalar(value)
        current_key = key
        current_list = None

    return fm, body, end + 1, findings


# ---------------------------------------------------------------------------
# Spec discovery
# ---------------------------------------------------------------------------


def find_repo_root(start: Path) -> Path:
    """Walk up from `start` until a `docs/specs` directory is found."""
    cur = start.resolve()
    for candidate in [cur, *cur.parents]:
        if (candidate / "docs" / "specs").is_dir():
            return candidate
    raise SystemExit(
        f"validate-specs: no docs/specs/ ancestor found starting at {start}"
    )


def discover_specs(root: Path) -> tuple[list[Spec], list[Finding]]:
    """Load every *.md under docs/specs/{active,archived}/."""
    specs: list[Spec] = []
    findings: list[Finding] = []
    for sub in ("active", "archived"):
        d = root / "docs" / "specs" / sub
        if not d.is_dir():
            continue
        for path in sorted(d.glob("*.md")):
            if path.name == "README.md":
                continue
            text = path.read_text(encoding="utf-8")
            fm, body, end_line, parse_findings = _parse_front_matter(text, path)
            findings.extend(parse_findings)
            specs.append(
                Spec(
                    path=path,
                    front_matter=fm,
                    body=body,
                    front_matter_end_line=end_line,
                )
            )
    return specs, findings


# ---------------------------------------------------------------------------
# Check classes
# ---------------------------------------------------------------------------

# Schema enums + patterns (per spec-lifecycle.md § Front-matter schema).
_TYPE_ENUM = {"CR", "BUG", "IMP", "RES"}
_STATUS_ENUM = {"specify", "plan", "in-progress", "done"}
_RISK_ENUM = {"low", "medium", "high"}
_SEVERITY_ENUM = {"low", "medium", "high", "critical"}
_MODEL_ENUM = {"fast", "default", "deep"}
_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# Unconditional required front-matter fields. `risk` / `severity` are
# type-conditional and handled separately.
_REQUIRED_FIELDS = (
    "id",
    "type",
    "date",
    "status",
    "owner",
    "affected-repos",
    "affected-docs",
    "affected-code",
    "skills",
    "model-suggestion",
)

# Fields whose value MUST be a list (front-matter parser may emit []
# for empty-list shorthand `key: []`).
_LIST_FIELDS = (
    "affected-repos",
    "affected-docs",
    "affected-code",
    "skills",
    "siblings",
    "depends-on",
    "cites-reqs",
)

# FR-1 check #3 — naming pattern (production-ready in F1).
_NAMING_RE = re.compile(r"^(CR|BUG|IMP|RES)-\d{8}-[a-z0-9-]+\.md$")


def check_naming_pattern(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #3 — filename matches <TYPE>-YYYYMMDD-<kebab>.md."""
    findings: list[Finding] = []
    for spec in specs:
        if not _NAMING_RE.match(spec.path.name):
            findings.append(
                Finding(
                    spec.path,
                    1,
                    "naming_pattern",
                    f"filename does not match (CR|BUG|IMP|RES)-YYYYMMDD-<kebab>.md",
                )
            )
    return findings


def check_front_matter_schema(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #1 — front-matter schema.

    Validates (per spec-lifecycle.md § Front-matter schema):
      * Every unconditional required field is present (_REQUIRED_FIELDS).
      * `type`, `status`, `model-suggestion` values are in their enums.
      * `date` matches YYYY-MM-DD.
      * For type=CR/IMP, `risk` is present and in _RISK_ENUM.
      * For type=BUG, `severity` is present and in _SEVERITY_ENUM.
      * List-shaped fields are actually lists.
    """
    findings: list[Finding] = []
    for spec in specs:
        fm = spec.front_matter
        line = spec.front_matter_end_line or 1

        # Required fields
        for field in _REQUIRED_FIELDS:
            if field not in fm:
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "schema_missing_field",
                        f"required field '{field}' missing",
                    )
                )

        # Enum checks
        if "type" in fm and fm["type"] not in _TYPE_ENUM:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "schema_enum",
                    f"type={fm['type']!r} not in {sorted(_TYPE_ENUM)}",
                )
            )
        if "status" in fm and fm["status"] not in _STATUS_ENUM:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "schema_enum",
                    f"status={fm['status']!r} not in {sorted(_STATUS_ENUM)}",
                )
            )
        if "model-suggestion" in fm and fm["model-suggestion"] not in _MODEL_ENUM:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "schema_enum",
                    f"model-suggestion={fm['model-suggestion']!r} "
                    f"not in {sorted(_MODEL_ENUM)}",
                )
            )

        # Date format
        if "date" in fm:
            d = fm["date"]
            if not isinstance(d, str) or not _DATE_RE.match(d):
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "schema_date_format",
                        f"date={d!r} does not match YYYY-MM-DD",
                    )
                )

        # Type-conditional requiredness (independent of value-validation)
        spec_type = fm.get("type")
        if spec_type in {"CR", "IMP"} and "risk" not in fm:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "schema_conditional",
                    f"type={spec_type} requires 'risk' field",
                )
            )
        if spec_type == "BUG" and "severity" not in fm:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "schema_conditional",
                    "type=BUG requires 'severity' field",
                )
            )
        # Unconditional value-validation when present
        if "risk" in fm and fm["risk"] not in _RISK_ENUM:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "schema_enum",
                    f"risk={fm['risk']!r} not in {sorted(_RISK_ENUM)}",
                )
            )
        if "severity" in fm and fm["severity"] not in _SEVERITY_ENUM:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "schema_enum",
                    f"severity={fm['severity']!r} not in {sorted(_SEVERITY_ENUM)}",
                )
            )

        # List-shaped fields
        for field in _LIST_FIELDS:
            if field in fm and not isinstance(fm[field], list):
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "schema_type",
                        f"field '{field}' must be a list, got {type(fm[field]).__name__}",
                    )
                )

    return findings


def check_dependency_graph(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #4 — siblings / depends-on graph + rule #10 enforcement.

    Validates:
      * Every `siblings:` and `depends-on:` ID resolves to a known spec.
      * `depends-on:` graph has no cycles (3-colour DFS).
      * Rule #10: no spec at `plan` or `in-progress` may have an
        unmet (non-`done`) `depends-on:` entry.
    """
    specs_list = list(specs)
    findings: list[Finding] = []

    # Build id → spec index
    by_id: dict[str, Spec] = {}
    for spec in specs_list:
        sid = spec.front_matter.get("id")
        if isinstance(sid, str):
            by_id[sid] = spec

    # Resolution: dangling siblings / depends-on
    for spec in specs_list:
        for field in ("siblings", "depends-on"):
            refs = spec.front_matter.get(field) or []
            if not isinstance(refs, list):
                continue
            for ref in refs:
                if not isinstance(ref, str):
                    continue
                if ref not in by_id:
                    findings.append(
                        Finding(
                            spec.path,
                            spec.front_matter_end_line or 1,
                            "deps_dangling",
                            f"{field} references unknown spec id: {ref!r}",
                        )
                    )

    # Cycle detection on depends-on graph
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {sid: WHITE for sid in by_id}

    def dfs(sid: str, stack: list[str]) -> None:
        color[sid] = GRAY
        spec = by_id[sid]
        deps = spec.front_matter.get("depends-on") or []
        if isinstance(deps, list):
            for dep in deps:
                if not isinstance(dep, str) or dep not in by_id:
                    continue
                if color[dep] == GRAY:
                    cycle = " -> ".join(stack[stack.index(dep):] + [sid, dep])
                    findings.append(
                        Finding(
                            spec.path,
                            spec.front_matter_end_line or 1,
                            "deps_cycle",
                            f"depends-on cycle: {cycle}",
                        )
                    )
                    continue
                if color[dep] == WHITE:
                    dfs(dep, stack + [sid])
        color[sid] = BLACK

    for sid in by_id:
        if color[sid] == WHITE:
            dfs(sid, [])

    # Rule #10 — no plan/in-progress with unmet depends-on
    for spec in specs_list:
        status = spec.front_matter.get("status")
        if status not in {"plan", "in-progress"}:
            continue
        deps = spec.front_matter.get("depends-on") or []
        if not isinstance(deps, list):
            continue
        for dep in deps:
            if not isinstance(dep, str) or dep not in by_id:
                continue
            dep_status = by_id[dep].front_matter.get("status")
            if dep_status != "done":
                findings.append(
                    Finding(
                        spec.path,
                        spec.front_matter_end_line or 1,
                        "deps_rule_10",
                        f"status={status} but depends-on {dep!r} is at "
                        f"status={dep_status!r} (must be 'done')",
                    )
                )

    return findings


def check_filename_id_parity(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #2 — basename without .md equals the `id` front-matter field."""
    findings: list[Finding] = []
    for spec in specs:
        expected = spec.path.stem  # filename without .md
        actual = spec.front_matter.get("id")
        if not isinstance(actual, str):
            # Schema check will already flag missing id; don't double-fire.
            continue
        if actual != expected:
            findings.append(
                Finding(
                    spec.path,
                    spec.front_matter_end_line or 1,
                    "filename_id_parity",
                    f"id={actual!r} does not match filename stem {expected!r}",
                )
            )
    return findings


# Match a markdown table separator row: `|---|---|...` with optional
# colons (alignment) and whitespace. Two-or-more pipe-segments suffice.
_TABLE_SEP_RE = re.compile(r"^\s*\|(?:\s*:?-+:?\s*\|)+\s*$")


def _has_tasks_table(body: str) -> bool:
    """True iff the body has a `## Tasks` H2 followed by an actual table.

    Scans from the `## Tasks` header to the next H2 (or EOF) looking for
    a markdown table-separator row. Prose-only Tasks sections (e.g.,
    'Pending — Plan stage only.') are not flagged.
    """
    lines = body.splitlines()
    in_tasks = False
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith("## "):
            if in_tasks:
                return False  # left the section without finding a table
            in_tasks = stripped[3:].strip().lower() == "tasks"
            continue
        if in_tasks and _TABLE_SEP_RE.match(line):
            return True
    return False


def check_status_invariants(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #8 — status / location invariants.

    Three rules:
      * `## Tasks` table forbidden while status is `specify`
        (spec-lifecycle § Rules #2).
      * `done` specs MUST live in archived/, not active/.
      * Anything other than `done` MUST NOT live in archived/.
    """
    findings: list[Finding] = []
    for spec in specs:
        status = spec.front_matter.get("status")
        location = spec.path.parent.name  # 'active' or 'archived'
        line = spec.front_matter_end_line or 1

        if status == "specify" and _has_tasks_table(spec.body):
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "status_tasks_table",
                    "`## Tasks` table present while status='specify' "
                    "(spec-lifecycle § Rules #2)",
                )
            )

        if location == "active" and status == "done":
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "status_location",
                    "status='done' but file lives in active/ (move to archived/)",
                )
            )

        if location == "archived" and status not in {"done", None}:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "status_location",
                    f"status={status!r} but file lives in archived/ "
                    "(only 'done' allowed in archived/)",
                )
            )
    return findings


# Pattern: `*Last updated: YYYY-MM-DD*` anywhere in the body.
_LAST_UPDATED_RE = re.compile(r"\*Last updated:\s*(\d{4}-\d{2}-\d{2})\*")
_FRESHNESS_MAX_DAYS = 60


def check_freshness(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #5 — `*Last updated:*` ≤60 days for specs in active/.

    Specs in archived/ are skipped (they are immutable post-closure).
    A missing `*Last updated:*` line in an active spec is also a
    finding — boundaries.md § Always do #10 mandates the stamp.
    """
    findings: list[Finding] = []
    today = _dt.date.today()
    for spec in specs:
        if spec.path.parent.name != "active":
            continue
        m = _LAST_UPDATED_RE.search(spec.body)
        if not m:
            findings.append(
                Finding(
                    spec.path,
                    spec.front_matter_end_line or 1,
                    "freshness_missing_stamp",
                    "no `*Last updated: YYYY-MM-DD*` line found",
                )
            )
            continue
        try:
            stamp = _dt.date.fromisoformat(m.group(1))
        except ValueError:
            findings.append(
                Finding(
                    spec.path,
                    spec.front_matter_end_line or 1,
                    "freshness_bad_date",
                    f"unparseable Last updated date: {m.group(1)!r}",
                )
            )
            continue
        age = (today - stamp).days
        if age > _FRESHNESS_MAX_DAYS:
            findings.append(
                Finding(
                    spec.path,
                    spec.front_matter_end_line or 1,
                    "freshness_stale",
                    f"Last updated {stamp.isoformat()} is {age} days old "
                    f"(>{_FRESHNESS_MAX_DAYS} days)",
                )
            )
    return findings


# Inline markdown link: `[text](url)` — url captured. Reference-style
# links `[text][ref]` are not handled (none in current corpus).
_LINK_RE = re.compile(r"\[(?:[^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")

# Treat these schemes as external (not checked locally).
_EXTERNAL_PREFIXES = (
    "http://",
    "https://",
    "mailto:",
    "ftp://",
    "tel:",
)


def check_link_integrity(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #6 — every relative markdown link in a spec body resolves
    to a file at HEAD. External (http/https/mailto/etc.) and pure-anchor
    (`#section`) links are skipped. Fragments are stripped before
    existence check.
    """
    findings: list[Finding] = []
    for spec in specs:
        spec_dir = spec.path.parent
        body_start = spec.front_matter_end_line or 0
        for i, line in enumerate(spec.body.splitlines(), start=1):
            for m in _LINK_RE.finditer(line):
                url = m.group(1)
                if url.startswith("#"):
                    continue
                if any(url.startswith(p) for p in _EXTERNAL_PREFIXES):
                    continue
                # Strip fragment / query
                target = url.split("#", 1)[0].split("?", 1)[0]
                if not target:
                    continue
                resolved = (spec_dir / target).resolve()
                if not resolved.exists():
                    findings.append(
                        Finding(
                            spec.path,
                            body_start + i,
                            "link_broken",
                            f"link target does not exist: {url!r}",
                        )
                    )
    return findings


# Characters outside this set are flagged. The set covers:
#   * ASCII (0x00-0x7F)
#   * Latin-1 Supplement (0xA0-0xFF) — é, ñ, à, …
#   * Latin Extended-A (0x100-0x17F)
#   * Latin Extended-B (0x180-0x24F)
#   * Greek + Coptic (0x370-0x3FF) — math/science symbols: Δ π μ ε σ Ω …
#     Greek letters are universal in English math/engineering notation;
#     flagging them produces false positives with no real signal.
#   * General Punctuation (0x2000-0x206F) — em-dash, curly quotes, …
#   * Currency Symbols (0x20A0-0x20CF)
#   * Letterlike Symbols (0x2100-0x214F)
#   * Arrows (0x2190-0x21FF)
#   * Mathematical Operators (0x2200-0x22FF)
#   * Box drawing (0x2500-0x257F) — for ASCII-art diagrams
#   * Geometric Shapes (0x25A0-0x25FF) — checkboxes ☑ ☐
#   * Misc Symbols (0x2600-0x26FF) — ✅ ❌
#   * Dingbats (0x2700-0x27BF) — ✓ ✗
_NON_ENGLISH_RE = re.compile(
    r"[^\x00-\x7F"
    r" -ɏ"
    r"Ͱ-Ͽ"
    r" -⁯"
    r"₠-⃏"
    r"℀-⅏"
    r"←-⇿"
    r"∀-⋿"
    r"─-╿"
    r"■-◿"
    r"☀-⛿"
    r"✀-➿"
    r"]+"
)


def check_english_only(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #7 — boundaries.md § Always do #8: file output is English.

    Flags any run of characters outside the allowed Unicode ranges
    (ASCII, Latin supplements, common punctuation, math, arrows, box
    drawing, dingbats — see _NON_ENGLISH_RE). One finding per offending
    line, with the offending excerpt included for context.
    """
    findings: list[Finding] = []
    for spec in specs:
        body_start = spec.front_matter_end_line or 0
        for i, line in enumerate(spec.body.splitlines(), start=1):
            m = _NON_ENGLISH_RE.search(line)
            if not m:
                continue
            excerpt = m.group(0)
            if len(excerpt) > 40:
                excerpt = excerpt[:37] + "..."
            findings.append(
                Finding(
                    spec.path,
                    body_start + i,
                    "english_only",
                    f"non-English run at col {m.start() + 1}: {excerpt!r}",
                )
            )
    return findings


CHECK_REGISTRY: list[Callable[[Iterable[Spec]], list[Finding]]] = [
    check_front_matter_schema,
    check_filename_id_parity,
    check_naming_pattern,
    check_dependency_graph,
    check_freshness,
    check_link_integrity,
    check_english_only,
    check_status_invariants,
]


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main(argv: list[str]) -> int:
    here = Path(__file__).resolve().parent
    root = find_repo_root(here)
    specs, discovery_findings = discover_specs(root)

    findings: list[Finding] = list(discovery_findings)
    for check in CHECK_REGISTRY:
        findings.extend(check(specs))

    for f in findings:
        print(f.render(root))

    if findings:
        print(
            f"\nvalidate-specs: {len(findings)} finding(s) across {len(specs)} spec(s).",
            file=sys.stderr,
        )
        return 1
    print(
        f"validate-specs: OK ({len(specs)} spec(s); "
        f"{len(CHECK_REGISTRY)} check(s) registered).",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
