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
_RISK_ENUM = {"low", "medium", "high", "trivial"}
_SEVERITY_ENUM = {"low", "medium", "high", "critical", "trivial"}
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
    "domain-refs",
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


# Path substrings that disqualify a spec from the Trivial lane.
# Mirrors `spec-lifecycle.md § Trivial lane` rules #4 (schema), #6 (prompts),
# and #7 (boundaries). Substring match — catches both system-scope and
# project-scope variants (e.g. workspace `.github/copilot-instructions.md`
# AND `tobevisit-content/.github/copilot-instructions.md`).
_TRIVIAL_FORBIDDEN_PATH_MARKERS = (
    "framework/boundaries.md",                     # rule #7 — system boundaries
    ".github/copilot-instructions.md",             # rule #7 — project boundaries
    "framework/prompts/",                          # rule #6 — system AI prompts
    ".github/copilot/prompts/",                    # rule #6 — project AI prompts
    "framework/spec-workflows/spec-lifecycle.md",  # rule #4 — front-matter schema
    "docs/requirements/",                          # rule #4 — baselines
)


def check_trivial_lane_eligibility(specs: Iterable[Spec]) -> list[Finding]:
    """When `risk: trivial` (CR/IMP) or `severity: trivial` (BUG), enforce
    eligibility per `spec-lifecycle.md § Trivial lane` (added by
    IMP-20260514-trivial-lane Task T1).

    Mechanically enforced rules:
      * #1 affected-code + affected-docs total ≤ 2 files
      * #2 exactly one entry in affected-repos
      * #3 no depends-on:
      * #4/#6/#7 no path under affected-* touches a forbidden marker
        (boundaries / prompts / lifecycle schema / baselines)

    NOT mechanically enforced (human judgment at gate):
      * #5 "no new bounded context" — too context-dependent for static
        checking; surfaces at the combined gate via question-round Q1.

    Every finding ends with the same fix instruction: "Drop `trivial` and
    re-run Specify on the standard track." Authors get an unambiguous
    signal that there's no path forward except the standard track.
    """
    findings: list[Finding] = []
    for spec in specs:
        fm = spec.front_matter
        risk = fm.get("risk")
        severity = fm.get("severity")
        is_trivial = (risk == "trivial") or (severity == "trivial")
        if not is_trivial:
            continue
        line = spec.front_matter_end_line or 1
        fix_hint = "Drop `trivial` and re-run Specify on the standard track."

        # #1 — ≤2 affected files total
        ac = fm.get("affected-code") if isinstance(fm.get("affected-code"), list) else []
        ad = fm.get("affected-docs") if isinstance(fm.get("affected-docs"), list) else []
        total = len(ac) + len(ad)
        if total > 2:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "trivial_eligibility_files",
                    f"trivial spec touches {total} files "
                    f"({len(ac)} affected-code + {len(ad)} affected-docs); "
                    f"≤2 required. {fix_hint}",
                )
            )

        # #2 — single repo
        ar = fm.get("affected-repos")
        if isinstance(ar, list) and len(ar) > 1:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "trivial_eligibility_repos",
                    f"trivial spec lists {len(ar)} affected-repos; "
                    f"exactly 1 required. {fix_hint}",
                )
            )

        # #3 — no depends-on
        deps = fm.get("depends-on")
        if isinstance(deps, list) and deps:
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "trivial_eligibility_depends_on",
                    f"trivial spec has depends-on: {deps!r}; "
                    f"the lane requires autonomous specs. {fix_hint}",
                )
            )

        # #4/#6/#7 — forbidden-path markers
        for path in list(ac) + list(ad):
            if not isinstance(path, str):
                continue
            for marker in _TRIVIAL_FORBIDDEN_PATH_MARKERS:
                if marker in path:
                    findings.append(
                        Finding(
                            spec.path,
                            line,
                            "trivial_eligibility_forbidden_path",
                            f"trivial spec touches {path!r} which contains "
                            f"{marker!r} — boundaries / prompts / schema / "
                            f"baselines changes are excluded from the lane. "
                            f"{fix_hint}",
                        )
                    )
                    break  # one marker per path is enough

    return findings


# Per IMP-20260514-research-lane FR-7/8/9/10 — RES-only checks.
# Kill-criteria shape detectors: each regex matches one of the three
# canonical shapes. A valid kill-criteria string matches exactly one.
_RES_KILL_CRITERIA_SHAPES: dict[str, "re.Pattern[str]"] = {
    # Word-boundary at start, no boundary at end: matches plural and
    # base forms uniformly (`hours`, `hour`, `days`, `day`, etc.).
    "time-box": re.compile(
        r"\b(hour|hr|day|min|minute|week|by\s+\d{4}-\d{2}-\d{2})",
        re.IGNORECASE,
    ),
    "token-budget": re.compile(r"\btoken", re.IGNORECASE),
    "iteration-count": re.compile(
        r"\b(backflip|iteration|round|loop)",
        re.IGNORECASE,
    ),
}

# Valid RES outcomes at status=done. `promoted-to-<spec-id>` is matched
# separately and the referenced spec-id MUST resolve.
_RES_OUTCOME_TERMINAL = {"confirmed", "refuted", "inconclusive"}
_RES_PROMOTED_RE = re.compile(r"^promoted-to-(.+)$")


def check_res_eligibility(specs: Iterable[Spec]) -> list[Finding]:
    """RES-only validation per spec-lifecycle.md § RES exception:
      * `hypothesis:` non-empty
      * `kill-criteria:` matches exactly one shape (time-box, token-budget,
        iteration-count) — mixed shapes are unenforceable
      * `code-location:` is NOT inside `src/` of any repo
      * at `status: done`, `outcome:` is in {confirmed, refuted,
        inconclusive, promoted-to-<spec-id>} and any promotion target resolves
    """
    specs_list = list(specs)
    all_spec_ids = {
        spec.front_matter.get("id")
        for spec in specs_list
        if isinstance(spec.front_matter.get("id"), str)
    }

    findings: list[Finding] = []
    for spec in specs_list:
        fm = spec.front_matter
        if fm.get("type") != "RES":
            continue
        line = spec.front_matter_end_line or 1

        # 1. hypothesis non-empty
        hyp = fm.get("hypothesis")
        if not isinstance(hyp, str) or not hyp.strip():
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "res_hypothesis_empty",
                    "RES spec has empty or missing `hypothesis:` field",
                )
            )

        # 2. kill-criteria single shape
        kc = fm.get("kill-criteria")
        if not isinstance(kc, str) or not kc.strip():
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "res_kill_criteria_missing",
                    "RES spec missing `kill-criteria:` field",
                )
            )
        else:
            matched = [
                name
                for name, rx in _RES_KILL_CRITERIA_SHAPES.items()
                if rx.search(kc)
            ]
            if not matched:
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "res_kill_criteria_unknown_shape",
                        f"kill-criteria={kc!r} does not match any known shape "
                        f"(time-box, token-budget, iteration-count)",
                    )
                )
            elif len(matched) > 1:
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "res_kill_criteria_mixed_shape",
                        f"kill-criteria={kc!r} matches multiple shapes "
                        f"{matched}; pick one shape — mixed criteria are "
                        f"unenforceable",
                    )
                )

        # 3. code-location outside src/
        cl = fm.get("code-location")
        if not isinstance(cl, str) or not cl.strip():
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "res_code_location_missing",
                    "RES spec missing `code-location:` field",
                )
            )
        else:
            # Match `src/` or `src/...` as a path segment. Substring of `src`
            # alone (e.g. "research/srcfoo/") is not flagged — path-segment
            # boundary matters.
            parts = cl.strip("/").split("/")
            if "src" in parts:
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "res_code_location_in_src",
                        f"code-location={cl!r} contains a 'src/' path segment; "
                        f"RES sandboxes MUST live outside src/",
                    )
                )

        # 4. outcome at done
        if fm.get("status") == "done":
            outcome = fm.get("outcome")
            if not isinstance(outcome, str) or not outcome.strip():
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "res_outcome_missing_at_done",
                        "RES spec at status=done has empty or missing "
                        "`outcome:` field",
                    )
                )
            else:
                outcome_str = outcome.strip()
                if outcome_str in _RES_OUTCOME_TERMINAL:
                    pass  # valid terminal outcome
                else:
                    m = _RES_PROMOTED_RE.match(outcome_str)
                    if m:
                        referenced = m.group(1)
                        if referenced not in all_spec_ids:
                            findings.append(
                                Finding(
                                    spec.path,
                                    line,
                                    "res_outcome_dangling_promotion",
                                    f"outcome={outcome_str!r} references "
                                    f"unknown spec id: {referenced!r}",
                                )
                            )
                    else:
                        findings.append(
                            Finding(
                                spec.path,
                                line,
                                "res_outcome_invalid",
                                f"outcome={outcome_str!r} not in "
                                "{confirmed, refuted, inconclusive, "
                                "promoted-to-<spec-id>}",
                            )
                        )

    return findings


# FR-9 — inventory paths must be readable by spec-status-guard.sh, which
# resolves affected-code / affected-docs from the project root that owns
# docs/specs/active. A path written any other way (workspace-relative, say)
# matches nothing there, so it is a lease the guard cannot see.
_INVENTORY_FIELDS = ("affected-code", "affected-docs")


def _guard_normalize(entry: str) -> str:
    """Apply spec-status-guard.sh's own normalization to an inventory entry."""
    entry = entry.split(" (")[0]  # strip annotations: "src/foo (new)"
    if entry.endswith("/..."):  # strip ellipsis: "src/..."
        entry = entry[: -len("/...")]
    return entry.rstrip("/")


def _project_root(spec_path: Path) -> Path | None:
    for candidate in spec_path.parents:
        if (candidate / "docs" / "specs").is_dir():
            return candidate
    return None


def check_inventory_paths(specs: Iterable[Spec]) -> list[Finding]:
    """FR-9 — an inventory path that does not resolve from the project root."""
    findings: list[Finding] = []
    for spec in specs:
        # spec-status-guard.sh iterates docs/specs/active/*.md and nothing else,
        # so only an active spec's inventory is a lease at all. An archived
        # spec's paths are inert, and judging them would flag cross-repo entries
        # that have no project-root-relative form (see FR-9 in this spec).
        if spec.path.parent.name != "active":
            continue
        root = _project_root(spec.path)
        if root is None:
            continue
        line = spec.front_matter_end_line or 1
        for field in _INVENTORY_FIELDS:
            value = spec.front_matter.get(field)
            if not isinstance(value, list):
                continue
            for raw in value:
                if not isinstance(raw, str):
                    continue
                entry = _guard_normalize(raw.strip())
                # Unfilled template placeholders are a schema concern, not this one.
                if not entry or entry.startswith("<"):
                    continue
                # Judge the form, not the freshness: an archived spec may name a
                # file since deleted, but its first segment still has to be one
                # the guard would descend into from the project root.
                if (root / entry.split("/")[0]).exists():
                    continue
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "inventory_path_unresolvable",
                        f"{field} entry {raw!r} does not resolve from the project "
                        f"root {root.name!r}; spec-status-guard.sh matches paths "
                        f"in that form, so this leases nothing",
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
    check_trivial_lane_eligibility,
    check_res_eligibility,
    check_inventory_paths,
]


# ---------------------------------------------------------------------------
# Agent corpus (framework/agents/*.md) — discovery + schema check
# Added by IMP-20260514-framework-subagents Task S6 (FR-6).
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Agent:
    """A framework sub-agent definition. Lives under framework/agents/."""

    path: Path
    front_matter: dict[str, object]
    body: str
    front_matter_end_line: int


_AGENT_REQUIRED_FIELDS = ("name", "description", "model-suggestion", "tools-allowed")


def discover_agents(root: Path) -> tuple[list[Agent], list[Finding]]:
    """Load every *.md under framework/agents/, EXCEPT README.md.

    README.md is the contract document, not an agent definition. Its
    schema-example placeholder values (e.g. `name: <kebab-case-id>`) would
    otherwise fail the schema check.
    """
    agents: list[Agent] = []
    findings: list[Finding] = []
    d = root / "framework" / "agents"
    if not d.is_dir():
        return agents, findings
    for path in sorted(d.glob("*.md")):
        if path.name == "README.md":
            continue
        text = path.read_text(encoding="utf-8")
        fm, body, end_line, parse_findings = _parse_front_matter(text, path)
        findings.extend(parse_findings)
        agents.append(
            Agent(
                path=path,
                front_matter=fm,
                body=body,
                front_matter_end_line=end_line,
            )
        )
    return agents, findings


def check_agent_front_matter(agents: Iterable[Agent]) -> list[Finding]:
    """Enforce the agent contract per `framework/agents/README.md`:
      * All four required fields present (name, description,
        model-suggestion, tools-allowed).
      * `name` MUST equal the filename stem.
      * `model-suggestion` in {fast, default, deep}.
      * `tools-allowed` is a non-empty list.
    """
    findings: list[Finding] = []
    for agent in agents:
        fm = agent.front_matter
        line = agent.front_matter_end_line or 1

        for field in _AGENT_REQUIRED_FIELDS:
            if field not in fm:
                findings.append(
                    Finding(
                        agent.path,
                        line,
                        "agent_schema_missing_field",
                        f"required field '{field}' missing",
                    )
                )

        expected_name = agent.path.stem
        if "name" in fm and fm["name"] != expected_name:
            findings.append(
                Finding(
                    agent.path,
                    line,
                    "agent_filename_name_parity",
                    f"name={fm['name']!r} does not match filename stem {expected_name!r}",
                )
            )

        if "model-suggestion" in fm and fm["model-suggestion"] not in _MODEL_ENUM:
            findings.append(
                Finding(
                    agent.path,
                    line,
                    "agent_schema_enum",
                    f"model-suggestion={fm['model-suggestion']!r} "
                    f"not in {sorted(_MODEL_ENUM)}",
                )
            )

        if "tools-allowed" in fm:
            ta = fm["tools-allowed"]
            if not isinstance(ta, list):
                findings.append(
                    Finding(
                        agent.path,
                        line,
                        "agent_schema_type",
                        f"tools-allowed must be a list, got {type(ta).__name__}",
                    )
                )
            elif not ta:
                findings.append(
                    Finding(
                        agent.path,
                        line,
                        "agent_schema_empty",
                        "tools-allowed must be non-empty",
                    )
                )

    return findings


# ---------------------------------------------------------------------------
# Domain baselines (docs/domain/*.md) — REQ-ID uniqueness
# Added by IMP-20260826-spec-guard-and-validator-gaps (FR-8).
# ---------------------------------------------------------------------------

# A REQ-ID is *defined* by the trailing annotation on its requirement bullet —
# `*(REQ-PCE-001)*` or `*(REQ-PCE-001; amended by ...)*`. The same ID named
# anywhere else on the line is a citation, and an annotation that retires or
# supersedes the ID is history the lifecycle requires to stay in the file
# (docs/req-id-lifecycle.md § Deletion, § Supersession) — neither is a second
# claim on the number.
_REQ_DEF_RE = re.compile(r"\*\((REQ-[A-Z0-9]+(?:-[A-Z]+)*-\d+)([^)]*)\)")
_REQ_HISTORY_RE = re.compile(
    r"\b(retired|superseded|supersedes|deleted|tombstone)\b", re.IGNORECASE
)


def check_domain_req_ids(root: Path) -> list[Finding]:
    """FR-8 — one REQ-ID defined more than once inside a single baseline file."""
    findings: list[Finding] = []
    domain = root / "docs" / "domain"
    if not domain.is_dir():
        return findings
    for path in sorted(domain.glob("*.md")):
        if path.name == "README.md":
            continue
        seen: dict[str, int] = {}
        text = path.read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), 1):
            for m in _REQ_DEF_RE.finditer(line):
                req_id, annotation = m.group(1), m.group(2)
                if _REQ_HISTORY_RE.search(annotation) or _REQ_HISTORY_RE.search(
                    line[: m.start()]
                ):
                    continue
                if req_id in seen:
                    findings.append(
                        Finding(
                            path,
                            lineno,
                            "domain_req_id_duplicate",
                            f"REQ-ID {req_id} is defined again here; "
                            f"first definition at line {seen[req_id]}",
                        )
                    )
                else:
                    seen[req_id] = lineno
    return findings


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main(argv: list[str]) -> int:
    # An optional path argument lets a consuming project validate its own specs:
    # the walk-up starts there instead of at this file, which otherwise always
    # resolves to ai-dotfiles and silently reports on the wrong corpus.
    start = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parent
    root = find_repo_root(start)
    specs, discovery_findings = discover_specs(root)
    agents, agent_discovery_findings = discover_agents(root)

    findings: list[Finding] = list(discovery_findings)
    findings.extend(agent_discovery_findings)
    for check in CHECK_REGISTRY:
        findings.extend(check(specs))
    findings.extend(check_agent_front_matter(agents))
    findings.extend(check_domain_req_ids(root))

    for f in findings:
        print(f.render(root))

    total_checks = len(CHECK_REGISTRY) + 2  # + agent front-matter, + domain REQ-IDs
    if findings:
        print(
            f"\nvalidate-specs: {len(findings)} finding(s) across "
            f"{len(specs)} spec(s) + {len(agents)} agent(s).",
            file=sys.stderr,
        )
        return 1
    print(
        f"validate-specs: OK ({len(specs)} spec(s); {len(agents)} agent(s); "
        f"{total_checks} check(s) registered).",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
