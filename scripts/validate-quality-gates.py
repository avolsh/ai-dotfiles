#!/usr/bin/env python3
"""validate-quality-gates.py — checks a project's Build and Run gate table.

Implements IMP-20260916-quality-gates-check. Reads `<project-root>/_canonical.md`,
finds the first table under `## Build and Run`, and enforces the `Kind` / `Mode`
contract the project template seeds (IMP-20260914-quality-gates-contract):

- the section, the table and its `Kind` / `Mode` columns exist (FR-1);
- `format`, `lint`, `duplication` and `security` each have a decided row —
  a step, or `n/a — <reason>` with any reason but `to be decided` (FR-2);
- `Kind` and `Mode` come from their vocabularies, `gate` rows are numbered,
  `report` rows are not, and `n/a` rows carry `—` in both `#` and `Mode` (FR-3);
- a `duplication` step names the report file it writes (FR-4).

Findings print as `path:line:check:message`, as `validate-specs.py` does, and
the exit status is non-zero when any is emitted. Standard library only (FR-5).
It never runs the declared commands (OS-1).

Usage: validate-quality-gates.py [project-root]   (default: current directory)
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

KINDS = ("format", "lint", "typecheck", "test", "duplication", "security", "docs", "build", "other")
REQUIRED_KINDS = ("format", "lint", "duplication", "security")
MODES = ("gate", "report")
UNNUMBERED = ("—", "-", "–")
SEED_REASON = "to be decided"

SECTION_RE = re.compile(r"^##\s+Build and Run\s*$")
NA_RE = re.compile(r"^n/a\s*[—–-]\s*(.*)$", re.IGNORECASE)
# A report path: a token with a directory separator, or a name with a file extension.
PATH_RE = re.compile(r"[\w.\-]*/[\w.\-/]*\w|[\w\-]+\.[A-Za-z][A-Za-z0-9]{1,4}\b")


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    check: str
    message: str

    def render(self) -> str:
        return f"{self.path}:{self.line}:{self.check}:{self.message}"


def split_row(line: str) -> list[str]:
    """Split a Markdown table row on `|`, ignoring pipes escaped or inside backticks."""
    cells, buf, in_code, prev = [], [], False, ""
    for ch in line.strip():
        if ch == "`":
            in_code = not in_code
        if ch == "|" and not in_code and prev != "\\":
            cells.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
        prev = ch
    cells.append("".join(buf).strip())
    # A row written `| a | b |` yields empty edge cells.
    if cells and cells[0] == "":
        cells = cells[1:]
    if cells and cells[-1] == "":
        cells = cells[:-1]
    return cells


def plain(cell: str) -> str:
    return cell.replace("`", "").strip()


def validate(root: Path) -> list[Finding]:
    canonical = root / "_canonical.md"
    shown = str(canonical)
    try:
        lines = canonical.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        return [Finding(shown, 1, "file_missing", f"cannot read _canonical.md: {exc.strerror}")]

    start = next((i for i, l in enumerate(lines) if SECTION_RE.match(l)), None)
    if start is None:
        return [Finding(shown, 1, "section_missing", "no '## Build and Run' section")]
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))

    header_idx = next((i for i in range(start + 1, end) if lines[i].lstrip().startswith("|")), None)
    if header_idx is None:
        return [Finding(shown, start + 1, "table_missing", "'## Build and Run' has no gate table")]

    header = [plain(c).lower() for c in split_row(lines[header_idx])]
    missing = [name for name in ("#", "step", "kind", "mode", "what fails it") if name not in header]
    if missing:
        cols = ", ".join(f"'{m}'" for m in missing)
        return [Finding(shown, header_idx + 1, "column_missing", f"gate table has no {cols} column")]
    col = {name: header.index(name) for name in ("#", "step", "kind", "mode", "what fails it")}

    findings: list[Finding] = []
    decided: dict[str, bool] = {}
    seed_line: dict[str, int] = {}
    i = header_idx + 1
    if i < end and re.match(r"^\s*\|[\s:|-]+\|?\s*$", lines[i]):
        i += 1  # delimiter row
    while i < end and lines[i].lstrip().startswith("|"):
        lineno = i + 1
        cells = split_row(lines[i])
        i += 1
        if len(cells) < len(header):
            findings.append(Finding(shown, lineno, "row_malformed",
                                    f"row has {len(cells)} cells, header has {len(header)}"))
            continue
        number, step = plain(cells[col["#"]]), plain(cells[col["step"]])
        kind, mode = plain(cells[col["kind"]]), plain(cells[col["mode"]])
        fails_it = cells[col["what fails it"]]

        if kind not in KINDS:
            findings.append(Finding(shown, lineno, "kind_unknown",
                                    f"Kind '{kind}' is not one of {' | '.join(KINDS)}"))
            continue

        na = NA_RE.match(step)
        if na:
            is_seed = na.group(1).strip().lower() == SEED_REASON
            decided[kind] = decided.get(kind, False) or not is_seed
            if is_seed:
                seed_line.setdefault(kind, lineno)
            if number not in UNNUMBERED or mode not in UNNUMBERED:
                findings.append(Finding(shown, lineno, "na_shape",
                                        f"n/a row for '{kind}' must carry '—' in # and Mode"))
            continue

        decided[kind] = True
        if mode not in MODES:
            findings.append(Finding(shown, lineno, "mode_unknown",
                                    f"Mode '{mode}' is not one of {' | '.join(MODES)}"))
            continue
        if mode == "gate" and number in UNNUMBERED:
            findings.append(Finding(shown, lineno, "gate_unnumbered",
                                    f"gate step '{step}' must carry a step number"))
        if mode == "report" and number not in UNNUMBERED:
            findings.append(Finding(shown, lineno, "report_numbered",
                                    f"report step '{step}' is numbered '{number}'; report steps are numbered '—'"))
        if kind == "duplication" and not PATH_RE.search(fails_it):
            findings.append(Finding(shown, lineno, "duplication_no_report",
                                    f"duplication step '{step}' names no report file path in 'What fails it'"))

    for kind in REQUIRED_KINDS:
        if kind not in decided:
            findings.append(Finding(shown, header_idx + 1, "kind_missing",
                                    f"required Kind '{kind}' has no row (add a step or 'n/a — <reason>')"))
        elif not decided[kind]:
            findings.append(Finding(shown, seed_line[kind], "kind_undecided",
                                    f"required Kind '{kind}' still reads 'n/a — {SEED_REASON}'"))
    return findings


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path(".")
    findings = validate(root)
    for f in sorted(findings, key=lambda f: f.line):
        print(f.render())
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
