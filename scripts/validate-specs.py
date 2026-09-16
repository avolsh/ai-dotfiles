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
  (`_parse_front_matter`, shared with `spec-status.py` from `speclib.py`). It handles only the subset present in the
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

import argparse
import datetime as _dt
import json
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable, NamedTuple

# The corpus reader lives beside this script; a direct run has no package to import it through.
# No bytecode cache either: these commands write nothing, not even `__pycache__/` beside them.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from speclib import (  # noqa: E402
    _LAST_UPDATED_RE,
    _TABLE_SEP_RE,
    Finding,
    Spec,
    _h2_section_lines,
    _parse_front_matter,
    _row_cells,
    discover_specs,
    _declared_relations,
    _spec_id,
    check_deltas,
    find_repo_root,
    index_baseline,
    parse_baseline_deltas,
)


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
# `closed:` is required at `done`, and a Direct-lane log entry needs its
# `Closed` line, from this date on (IMP-20260914-baseline-verification-freshness
# FR-1, FR-8). Pinned to that IMP's closure date; earlier records are history.
_CLOSURE_CUTOFF = _dt.date(2026, 9, 16)

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

        # `closed:` — well-formed wherever present; required at done from the cut-off.
        if "closed" in fm:
            c = fm["closed"]
            if not isinstance(c, str) or not _DATE_RE.match(c):
                findings.append(
                    Finding(
                        spec.path,
                        line,
                        "schema_date_format",
                        f"closed={c!r} does not match YYYY-MM-DD",
                    )
                )
        elif fm.get("status") == "done":
            dated = fm.get("date")
            if isinstance(dated, str) and _DATE_RE.match(dated):
                try:
                    judged = _dt.date.fromisoformat(dated) >= _CLOSURE_CUTOFF
                except ValueError:
                    judged = False  # an impossible calendar date; format passed
                if judged:
                    findings.append(
                        Finding(
                            spec.path,
                            line,
                            "schema_closed_missing",
                            f"status=done requires 'closed: YYYY-MM-DD' for specs "
                            f"dated on or after {_CLOSURE_CUTOFF.isoformat()}",
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


# IMP-20260829 — the rule is about *prose*, so the check has to know what a run
# of characters is before it judges it. Three things it is not:
#
#   * Quoted data. A spec describing a Ukrainian corpus must be able to write
#     `Берестейський` in backticks or drop a fixture into a fenced block; the
#     word is the subject, not a lapse. Front-matter values need no handling
#     here — `Spec.body` already excludes them.
#   * A glyph. ⏳ 📍 ⬜ ⤓ and emoji belong to no letter category. A symbol is
#     not a language, and neither is a superscript digit or a variation
#     selector.
#   * A letter this project writes English in. ASCII and the Latin supplements
#     obviously; Greek too, because Δ π μ σ Ω are universal in English
#     engineering notation; and the spacing modifiers, which carry
#     transliteration (Indoneziysʹkyy) rather than a second script.
#
# What is left — an unquoted run of letters from another script, in a sentence —
# is what the rule was written for, and is what AC-3 pins by counter-example.

_ALLOWED_LETTER_RANGES = (
    (0x0041, 0x005A),  # A-Z
    (0x0061, 0x007A),  # a-z
    (0x00C0, 0x024F),  # Latin-1 Supplement, Latin Extended-A and -B
    (0x02B0, 0x02FF),  # Spacing Modifier Letters — ʹ in transliteration
    (0x0370, 0x03FF),  # Greek and Coptic — math/science notation
    (0x1E00, 0x1EFF),  # Latin Extended Additional
)

# Characters that may sit inside one foreign-language excerpt without ending it,
# so the message quotes the phrase a reader can act on rather than its first
# word. A Latin letter is not among them: it closes the run, which is what keeps
# an English sentence from being reported as one long finding.
_RUN_JOINERS = " \t\u00a0-\u2010\u2011\u2013\u2014'\u2019\u02bc"

_INLINE_CODE_RE = re.compile(r"(`+)[^`]*?\1")
_FENCE_RE = re.compile(r"^\s{0,3}(?:`{3,}|~{3,})")


def _is_foreign_letter(ch: str) -> bool:
    """True for a letter from a script this project does not write English in."""
    if not unicodedata.category(ch).startswith("L"):
        return False
    cp = ord(ch)
    return not any(lo <= cp <= hi for lo, hi in _ALLOWED_LETTER_RANGES)


def _mask_inline_code(line: str) -> str:
    """Blank out inline-code spans, preserving length so columns stay true."""
    return _INLINE_CODE_RE.sub(lambda m: " " * len(m.group(0)), line)


def _first_foreign_run(line: str) -> tuple[int, str] | None:
    """First (column, excerpt) of foreign-script letters, or None.

    A run survives the joiners above, so a whole clause is quoted back; any
    other character — a Latin letter included — closes it.
    """
    start: int | None = None
    stop = 0
    for i, ch in enumerate(line):
        if _is_foreign_letter(ch):
            if start is None:
                start = i
            stop = i + 1
        elif start is not None and ch not in _RUN_JOINERS:
            return start, line[start:stop]
    if start is not None:
        return start, line[start:stop]
    return None


def check_english_only(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 #7 — boundaries.md § Always do #8: file output is English.

    Flags an unquoted run of letters from another script in a spec's prose.
    Inline code, fenced blocks and front-matter values are data the spec is
    reporting, and characters outside every letter category are not language;
    neither is reported. One finding per offending line, with the excerpt.
    """
    findings: list[Finding] = []
    for spec in specs:
        body_start = spec.front_matter_end_line or 0
        in_fence = False
        for i, line in enumerate(spec.body.splitlines(), start=1):
            if _FENCE_RE.match(line):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            hit = _first_foreign_run(_mask_inline_code(line))
            if hit is None:
                continue
            col, excerpt = hit
            if len(excerpt) > 40:
                excerpt = excerpt[:37] + "..."
            findings.append(
                Finding(
                    spec.path,
                    body_start + i,
                    "english_only",
                    f"non-English run at col {col + 1}: {excerpt!r}",
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


def _inventory(spec: Spec) -> set[str]:
    """The spec's declared inventory, normalized the way the guard reads it."""
    paths: set[str] = set()
    for field in _INVENTORY_FIELDS:
        value = spec.front_matter.get(field)
        if not isinstance(value, list):
            continue
        for raw in value:
            if not isinstance(raw, str):
                continue
            entry = _guard_normalize(raw.strip())
            # Unfilled template placeholders name no file, so they collide with
            # nothing — every spec born from the template carries the same ones.
            if entry and not entry.startswith("<"):
                paths.add(entry)
    return paths


def check_active_spec_overlap(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1..FR-3 — two active specs aimed at the same file, undeclared.

    Two specs written independently against one target is where `## Current
    State` rots fastest: the wider one closes, and the narrower goes on
    describing code that no longer exists. The Split check's own output is the
    discriminator — a pair that declares itself in `siblings:` or `depends-on:`
    has already been adjudicated, and the staleness rule keyed to `depends-on:`
    covers it from there.
    """
    findings: list[Finding] = []
    # Only an active spec's inventory is a lease at all (OS-4); an archived
    # spec's paths are inert, and that case is covered procedurally by the
    # second re-verification key in spec-lifecycle.md § Rules #10.
    active = sorted(
        (s for s in specs if s.path.parent.name == "active"), key=lambda s: s.path
    )
    for i, spec in enumerate(active):
        inventory = _inventory(spec)
        if not inventory:
            continue
        spec_id = _spec_id(spec)
        related = _declared_relations(spec)
        for other in active[i + 1 :]:
            other_id = _spec_id(other)
            if other_id in related or spec_id in _declared_relations(other):
                continue
            shared = sorted(inventory & _inventory(other))
            if not shared:
                continue
            findings.append(
                Finding(
                    spec.path,
                    spec.front_matter_end_line or 1,
                    "active_spec_overlap",
                    f"active spec {other_id!r} claims the same "
                    f"{'path' if len(shared) == 1 else 'paths'}: "
                    f"{', '.join(shared)}; name one spec in the other's "
                    f"siblings: or depends-on:, or merge them",
                )
            )
    return findings


# A markdown image whose alt may itself hold one level of `[...]` — which is
# exactly the shape of a frame name: `[W-11.03] Entity — View · state`. The
# closing `)` is deliberately left unconsumed so the wrapping link can be read.
_IMAGE_RE = re.compile(r"!\[((?:[^\[\]]|\[[^\[\]]*\])*)\]\(([^)\s]*)")
_ID_TAG_RE = re.compile(r"^\[([A-Za-z]+-[0-9][0-9.]*)\]")
_TWO_PART_ID_RE = re.compile(r"^\[[A-Z]+-\d{2}\.\d{2}\]")


def _design_section(body: str) -> tuple[str, int] | None:
    """The `## Design` section's text and the 1-indexed body line it starts on."""
    lines = body.splitlines()
    start: int | None = None
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if not stripped.startswith("## "):
            continue
        if start is not None:
            return "\n".join(lines[start:i]), start + 1
        if stripped[3:].strip().lower() == "design":
            start = i + 1
    if start is None:
        return None
    return "\n".join(lines[start:]), start + 1


def check_figma_frame_id(specs: Iterable[Spec]) -> list[Finding]:
    """FR-10 — a Figma frame reference under an *active* spec's `## Design`
    carries a two-part `<platform>-<screen>.<state>` ID.

    Figma is not in the repository and cannot be checked from it; the alt text
    is, and it is where a superseded one-part ID reaches the corpus. Archived
    specs are out of scope by construction — they resolve against a frozen file
    key, where the one-part name is still the frame's real name.
    """
    findings: list[Finding] = []
    for spec in specs:
        if spec.path.parent.name != "active":
            continue
        section = _design_section(spec.body)
        if section is None:
            continue
        text, first_line = section
        for match in _IMAGE_RE.finditer(text):
            alt, src = match.group(1), match.group(2)
            after = text[match.end() :]
            # Link-wrapped form: `[![alt](src)](href)`.
            href = after[3:].split(")")[0] if after.startswith(")](") else ""
            tag = _ID_TAG_RE.match(alt)
            is_frame = "figma.com" in src or "figma.com" in href or tag is not None
            if not is_frame or _TWO_PART_ID_RE.match(alt):
                continue
            carries = f"ID {tag.group(1)}" if tag else "no ID tag"
            line = (
                spec.front_matter_end_line
                + first_line
                + text[: match.start()].count("\n")
            )
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "figma_frame_id",
                    f"Figma frame alt text carries {carries}; a two-part "
                    f"<platform>-<screen>.<state> ID is required "
                    f"(e.g. [W-11.03]) — figma-file-organization.md § 4",
                )
            )
    return findings


# ---------------------------------------------------------------------------
# Traceability — FR → AC → Task (IMP-20260914-spec-traceability-checks)
# ---------------------------------------------------------------------------

# Specs dated before this are history and not judged (FR-5): the IMP's closure date.
_TRACEABILITY_CUTOFF = _dt.date(2026, 9, 15)
_TRACEABILITY_TYPES = {"CR", "IMP", "BUG"}  # RES has no FR/AC contract (FR-6)
# `FR-2`, or a range `FR-1 – FR-3` (en dash, em dash or hyphen).
_FR_CITATION_RE = re.compile(r"\bFR-(\d+)(?:\s*[–—-]\s*FR-(\d+))?\b")
# An FR is defined by a list item, heading or table cell that opens with its ID.
_FR_DEFINITION_RE = re.compile(r"^\s*(?:[-*]\s+|#{3,6}\s+|\|\s*)\**FR-(\d+)\b")


def _traceability_judged(spec: Spec) -> bool:
    if spec.front_matter.get("type") not in _TRACEABILITY_TYPES:
        return False
    try:
        dated = _dt.date.fromisoformat(str(spec.front_matter.get("date")))
    except ValueError:
        return False  # the schema check reports a malformed date
    return dated >= _TRACEABILITY_CUTOFF


def _citations(pattern: re.Pattern[str], text: str) -> set[int]:
    """ID numbers `pattern` cites in `text`, a range expanded to its members."""
    cited: set[int] = set()
    for match in pattern.finditer(text):
        first = int(match.group(1))
        last = int(match.group(2)) if match.group(2) else first
        cited.update(range(first, last + 1) if last >= first else (first, last))
    return cited


def _fr_definitions(spec: Spec) -> dict[int, int]:
    """FR number → line it is defined on, from `## Requirements`."""
    defined: dict[int, int] = {}
    for line_no, text in _h2_section_lines(spec, {"requirements"}):
        match = _FR_DEFINITION_RE.match(text)
        if match:
            defined.setdefault(int(match.group(1)), line_no)
    return defined


def check_fr_ac_coverage(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1 / FR-2 — every defined FR is cited under `## Acceptance Criteria`
    (BUG: `## Fix Criteria`), and every FR cited there is defined."""
    findings: list[Finding] = []
    for spec in specs:
        if not _traceability_judged(spec):
            continue
        defined = _fr_definitions(spec)
        if not defined:
            continue
        cited: set[int] = set()
        for line_no, text in _h2_section_lines(
            spec, {"acceptance criteria", "fix criteria"}
        ):
            on_line = _citations(_FR_CITATION_RE, text)
            cited |= on_line
            for fr in sorted(on_line - defined.keys()):
                findings.append(
                    Finding(
                        spec.path,
                        line_no,
                        "traceability_fr_dangling",
                        f"cites FR-{fr}, which `## Requirements` does not define",
                    )
                )
        for fr, line_no in sorted(defined.items()):
            if fr not in cited:
                findings.append(
                    Finding(
                        spec.path,
                        line_no,
                        "traceability_fr_uncited",
                        f"FR-{fr} is cited by no acceptance block "
                        "(`FR-n` or a `FR-a – FR-b` range)",
                    )
                )
    return findings


_TASKS_REQUIRED_STATUSES = {"plan", "in-progress", "done"}


def check_fr_task_coverage(specs: Iterable[Spec]) -> list[Finding]:
    """FR-3 — from `plan` on, every defined FR is cited directly by a
    `## Tasks` table row; a row citing only an AC that cites the FR does not
    count."""
    findings: list[Finding] = []
    for spec in specs:
        if spec.front_matter.get("status") not in _TASKS_REQUIRED_STATUSES:
            continue
        if not _traceability_judged(spec):
            continue
        defined = _fr_definitions(spec)
        cited: set[int] = set()
        for _, text in _h2_section_lines(spec, {"tasks"}):
            if text.lstrip().startswith("|") and not _TABLE_SEP_RE.match(text):
                cited |= _citations(_FR_CITATION_RE, text)
        for fr, line_no in sorted(defined.items()):
            if fr not in cited:
                findings.append(
                    Finding(
                        spec.path,
                        line_no,
                        "traceability_fr_no_task",
                        f"FR-{fr} is cited by no `## Tasks` row "
                        "(a direct `FR-n` citation is required)",
                    )
                )
    return findings


_AC_CITATION_RE = re.compile(r"\bAC-(\d+)(?:\s*[–—-]\s*AC-(\d+))?\b")
_AC_DEFINITION_RE = re.compile(r"^\s*#{3,6}\s+\**AC-(\d+)\b")


def _closure_evidence_rows(spec: Spec) -> list[tuple[int, str, str]]:
    """Table rows of the acceptance table under `## Closure Evidence`, as
    (line, first cell, whole row), header and separator rows excluded. A row's
    first cell is its label — an AC ID for acceptance evidence, or a named row.

    Reading stops at the first `###` sub-heading: `### Review` carries its own
    findings table (IMP-20260914-mandatory-review-for-high-risk), and its rows
    are not acceptance evidence.
    """
    rows: list[tuple[int, str, str]] = []
    in_body = False  # past a separator row, so rows are data, not a header
    for line_no, text in _h2_section_lines(spec, {"closure evidence"}):
        stripped = text.strip()
        if stripped.startswith("#"):
            break  # a sub-section begins; its tables are not acceptance rows
        if not stripped:
            in_body = False  # a table ends at a blank line
        elif _TABLE_SEP_RE.match(text):
            in_body = True
        elif stripped.startswith("|") and in_body:
            label = stripped.strip("|").split("|", 1)[0].strip()
            rows.append((line_no, label, stripped))
        # any other line continues a wrapped row
    return rows


def check_ac_closure_coverage(specs: Iterable[Spec]) -> list[Finding]:
    """FR-4 — at `done`, every AC defined under `## Acceptance Criteria`
    (BUG: `## Fix Criteria`) has a row in the Closure Evidence table."""
    findings: list[Finding] = []
    for spec in specs:
        if spec.front_matter.get("status") != "done":
            continue
        if not _traceability_judged(spec):
            continue
        defined: dict[int, int] = {}
        for line_no, text in _h2_section_lines(
            spec, {"acceptance criteria", "fix criteria"}
        ):
            match = _AC_DEFINITION_RE.match(text)
            if match:
                defined.setdefault(int(match.group(1)), line_no)
        evidenced: set[int] = set()
        for _, label, _ in _closure_evidence_rows(spec):
            evidenced |= _citations(_AC_CITATION_RE, label)
        for ac, line_no in sorted(defined.items()):
            if ac not in evidenced:
                findings.append(
                    Finding(
                        spec.path,
                        line_no,
                        "traceability_ac_no_evidence",
                        f"AC-{ac} has no row in the `## Closure Evidence` table",
                    )
                )
    return findings


# IMP-20260914-mandatory-review-for-high-risk — the cold review is a closure
# precondition for the high tier, and its outcome is recorded where the gate
# and this validator can both read it.
_REVIEW_CUTOFF = _dt.date(2026, 9, 16)  # pinned to this IMP's closure date
_HIGH_SEVERITIES = {"high", "critical"}

# The sub-section's first non-blank line: `RESULT: <result> — <tail>`.
_REVIEW_RESULT_RE = re.compile(r"^RESULT:\s*(\S.*?)\s*$")
# `PASS — run 2026-09-16 against `a^..b`, sub-agent.`
_REVIEW_PASS_RE = re.compile(r"^PASS\s+[–—-]\s+(?P<tail>\S.*)$")
# `3 findings / 2 applied / 1 rejected — run …`
_REVIEW_FINDINGS_RE = re.compile(
    r"^(?P<n>\d+)\s+findings?\s*/\s*\d+\s+applied\s*/\s*\d+\s+rejected"
    r"\s+[–—-]\s+(?P<tail>\S.*)$"
)
# `WAIVED — by alexvolsh 2026-09-16: shipping ahead of the freeze. …`
_REVIEW_WAIVED_RE = re.compile(
    r"^WAIVED\s+[–—-]\s+by\s+(?P<who>\S+)\s+(?P<date>\d{4}-\d{2}-\d{2})"
    r"\s*:\s*(?P<reason>\S.*)$"
)
# The run header shared by PASS and findings results (FR-2's four fields).
_REVIEW_HEADER_RE = re.compile(
    r"^run\s+(?P<date>\d{4}-\d{2}-\d{2})\s+against\s+(?P<range>.+?),"
    r"\s*(?P<harness>\S.*?)\.\s*$"
)
_DISPOSITION_RE = re.compile(r"^(applied|rejected)\b")


def _high_tier(spec: Spec) -> bool:
    """FR-1 — `risk: high`, or `severity: high | critical` at any risk."""
    front = spec.front_matter
    if str(front.get("risk", "")).strip().lower() == "high":
        return True
    return str(front.get("severity", "")).strip().lower() in _HIGH_SEVERITIES


def _review_judged(spec: Spec) -> bool:
    try:
        dated = _dt.date.fromisoformat(str(spec.front_matter.get("date")))
    except ValueError:
        return False  # the schema check reports a malformed date
    return dated >= _REVIEW_CUTOFF


class ReviewSection(NamedTuple):
    heading_line: int
    result_line: int | None
    result: str | None
    rows: list[tuple[int, str, str]]  # (line, `#` cell, `Disposition` cell)


def _review_section(spec: Spec) -> ReviewSection | None:
    """The `### Review` sub-section of `## Closure Evidence`, or None.

    Rows are the findings table's, as (line, number cell, disposition cell).
    """
    lines = _h2_section_lines(spec, {"closure evidence"})
    start: int | None = None
    for i, (_, text) in enumerate(lines):
        if text.lstrip().lower().startswith("### review"):
            start = i
            break
    if start is None:
        return None
    result_line: int | None = None
    result: str | None = None
    rows: list[tuple[int, str, str]] = []
    in_body = False
    for line_no, text in lines[start + 1 :]:
        stripped = text.strip()
        if stripped.startswith("#"):
            break  # the next sub-section
        if not stripped:
            in_body = False
            continue
        if result is None:
            # FR-2: the first non-blank line is `RESULT:`. Prose before it
            # means the sub-section records no result at all.
            match = _REVIEW_RESULT_RE.match(stripped)
            if not match:
                break
            result_line, result = line_no, match.group(1)
            continue
        if _TABLE_SEP_RE.match(text):
            in_body = True
        elif stripped.startswith("|") and in_body:
            cells = _row_cells(stripped)
            number = cells[0] if cells else ""
            disposition = cells[2] if len(cells) > 2 else ""
            rows.append((line_no, number, disposition))
    return ReviewSection(lines[start][0], result_line, result, rows)


def check_review_disposition(specs: Iterable[Spec]) -> list[Finding]:
    """FR-1, FR-2, FR-3, FR-6, FR-10 — a high-tier spec at `done` records a
    `### Review` whose result is `PASS`, a finding count with every finding
    dispositioned, or a waiver naming a human and a reason."""
    findings: list[Finding] = []
    for spec in specs:
        if spec.front_matter.get("status") != "done":
            continue
        if not _high_tier(spec) or not _review_judged(spec):
            continue
        section = _review_section(spec)
        if section is None:
            findings.append(
                Finding(
                    spec.path,
                    spec.front_matter_end_line or 1,
                    "review_missing",
                    "high tier at `done` with no `### Review` sub-section "
                    "under `## Closure Evidence` (a waiver is recorded there "
                    "too, never left out)",
                )
            )
            continue
        if section.result is None:
            findings.append(
                Finding(
                    spec.path,
                    section.heading_line,
                    "review_no_result",
                    "`### Review` has no `RESULT:` line",
                )
            )
            continue
        anchor = section.result_line or section.heading_line
        waived = _REVIEW_WAIVED_RE.match(section.result)
        if section.result.startswith("WAIVED"):
            if not waived:
                findings.append(
                    Finding(
                        spec.path,
                        anchor,
                        "review_waiver_incomplete",
                        "a waived review must read `WAIVED — by <who> <date>: "
                        "<reason>` — the human and the reason are the record",
                    )
                )
            continue
        passed = _REVIEW_PASS_RE.match(section.result)
        counted = _REVIEW_FINDINGS_RE.match(section.result)
        if not passed and not counted:
            findings.append(
                Finding(
                    spec.path,
                    anchor,
                    "review_bad_result",
                    "`RESULT:` must read `PASS`, `<N> findings / <M> applied "
                    "/ <K> rejected`, or `WAIVED`",
                )
            )
            continue
        tail = (passed or counted).group("tail")
        if not _REVIEW_HEADER_RE.match(tail):
            findings.append(
                Finding(
                    spec.path,
                    anchor,
                    "review_header_incomplete",
                    "`RESULT:` must end `— run <date> against <range>, "
                    "<harness>.` (FR-2's four fields)",
                )
            )
        if passed:
            continue
        declared = int(counted.group("n"))
        if declared != len(section.rows):
            findings.append(
                Finding(
                    spec.path,
                    anchor,
                    "review_count_mismatch",
                    f"`RESULT:` declares {declared} finding(s) but the table "
                    f"has {len(section.rows)} row(s) — a truncated reply is "
                    "re-run, not patched by hand",
                )
            )
        for line_no, number, disposition in section.rows:
            if not _DISPOSITION_RE.match(disposition):
                findings.append(
                    Finding(
                        spec.path,
                        line_no,
                        "review_no_disposition",
                        f"finding {number or '?'} has no disposition — the "
                        "cell must open with `applied` or `rejected`",
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
    check_active_spec_overlap,
    check_figma_frame_id,
    check_fr_ac_coverage,
    check_fr_task_coverage,
    check_ac_closure_coverage,
    check_review_disposition,
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

# The REQ grammar — what defines an ID, what is a citation or history — lives in
# speclib.index_baseline, shared with baseline-merge.py.


def check_domain_req_ids(root: Path) -> list[Finding]:
    """FR-8 — one REQ-ID defined more than once inside a single baseline file."""
    findings: list[Finding] = []
    domain = root / "docs" / "domain"
    if not domain.is_dir():
        return findings
    for path in sorted(domain.glob("*.md")):
        if path.name == "README.md":
            continue
        index = index_baseline(path.read_text(encoding="utf-8"))
        for req_id, lineno, first in index.duplicates:
            findings.append(
                Finding(
                    path,
                    lineno,
                    "domain_req_id_duplicate",
                    f"REQ-ID {req_id} is defined again here; "
                    f"first definition at line {first}",
                )
            )
    return findings


# ---------------------------------------------------------------------------
# Domain baselines — `Last src verified` freshness
# Added by IMP-20260914-baseline-verification-freshness (FR-2 – FR-6).
# ---------------------------------------------------------------------------

_CLOSED_LINE_RE = re.compile(r"^[*_]Closed\s+(\d{4}-\d{2}-\d{2})\b", re.MULTILINE)
# Both italic forms: the corpus writes `*Last updated: …*` and `_Last updated: …_`.
_LAST_UPDATED_ANY_RE = re.compile(r"[*_]Last updated:\s*(\d{4}-\d{2}-\d{2})[*_]")
# Only the row's leading date is data; the parenthetical after it is prose.
_VERIFIED_ROW_RE = re.compile(
    r"^\|\s*Last src verified\s*\|\s*(\d{4}-\d{2}-\d{2})?", re.MULTILINE
)


def _iso_date(raw: object) -> _dt.date | None:
    try:
        return _dt.date.fromisoformat(str(raw))
    except ValueError:
        return None


def _closure_date(spec: Spec) -> tuple[_dt.date, str] | None:
    """FR-3 — the date a spec closed and where it was read, in declared order."""
    closed = _iso_date(spec.front_matter.get("closed"))
    if closed:
        return closed, "closed:"
    for pattern, source in (
        (_CLOSED_LINE_RE, "Closed line"),
        (_LAST_UPDATED_ANY_RE, "Last updated stamp"),
    ):
        m = pattern.search(spec.body)
        if m and _iso_date(m.group(1)):
            return _dt.date.fromisoformat(m.group(1)), source
    dated = _iso_date(spec.front_matter.get("date"))
    return (dated, "date:") if dated else None


def check_baseline_freshness(root: Path, specs: Iterable[Spec]) -> list[Finding]:
    """FR-2 / FR-5 — a baseline verified before the newest archived spec that
    changed it closed, or carrying no `Last src verified` row at all."""
    findings: list[Finding] = []
    domain = root / "docs" / "domain"
    if not domain.is_dir():
        return findings

    newest: dict[str, tuple[_dt.date, str, str]] = {}
    for spec in specs:
        if spec.path.parent.name != "archived":
            continue
        docs = spec.front_matter.get("affected-docs")
        if not isinstance(docs, list):
            continue
        closure = _closure_date(spec)
        if closure is None:
            continue
        for doc in docs:
            if not isinstance(doc, str) or not doc.startswith("docs/domain/"):
                continue
            candidate = (closure[0], _spec_id(spec), closure[1])
            if doc not in newest or candidate[0] > newest[doc][0]:
                newest[doc] = candidate

    for path in sorted(domain.glob("*.md")):
        if path.name == "README.md":
            continue
        text = path.read_text(encoding="utf-8")
        rel = f"docs/domain/{path.name}"
        m = _VERIFIED_ROW_RE.search(text)
        row_date = _iso_date(m.group(1)) if m and m.group(1) else None
        if row_date is None:
            findings.append(
                Finding(
                    path,
                    1,
                    "baseline_verified_missing",
                    f"{rel} has no `Last src verified` row with a leading YYYY-MM-DD "
                    f"(Rule 13)",
                )
            )
            continue
        closing = newest.get(rel)
        if closing and row_date < closing[0]:
            closed_on, spec_id, source = closing
            findings.append(
                Finding(
                    path,
                    text.count("\n", 0, m.start()) + 1,
                    "baseline_stale",
                    f"{rel} Last src verified {row_date.isoformat()} is older than "
                    f"{spec_id} closed {closed_on.isoformat()} (source: {source}); "
                    f"bump the row to the closure date (Rule 13)",
                )
            )
    return findings


# ---------------------------------------------------------------------------
# Improvements log — Direct-lane entries carry `Closed`
# Added by IMP-20260914-baseline-verification-freshness (FR-8, FR-9).
# ---------------------------------------------------------------------------

_LOG_ENTRY_RE = re.compile(r"^###\s+(\d{4}-\d{2}-\d{2})\b")
_LOG_SPEC_TASK_RE = re.compile(r"^\s*-\s*\*\*Spec / task:\*\*")
_LOG_CLOSED_RE = re.compile(r"^\s*-\s*\*\*Closed:\*\*\s*\d{4}-\d{2}-\d{2}\b")


def check_log_closed(root: Path) -> list[Finding]:
    """FR-9 — a Direct-lane entry dated on or after the cut-off with no
    `- **Closed:** YYYY-MM-DD` line."""
    path = root / "docs" / "improvements-log.md"
    if not path.is_file():
        return []

    # (heading line number, heading text, entry date, is Direct lane, has Closed)
    entries: list[list] = []
    fence: str | None = None
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.lstrip()
        if fence is not None:
            if stripped.startswith(fence):
                fence = None
            continue
        if stripped.startswith("```") or stripped.startswith("~~~"):
            fence = stripped[:3]
            continue
        if line.startswith("#"):
            m = _LOG_ENTRY_RE.match(line)
            if m:
                entries.append([lineno, line[4:].strip(), _iso_date(m.group(1)), False, False])
            elif line.startswith("## ") or line.startswith("# "):
                entries.append([lineno, "", None, False, False])  # closes the entry
            continue
        if not entries:
            continue
        if _LOG_SPEC_TASK_RE.match(line) and "Direct lane" in line:
            entries[-1][3] = True
        elif _LOG_CLOSED_RE.match(line):
            entries[-1][4] = True

    return [
        Finding(
            path,
            lineno,
            "log_closed_missing",
            f"Direct-lane entry '{heading}' needs a `- **Closed:** YYYY-MM-DD` line "
            f"(required from {_CLOSURE_CUTOFF.isoformat()}; improvements-log-format.md)",
        )
        for lineno, heading, dated, direct, closed in entries
        if dated and dated >= _CLOSURE_CUTOFF and direct and not closed
    ]


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Baseline deltas — every judged spec states its baseline impact
# Added by IMP-20260914-baseline-deltas-and-merge (FR-3, FR-4, FR-6, FR-10).
# ---------------------------------------------------------------------------

# Only specs dated *after* this are judged (FR-3, FR-10): pinned to the date the checks
# landed, so a spec written that day under the old Rule 13 stays history.
_DELTA_CUTOFF = _dt.date(2026, 9, 16)
# Baseline impact is known once requirements are approved, not while they are drafted.
_DELTA_JUDGED_STATUSES = {"plan", "in-progress", "done"}
_IMPACT_NONE_RE = re.compile(r"^none\s+(?:—|--)\s+\S")
_SCENARIO_RE = re.compile(r"\bScenario:|\bVerified by:|\bGiven\b.*\bWhen\b.*\bThen\b")


def check_baseline_deltas(root: Path, specs: Iterable[Spec]) -> list[Finding]:
    """FR-6 — active specs' deltas preflighted at every status; FR-3 / FR-4 —
    a judged spec carries deltas or the `baseline-impact: none` marker, and
    every new or modified REQ carries a scenario."""
    specs = list(specs)
    findings: list[Finding] = []
    for spec in specs:
        if spec.path.parent.name == "active":
            findings.extend(check_deltas(root, spec, specs))

        fm = spec.front_matter
        dated = _iso_date(fm.get("date"))
        if (
            dated is None
            or dated <= _DELTA_CUTOFF
            or fm.get("status") not in _DELTA_JUDGED_STATUSES
            or fm.get("type") == "RES"
        ):
            continue
        line = spec.front_matter_end_line or 1
        deltas = parse_baseline_deltas(spec)
        impact = fm.get("baseline-impact")
        if impact is not None and not (
            isinstance(impact, str) and _IMPACT_NONE_RE.match(impact)
        ):
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "baseline_impact_malformed",
                    f"baseline-impact={impact!r} must read `none — <reason>`",
                )
            )
        if impact is None and (deltas is None or not deltas.baselines):
            findings.append(
                Finding(
                    spec.path,
                    line,
                    "baseline_impact_missing",
                    "no `## Baseline Deltas` and no `baseline-impact: none — <reason>` "
                    "(spec-lifecycle.md Rule 13)",
                )
            )
        if deltas is None:
            continue
        for delta in deltas.baselines:
            changed = [(a.line, a.req_id, a.lines) for a in delta.added]
            changed += [(m.line, m.req_id, m.lines) for m in delta.modified]
            for req_line, req_id, lines in changed:
                if not any(_SCENARIO_RE.search(text) for text in lines):
                    findings.append(
                        Finding(
                            spec.path,
                            req_line,
                            "baseline_delta_scenario_missing",
                            f"{req_id} in {delta.path} carries no `Scenario:` "
                            f"(Given / When / Then) or `Verified by:` pointer",
                        )
                    )
    return findings


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="validate-specs",
        description="Validate a project's spec corpus under docs/specs/.",
    )
    # An optional path lets a consuming project validate its own specs: the walk-up
    # starts there instead of at this file, which otherwise always resolves to
    # ai-dotfiles and silently reports on the wrong corpus.
    parser.add_argument("path", nargs="?", help="project path (default: this repository)")
    output = parser.add_mutually_exclusive_group()
    output.add_argument(
        "--json", action="store_true", help="print one JSON report to stdout, nothing to stderr"
    )
    output.add_argument(
        "--report",
        choices=["findings"],
        help="findings: finding lines plus one per-check summary line, all on stdout",
    )
    return parser.parse_args(argv[1:])


def main(argv: list[str]) -> int:
    args = _parse_args(argv)
    start = Path(args.path).resolve() if args.path else Path(__file__).resolve().parent
    root = find_repo_root(start)
    specs, discovery_findings = discover_specs(root)
    agents, agent_discovery_findings = discover_agents(root)

    findings: list[Finding] = list(discovery_findings)
    findings.extend(agent_discovery_findings)
    for check in CHECK_REGISTRY:
        findings.extend(check(specs))
    findings.extend(check_agent_front_matter(agents))
    findings.extend(check_domain_req_ids(root))
    findings.extend(check_baseline_freshness(root, specs))
    findings.extend(check_log_closed(root))
    findings.extend(check_baseline_deltas(root, specs))

    by_check: dict[str, int] = {}
    for f in findings:
        by_check[f.check] = by_check.get(f.check, 0) + 1
    rc = 1 if findings else 0

    if args.json:
        report = {
            "schemaVersion": 1,
            "root": str(root),
            "findings": [
                {
                    "path": str(f.path.relative_to(root)),
                    "line": f.line,
                    "check": f.check,
                    "message": f.message,
                }
                for f in findings
            ],
            "summary": {
                "total": len(findings),
                "specs": len(specs),
                "agents": len(agents),
                "byCheck": by_check,
            },
        }
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return rc

    for f in findings:
        print(f.render(root))

    if args.report == "findings":
        counts = ", ".join(f"{check}={n}" for check, n in sorted(by_check.items()))
        print(
            f"validate-specs: {len(findings)} finding(s) across {len(specs)} spec(s) "
            f"+ {len(agents)} agent(s)" + (f"; {counts}" if counts else ".")
        )
        return rc

    # + agent front-matter, + domain REQ-IDs, + baseline freshness, + log Closed, + baseline deltas
    total_checks = len(CHECK_REGISTRY) + 5
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
