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


# Pattern: `*Last updated: YYYY-MM-DD*` anywhere in the body.
_LAST_UPDATED_RE = re.compile(r"\*Last updated:\s*(\d{4}-\d{2}-\d{2})\*")


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
