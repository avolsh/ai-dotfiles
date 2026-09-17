#!/usr/bin/env python3
"""speclib.py — the spec-corpus reader shared by the spec tools.

`validate-specs.py` judges the corpus and `spec-status.py` reports on it; both
read it through this module so there is one front-matter parser, one section
reader and one set of stamp/table patterns (IMP-20260914-machine-readable-spec-reports).
Stdlib only, and read-only: nothing here writes a file.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


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


def find_repo_root(start: Path, tool: str = "validate-specs") -> Path:
    """Walk up from `start` until a `docs/specs` directory is found."""
    cur = start.resolve()
    for candidate in [cur, *cur.parents]:
        if (candidate / "docs" / "specs").is_dir():
            return candidate
    raise SystemExit(
        f"{tool}: no docs/specs/ ancestor found starting at {start}"
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


# Match a markdown table separator row: `|---|---|...` with optional
# colons (alignment) and whitespace. Two-or-more pipe-segments suffice.
_TABLE_SEP_RE = re.compile(r"^\s*\|(?:\s*:?-+:?\s*\|)+\s*$")


# Pattern: `*Last updated: YYYY-MM-DD*` (or the `_…_` italic) anywhere in the body — the one stamp
# grammar; lifecycle.yaml `last_updated_re` states the same pattern for the declarative rules.
_LAST_UPDATED_RE = re.compile(r"[*_]Last updated:\s*(\d{4}-\d{2}-\d{2})[*_]")


def _h2_section_lines(spec: Spec, titles: set[str]) -> list[tuple[int, str]]:
    """Lines of the first `## <title>` section matching `titles`, paired with
    their 1-indexed line number in the file.

    Headings inside a fenced block are text, not structure: a spec that shows
    the shape of a section in `## Design` — `## Closure Evidence` with a
    `### Review` under it, say — would otherwise have its worked example read
    as the section itself, and the real one never reached.
    """
    lines: list[tuple[int, str]] = []
    inside = False
    fence: str | None = None
    for i, line in enumerate(spec.body.splitlines()):
        stripped = line.lstrip()
        if fence is not None:
            if stripped.startswith(fence):
                fence = None
            if inside:
                lines.append((spec.front_matter_end_line + i + 1, line))
            continue
        if stripped.startswith("```") or stripped.startswith("~~~"):
            fence = stripped[:3]
            if inside:
                lines.append((spec.front_matter_end_line + i + 1, line))
            continue
        if stripped.startswith("## "):
            if inside:
                break
            inside = stripped[3:].strip().lower() in titles
            continue
        if inside:
            lines.append((spec.front_matter_end_line + i + 1, line))
    return lines


# Splits a table row on real column separators only. The corpus writes
# `severity: high \| critical` inside cells; splitting on that escaped pipe
# would shift every later column and mis-read the one it lands on.
_UNESCAPED_PIPE_RE = re.compile(r"(?<!\\)\|")


def _row_cells(stripped: str) -> list[str]:
    """Cells of a markdown table row, split on unescaped pipes only."""
    return [c.strip() for c in _UNESCAPED_PIPE_RE.split(stripped.strip("|"))]


# A Status cell opens with an optional glyph (`☑`, `✅`, `☐`, `⊘`, …) before its word.
_STATUS_WORD_RE = re.compile(r"[A-Za-z][A-Za-z-]*")
_EXCLUDED_WORDS = {"descoped", "cancelled", "canceled"}


def task_counts(spec: Spec) -> dict[str, int] | None:
    """Done / total / excluded rows of the `## Tasks` table, or None without one.

    The Status column is found by its header, so a table with extra or reordered
    columns still reads right. Descoped and cancelled rows leave the total.
    """
    status_col: int | None = None
    counts = {"done": 0, "total": 0, "excluded": 0}
    for _, line in _h2_section_lines(spec, {"tasks"}):
        stripped = line.strip()
        if not stripped.startswith("|") or _TABLE_SEP_RE.match(stripped):
            continue
        cells = _row_cells(stripped)
        if status_col is None:
            headers = [c.lower() for c in cells]
            if "status" in headers:
                status_col = headers.index("status")
            continue
        if len(cells) <= status_col:
            continue
        m = _STATUS_WORD_RE.search(cells[status_col])
        word = m.group(0).lower() if m else ""
        if word in _EXCLUDED_WORDS:
            counts["excluded"] += 1
            continue
        counts["total"] += 1
        if word == "done":
            counts["done"] += 1
    return counts if status_col is not None else None


_RELATION_FIELDS = ("siblings", "depends-on")


def _spec_id(spec: Spec) -> str:
    value = spec.front_matter.get("id")
    return value if isinstance(value, str) else spec.path.stem


def _declared_relations(spec: Spec) -> set[str]:
    """Every spec id this spec names in `siblings:` or `depends-on:`."""
    named: set[str] = set()
    for field in _RELATION_FIELDS:
        value = spec.front_matter.get(field)
        if isinstance(value, list):
            named.update(item.strip() for item in value if isinstance(item, str))
    return named


# ---------------------------------------------------------------------------
# Domain baselines (docs/domain/*.md) — the REQ grammar
# Moved here from validate-specs.py by IMP-20260914-baseline-deltas-and-merge,
# so the validator and baseline-merge read requirements the same way.
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
# Any mention — definition, citation or tombstone — counts toward numbering:
# req-id-lifecycle.md § Numbering forbids reusing a retired number.
_REQ_ID_RE = re.compile(r"\b(REQ-[A-Z0-9]+(?:-[A-Z]+)*)-(\d+)\b")
_HEADING_RE = re.compile(r"^#{1,6}\s")
_BULLET_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s")


def req_definitions(line: str) -> list[str]:
    """REQ-IDs this line defines, excluding history annotations."""
    defined: list[str] = []
    for m in _REQ_DEF_RE.finditer(line):
        if _REQ_HISTORY_RE.search(m.group(2)) or _REQ_HISTORY_RE.search(
            line[: m.start()]
        ):
            continue
        defined.append(m.group(1))
    return defined


@dataclass(frozen=True)
class ReqEntry:
    """One requirement in a baseline: its lines and where it sits."""

    req_id: str
    start: int  # 0-indexed first line (the bullet)
    end: int  # 0-indexed, exclusive — includes nested lines after the annotation
    line: int  # 1-indexed line carrying the defining annotation
    heading: str | None  # nearest heading above, as written


@dataclass(frozen=True)
class BaselineIndex:
    entries: dict[str, ReqEntry]
    duplicates: list[tuple[str, int, int]]  # (REQ-ID, line, first definition line)
    series_max: dict[str, tuple[int, int]]  # series -> (highest number, digit width)
    headings: tuple[tuple[int, str], ...]  # (0-indexed line, heading as written), fences skipped

    def next_id(self, series: str) -> str:
        """`max(existing) + 1` in the series' padding; `001` for a new series."""
        number, width = self.series_max.get(series, (0, 3))
        return f"{series}-{number + 1:0{width}d}"


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip())


def _req_span(lines: list[str], i: int) -> tuple[int, int]:
    """Bullet line through the last line nested deeper than it."""
    start = i
    while not _BULLET_RE.match(lines[start]) and start > 0:
        above = lines[start - 1]
        if not above.strip() or _HEADING_RE.match(above):
            break
        start -= 1
    end = i + 1
    while (
        end < len(lines)
        and lines[end].strip()
        and not _HEADING_RE.match(lines[end])
        and _indent(lines[end]) > _indent(lines[start])
    ):
        end += 1
    return start, end


def index_baseline(text: str) -> BaselineIndex:
    """Every REQ defined in a baseline, with its span, heading and numbering."""
    lines = text.splitlines()
    entries: dict[str, ReqEntry] = {}
    duplicates: list[tuple[str, int, int]] = []
    series_max: dict[str, tuple[int, int]] = {}
    headings: list[tuple[int, str]] = []
    heading: str | None = None
    fence: str | None = None
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if fence is not None:
            if stripped.startswith(fence):
                fence = None
            continue
        if stripped.startswith(("```", "~~~")):
            fence = stripped[:3]
            continue
        if _HEADING_RE.match(line):
            heading = line.strip()
            headings.append((i, heading))
            continue
        for m in _REQ_ID_RE.finditer(line):
            number, width = int(m.group(2)), len(m.group(2))
            best = series_max.get(m.group(1), (0, 0))
            series_max[m.group(1)] = (max(best[0], number), max(best[1], width))
        for req_id in req_definitions(line):
            if req_id in entries:
                duplicates.append((req_id, i + 1, entries[req_id].line))
                continue
            start, end = _req_span(lines, i)
            entries[req_id] = ReqEntry(req_id, start, end, i + 1, heading)
    return BaselineIndex(entries, duplicates, series_max, tuple(headings))


# ---------------------------------------------------------------------------
# Spec `## Baseline Deltas` — the change a spec makes to its baselines
# Added by IMP-20260914-baseline-deltas-and-merge (FR-1, FR-2).
# ---------------------------------------------------------------------------

_REQ = r"REQ-[A-Z0-9]+(?:-[A-Z]+)*-\d+"
_DASH = r"\s+(?:—|--)\s+"
_ADDED_HEAD_RE = re.compile(r"^- Under `(#{1,6} [^`]+)`:?\s*$")
_MODIFIED_HEAD_RE = re.compile(rf"^- ({_REQ})(?:{_DASH}Why:\s*(.+?))?\s*$")
_REMOVED_HEAD_RE = re.compile(rf"^- ({_REQ}){_DASH}Reason:\s*(.+?){_DASH}Migration:\s*(.+?)\s*$")
_RENAMED_HEAD_RE = re.compile(rf"^- FROM ({_REQ}) TO ({_REQ})(?:{_DASH}Why:\s*(.+?))?\s*$")
_DELTA_KINDS = ("ADDED", "MODIFIED", "REMOVED", "RENAMED")


@dataclass(frozen=True)
class AddedReq:
    line: int  # 1-indexed line of the requirement's bullet in the spec
    heading: str  # baseline heading it lands under, as written there
    req_id: str
    lines: tuple[str, ...]  # the requirement as it will read in the baseline


@dataclass(frozen=True)
class ModifiedReq:
    line: int
    req_id: str
    why: str | None
    lines: tuple[str, ...]  # full replacement


@dataclass(frozen=True)
class RemovedReq:
    line: int
    req_id: str
    reason: str
    migration: str


@dataclass(frozen=True)
class RenamedReq:
    line: int
    from_id: str
    to_id: str
    why: str | None


@dataclass(frozen=True)
class BaselineDelta:
    path: str  # project-relative, e.g. docs/domain/geo-canonicalization.md
    line: int
    added: tuple[AddedReq, ...]
    modified: tuple[ModifiedReq, ...]
    removed: tuple[RemovedReq, ...]
    renamed: tuple[RenamedReq, ...]


@dataclass(frozen=True)
class SpecDeltas:
    baselines: tuple[BaselineDelta, ...]
    findings: tuple[Finding, ...]


def _requirements(
    children: list[tuple[int, str]],
) -> list[tuple[int, tuple[str, ...]]]:
    """Nested requirement bullets of one delta item, dedented to baseline level."""
    body = [(n, t) for n, t in children if t.strip()]
    if not body:
        return []
    base = min(_indent(t) for _, t in body)
    reqs: list[tuple[int, list[str]]] = []
    for n, t in body:
        if _indent(t) == base and _BULLET_RE.match(t):
            reqs.append((n, []))
        if reqs:
            reqs[-1][1].append(t[base:])
    return [(n, tuple(lines)) for n, lines in reqs]


def _defined_id(lines: tuple[str, ...]) -> list[str]:
    return sorted({req_id for line in lines for req_id in req_definitions(line)})


def _has_h2(spec: Spec, title: str) -> bool:
    """Whether `## <title>` is a real heading — one inside a fence is text."""
    fence: str | None = None
    for line in spec.body.splitlines():
        stripped = line.lstrip()
        if fence is not None:
            if stripped.startswith(fence):
                fence = None
            continue
        if stripped.startswith(("```", "~~~")):
            fence = stripped[:3]
        elif stripped.startswith("## ") and stripped[3:].strip().lower() == title:
            return True
    return False


def parse_baseline_deltas(spec: Spec) -> SpecDeltas | None:
    """The spec's `## Baseline Deltas`, or None when it has no such section."""
    if not _has_h2(spec, "baseline deltas"):
        return None
    section = _h2_section_lines(spec, {"baseline deltas"})

    findings: list[Finding] = []
    baselines: list[BaselineDelta] = []
    blocks: dict[str, list] | None = None  # current baseline's blocks; None = none open
    path_line: tuple[str, int] | None = None
    kind: str | None = None  # current block; "" = unknown block, skipped
    item: tuple[int, str, list[tuple[int, str]]] | None = None

    def bad(line: int, message: str) -> None:
        findings.append(Finding(spec.path, line, "baseline_delta_malformed", message))

    def flush_item() -> None:
        nonlocal item
        if item is None or blocks is None or not kind:
            item = None
            return
        n, head, children = item
        item = None
        reqs = _requirements(children)
        if kind == "ADDED":
            m = _ADDED_HEAD_RE.match(head)
            if not m:
                bad(n, "ADDED item must open with Under `<baseline heading>`:")
                return
            if not reqs:
                bad(n, "ADDED item names no requirement")
            for req_line, lines in reqs:
                ids = _defined_id(lines)
                if len(ids) != 1:
                    bad(req_line, "requirement carries no single defining `*(REQ-…)*` annotation")
                    continue
                blocks["added"].append(AddedReq(req_line, m.group(1), ids[0], lines))
        elif kind == "MODIFIED":
            m = _MODIFIED_HEAD_RE.match(head)
            if not m:
                bad(n, "MODIFIED item must open with `<REQ-ID>` (optionally `— Why: …`)")
                return
            if len(reqs) != 1:
                bad(n, f"MODIFIED {m.group(1)} needs one full replacement requirement")
                return
            ids = _defined_id(reqs[0][1])
            if ids != [m.group(1)]:
                bad(n, f"MODIFIED {m.group(1)} replacement defines {', '.join(ids) or 'no ID'}")
                return
            blocks["modified"].append(ModifiedReq(n, m.group(1), m.group(2), reqs[0][1]))
        elif kind == "REMOVED":
            m = _REMOVED_HEAD_RE.match(head)
            if not m:
                bad(n, "REMOVED item needs `<REQ-ID> — Reason: … — Migration: …`")
                return
            blocks["removed"].append(RemovedReq(n, m.group(1), m.group(2), m.group(3)))
        elif kind == "RENAMED":
            m = _RENAMED_HEAD_RE.match(head)
            if not m:
                bad(n, "RENAMED item needs `FROM <REQ-ID> TO <REQ-ID>`")
                return
            blocks["renamed"].append(RenamedReq(n, m.group(1), m.group(2), m.group(3)))

    def flush_baseline() -> None:
        nonlocal blocks, path_line
        flush_item()
        if blocks is not None and path_line is not None:
            baselines.append(
                BaselineDelta(
                    path_line[0],
                    path_line[1],
                    *(tuple(blocks[k]) for k in ("added", "modified", "removed", "renamed")),
                )
            )
        blocks, path_line = None, None

    skipping = False  # inside an invalid baseline sub-heading
    fence: str | None = None
    comment = False  # inside `<!-- … -->` — template guidance, not content
    for n, line in section:
        stripped = line.lstrip()
        if comment or stripped.startswith("<!--"):
            comment = "-->" not in stripped
            continue
        if fence is not None:
            if stripped.startswith(fence):
                fence = None
            continue
        if stripped.startswith(("```", "~~~")):
            fence = stripped[:3]
            continue
        if line.startswith("### "):
            flush_baseline()
            kind = None
            path = line[4:].strip().strip("`")
            if path.startswith("docs/domain/") and path.endswith(".md"):
                blocks = {"added": [], "modified": [], "removed": [], "renamed": []}
                path_line, skipping = (path, n), False
            else:
                bad(n, f"sub-heading `{path}` must name a baseline file under docs/domain/")
                skipping = True
            continue
        if line.startswith("#### "):
            flush_item()
            if blocks is None:
                if not skipping:
                    bad(n, "block outside a baseline sub-heading")
                kind = ""
                continue
            name = line[5:].strip()
            if name in _DELTA_KINDS:
                kind = name
            else:
                bad(n, f"unknown block `#### {name}`; use ADDED, MODIFIED, REMOVED or RENAMED")
                kind = ""
            continue
        if not line.strip() or skipping:
            continue
        if blocks is None:
            bad(n, "text outside a baseline sub-heading")
            continue
        if kind is None:
            bad(n, "text outside an ADDED / MODIFIED / REMOVED / RENAMED block")
            continue
        if _indent(line) == 0:
            flush_item()
            if kind and _BULLET_RE.match(line):
                item = (n, line.rstrip(), [])
            elif kind:
                bad(n, "block content must be `- ` items")
        elif item is not None:
            item[2].append((n, line))
    flush_baseline()
    return SpecDeltas(tuple(baselines), tuple(findings))


# ---------------------------------------------------------------------------
# Delta preflight — what `baseline-merge --check` and the validator report
# Added by IMP-20260914-baseline-deltas-and-merge (FR-2, FR-6).
# ---------------------------------------------------------------------------


def _series(req_id: str) -> tuple[str, int]:
    series, _, number = req_id.rpartition("-")
    return series, int(number)


def _touched(delta: BaselineDelta) -> list[tuple[int, str]]:
    """Every REQ-ID a baseline delta names, with the spec line naming it."""
    named = [(a.line, a.req_id) for a in delta.added]
    named += [(m.line, m.req_id) for m in delta.modified]
    named += [(r.line, r.req_id) for r in delta.removed]
    for r in delta.renamed:
        named += [(r.line, r.from_id), (r.line, r.to_id)]
    return named


def check_deltas(root: Path, spec: Spec, specs: Iterable[Spec]) -> list[Finding]:
    """FR-6 — a spec's deltas judged against its baselines and the other active specs."""
    deltas = parse_baseline_deltas(spec)
    if deltas is None:
        return []
    findings = list(deltas.findings)

    def report(line: int, check: str, message: str) -> None:
        findings.append(Finding(spec.path, line, f"baseline_delta_{check}", message))

    for delta in deltas.baselines:
        seen: dict[str, int] = {}
        for line, req_id in _touched(delta):
            if req_id in seen and seen[req_id] != line:
                report(
                    line,
                    "conflict",
                    f"{req_id} in {delta.path} is already changed at line {seen[req_id]} of this spec",
                )
            seen.setdefault(req_id, line)

        file = root / delta.path
        if not file.is_file():
            report(delta.line, "file_missing", f"{delta.path} does not exist in this project")
            continue
        index = index_baseline(file.read_text(encoding="utf-8"))
        duplicated = {req_id for req_id, _, _ in index.duplicates}
        no_ids = not index.entries

        targets = [(m.line, m.req_id, "MODIFIED") for m in delta.modified]
        targets += [(r.line, r.req_id, "REMOVED") for r in delta.removed]
        targets += [(r.line, r.from_id, "RENAMED") for r in delta.renamed]
        for line, req_id, kind in targets:
            if req_id in duplicated:
                report(
                    line,
                    "target_ambiguous",
                    f"{kind} {req_id} is defined more than once in {delta.path}",
                )
            elif req_id not in index.entries:
                hint = (
                    f"; {delta.path} has no REQ-IDs — edit it by hand at this spec's closure"
                    if no_ids
                    else ""
                )
                report(
                    line, "target_missing", f"{kind} {req_id} is not defined in {delta.path}{hint}"
                )

        for a in delta.added:
            if a.heading not in {text for _, text in index.headings}:
                report(
                    a.line,
                    "heading_missing",
                    f"ADDED {a.req_id} lands under `{a.heading}`, which {delta.path} does not have",
                )

        new_ids = [(a.line, a.req_id) for a in delta.added]
        new_ids += [(r.line, r.to_id) for r in delta.renamed]
        by_series: dict[str, list[tuple[int, int, str]]] = {}
        for line, req_id in new_ids:
            if req_id in index.entries:
                report(line, "id_taken", f"{req_id} is already defined in {delta.path}")
                continue
            series, number = _series(req_id)
            by_series.setdefault(series, []).append((number, line, req_id))
        for series, numbered in by_series.items():
            expected = index.next_id(series)
            for number, line, req_id in sorted(numbered):
                if req_id != expected:
                    report(
                        line,
                        "numbering",
                        f"{req_id} must be {expected} (req-id-lifecycle.md § Numbering)",
                    )
                    break
                expected = f"{series}-{number + 1:0{len(expected) - len(series) - 1}d}"

    mine: dict[tuple[str, str], int] = {}
    for d in deltas.baselines:
        for line, req_id in _touched(d):
            mine.setdefault((d.path, req_id), line)
    my_id, my_relations = _spec_id(spec), _declared_relations(spec)
    for other in specs:
        if other.path == spec.path or other.path.parent.name != "active":
            continue
        other_id = _spec_id(other)
        if other_id in my_relations or my_id in _declared_relations(other):
            continue
        theirs = parse_baseline_deltas(other)
        if theirs is None:
            continue
        shared = {(d.path, req_id) for d in theirs.baselines for _, req_id in _touched(d)}
        for path, req_id in sorted(shared & mine.keys()):
            report(
                mine[(path, req_id)],
                "collision",
                f"{req_id} in {path} is also changed by {other_id}; "
                "declare `siblings:` or `depends-on:` between them",
            )
    return findings
