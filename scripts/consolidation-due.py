#!/usr/bin/env python3
"""consolidation-due.py — which bounded contexts are due a refactor-only IMP.

Implements IMP-20260914-consolidation-checkpoint. Maps each closed spec to bounded
contexts by its `affected-code` paths through `docs/architecture/module-map.md`
(FR-1), counts closures per context since that context's last entry in
`docs/consolidation-log.md` — or the log's `since:` — and marks a context due at
`threshold:` closures (default 5) or on one large closure (FR-2, FR-9). A spec
named as an accepted IMP in the log never counts (FR-10). Paths no context owns
count under `unknown` (OS-3).

`--recommend <context>` gathers what a consolidation IMP's `## Current State` cites
(FR-3, FR-7): accepted-duplication bullets and rejected reviewer findings from the
context's counted closures, improvements-log entries naming it since the cut-off,
and its figures from the report the project's `duplication` row names — or one
line saying why there are none (FR-8).

Read-only: it never writes a file — log entries are appended by the agent after
the human answers (OS-2) — and it always exits 0.

Usage:
    consolidation-due.py [path] [--json] [--closed SPEC-ID | --recommend CONTEXT]
    make consolidation-due [PROJECT=path] [CLOSED=SPEC-ID | CONTEXT=name]
"""

from __future__ import annotations

import argparse
import datetime as _dt
import importlib.util
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# The corpus reader lives beside this script; a direct run has no package to import it through.
# No bytecode cache either: this command writes nothing, not even `__pycache__/` beside it.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from speclib import (  # noqa: E402
    _TABLE_SEP_RE,
    Spec,
    _h2_section_lines,
    _parse_front_matter,
    _row_cells,
    discover_specs,
    find_repo_root,
    task_counts,
)


def _load_quality_gates():
    """The Build and Run table reader `validate-quality-gates.py` owns — one parser for the `duplication` row."""
    path = Path(__file__).resolve().parent / "validate-quality-gates.py"
    spec = importlib.util.spec_from_file_location("validate_quality_gates", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # its dataclasses resolve their module through sys.modules
    spec.loader.exec_module(module)
    return module


quality_gates = _load_quality_gates()

SCHEMA_VERSION = 1
DEFAULT_THRESHOLD = 5
# Where counting starts in a project whose log declares no `since:` — this IMP's closure.
DEFAULT_SINCE = _dt.date(2026, 9, 16)
UNKNOWN = "unknown"
LOG_PATH = Path("docs/consolidation-log.md")
IMPROVEMENTS_LOG_PATH = Path("docs/improvements-log.md")
MODULE_MAP_PATH = Path("docs/architecture/module-map.md")

# FR-2: what makes one closure large enough to trigger on its own.
LARGE_TASKS = 8
LARGE_AFFECTED_CODE = 15

# Both logs head an entry `### YYYY-MM-DD — <title>`; in the consolidation log the title is the context.
_ENTRY_RE = re.compile(r"^###\s+(\d{4}-\d{2}-\d{2})\s+[—–-]\s+(.+?)\s*$")
_FIELD_RE = re.compile(r"^-\s+\*\*(\w[\w ]*):\*\*\s*(.*)$")
_OUTCOME_RE = re.compile(r"^(accepted|declined)\s*(?:[—–-]\s*(.*))?$", re.IGNORECASE)
_ACCEPTED_DUP_RE = re.compile(r"^\s*-\s+\*\*Accepted duplication:\*\*\s*(.+?)\s*$", re.IGNORECASE)
_FINDING_PATH_RE = re.compile(r"^`?([^\s`:]+?)(?::\d+)?`?\s*→")
_SPEC_ID_RE = re.compile(r"\b(?:CR|BUG|IMP|RES)-\d{8}-[a-z0-9-]+\b")


@dataclass(frozen=True)
class Context:
    name: str
    directory: str  # project-root-relative, trailing slash; "" for unknown


@dataclass(frozen=True)
class Outcome:
    date: _dt.date
    context: str
    outcome: str  # accepted | declined
    imp: str | None
    reason: str | None
    line: int

    def as_json(self) -> dict[str, object]:
        return {"date": self.date.isoformat(), "outcome": self.outcome, "imp": self.imp, "reason": self.reason}


@dataclass(frozen=True)
class Log:
    path: Path | None
    threshold: int
    since: _dt.date
    entries: list[Outcome]


def _plain(cell: str) -> str:
    return cell.replace("`", "").replace("*", "").strip()


def read_contexts(root: Path) -> list[Context]:
    """Contexts from the first module-map table carrying `Context` and `Directory` columns."""
    path = root / MODULE_MAP_PATH
    if not path.is_file():
        return []
    contexts: list[Context] = []
    cols: tuple[int, int] | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            if contexts:
                break
            cols = None
            continue
        if _TABLE_SEP_RE.match(stripped):
            continue
        cells = [_plain(c) for c in _row_cells(stripped)]
        if cols is None:
            headers = [c.lower() for c in cells]
            if "context" in headers and "directory" in headers:
                cols = (headers.index("context"), headers.index("directory"))
            continue
        if len(cells) <= max(cols):
            continue
        name, directory = cells[cols[0]], cells[cols[1]]
        if name and directory:
            contexts.append(Context(name, directory.rstrip("/") + "/"))
    return contexts


def read_log(root: Path) -> Log:
    path = root / LOG_PATH
    if not path.is_file():
        return Log(None, DEFAULT_THRESHOLD, DEFAULT_SINCE, [])
    fm, body, end_line, _ = _parse_front_matter(path.read_text(encoding="utf-8"), path)
    threshold = fm.get("threshold")
    since = fm.get("since")
    entries: list[Outcome] = []
    heading: tuple[_dt.date, str, int] | None = None
    fields: dict[str, str] = {}

    def flush() -> None:
        if heading is None:
            return
        m = _OUTCOME_RE.match(fields.get("outcome", ""))
        if not m:
            return
        outcome, detail = m.group(1).lower(), (m.group(2) or "").strip()
        imp = None
        if outcome == "accepted":
            found = _SPEC_ID_RE.search(detail)
            imp = found.group(0) if found else None
        entries.append(
            Outcome(heading[0], heading[1], outcome, imp, None if outcome == "accepted" else detail or None, heading[2])
        )

    for i, line in enumerate(body.splitlines(), start=end_line + 1):
        m = _ENTRY_RE.match(line.strip())
        if m:
            flush()
            try:
                heading = (_dt.date.fromisoformat(m.group(1)), m.group(2), i)
            except ValueError:
                heading = None
            fields = {}
            continue
        f = _FIELD_RE.match(line.strip())
        if f and heading is not None:
            fields[f.group(1).lower()] = f.group(2).strip()
    flush()
    try:
        since_date = _dt.date.fromisoformat(str(since)) if since else DEFAULT_SINCE
    except ValueError:
        since_date = DEFAULT_SINCE
    return Log(
        path,
        threshold if isinstance(threshold, int) and threshold > 0 else DEFAULT_THRESHOLD,
        since_date,
        entries,
    )


def _code_path(entry: str) -> str:
    """`affected-code` entry → bare path: backticks, `(new)` markers and notes dropped."""
    token = entry.strip().split()[0] if entry.strip() else ""
    return token.strip("`").removeprefix("./")


def contexts_of(paths: list[str], contexts: list[Context]) -> list[str]:
    """Context names a spec's paths fall under, by longest directory prefix; `unknown` for the rest."""
    names: list[str] = []
    for raw in paths:
        path = _code_path(raw)
        if not path:
            continue
        owner = max(
            (c for c in contexts if path == c.directory.rstrip("/") or path.startswith(c.directory)),
            key=lambda c: len(c.directory),
            default=None,
        )
        name = owner.name if owner else UNKNOWN
        if name not in names:
            names.append(name)
    return names


def _closed(spec: Spec) -> _dt.date | None:
    if spec.front_matter.get("status") != "done":
        return None
    try:
        return _dt.date.fromisoformat(str(spec.front_matter.get("closed")))
    except ValueError:
        return None


def _as_list(value: object) -> list[str]:
    if isinstance(value, list):
        return [str(v) for v in value]
    return [str(value)] if value not in (None, "") else []


def large_reason(spec: Spec) -> str | None:
    """FR-2: why this closure triggers on its own, or None."""
    if spec.front_matter.get("risk") == "high":
        return "risk: high"
    counts = task_counts(spec)
    tasks = counts["total"] + counts["excluded"] if counts else 0
    if tasks > LARGE_TASKS:
        return f"{tasks} tasks"
    code = len(_as_list(spec.front_matter.get("affected-code")))
    if code > LARGE_AFFECTED_CODE:
        return f"{code} affected-code entries"
    return None


def build_report(root: Path, closed_filter: str | None = None) -> dict[str, object]:
    return _count(root, closed_filter)[0]


def _count(root: Path, closed_filter: str | None = None) -> tuple[dict[str, object], dict[str, Spec], dict[str, _dt.date]]:
    """The report, the specs by ID, and each context's cut-off date."""
    contexts = read_contexts(root)
    log = read_log(root)
    specs, _ = discover_specs(root)
    by_id = {str(s.front_matter.get("id") or s.path.stem): s for s in specs}
    accepted_imps = {e.imp for e in log.entries if e.imp}

    last: dict[str, Outcome] = {}
    for entry in log.entries:
        if entry.context not in last or entry.date >= last[entry.context].date:
            last[entry.context] = entry

    records: dict[str, dict[str, object]] = {
        name: {"context": name, "directory": directory, "closures": [], "triggers": []}
        for name, directory in [(c.name, c.directory) for c in contexts] + [(UNKNOWN, "")]
    }
    spec_contexts: dict[str, list[str]] = {}

    for spec in sorted(specs, key=lambda s: (str(s.front_matter.get("closed")), s.path.name)):
        spec_id = str(spec.front_matter.get("id") or spec.path.stem)
        names = contexts_of(_as_list(spec.front_matter.get("affected-code")), contexts)
        spec_contexts[spec_id] = names
        closed = _closed(spec)
        if closed is None or spec_id in accepted_imps:
            continue
        reason = large_reason(spec)
        for name in names:
            cut = last[name].date if name in last else log.since
            if closed <= cut:
                continue
            record = records[name]
            record["closures"].append(spec_id)
            if reason:
                record["triggers"].append(f"large {spec_id} ({reason})")

    cutoffs = {name: (last[name].date if name in last else log.since) for name in records}
    out = []
    for name, record in records.items():
        count = len(record["closures"])
        triggers = list(record["triggers"])
        if count >= log.threshold:
            triggers.insert(0, f"count {count}/{log.threshold}")
        if name == UNKNOWN and count == 0:
            continue
        if closed_filter is not None and name not in spec_contexts.get(closed_filter, []):
            continue
        out.append(
            {
                **record,
                "count": count,
                "threshold": log.threshold,
                "due": bool(triggers),
                "triggers": triggers,
                "lastOutcome": last[name].as_json() if name in last else None,
            }
        )
    report = {
        "schemaVersion": SCHEMA_VERSION,
        "root": str(root),
        "log": str(LOG_PATH) if log.path else None,
        "threshold": log.threshold,
        "since": log.since.isoformat(),
        "defaultSince": DEFAULT_SINCE.isoformat(),
        "contexts": out,
    }
    return report, by_id, cutoffs


def _rel(root: Path, path: Path) -> str:
    return str(path.relative_to(root))


def _in_directory(path: str, directory: str) -> bool:
    return bool(directory) and (path == directory.rstrip("/") or path.startswith(directory))


def gather_spec_inputs(root: Path, specs: list[Spec], context: Context, contexts: list[Context]) -> dict[str, list]:
    """Accepted-duplication bullets and rejected Review rows from the context's counted closures."""
    duplication: list[dict[str, str]] = []
    rejected: list[dict[str, str]] = []
    for spec in specs:
        for line_no, line in _h2_section_lines(spec, {"closure evidence"}):
            source = f"{_rel(root, spec.path)}:{line_no}"
            m = _ACCEPTED_DUP_RE.match(line)
            if m:
                duplication.append({"source": source, "text": m.group(1)})
                continue
            stripped = line.strip()
            if not stripped.startswith("|") or _TABLE_SEP_RE.match(stripped):
                continue
            cells = _row_cells(stripped)
            if len(cells) < 3 or not cells[-1].lower().startswith("rejected"):
                continue
            found = _FINDING_PATH_RE.match(cells[1])
            if not found or contexts_of([found.group(1)], contexts) != [context.name]:
                continue
            rejected.append({"source": source, "text": f"{cells[1]} — {cells[-1]}"})
    return {"acceptedDuplication": duplication, "rejectedFindings": rejected}


def gather_improvements_log(root: Path, context: Context, cutoff: _dt.date) -> list[dict[str, str]]:
    """Entries dated after the cut-off whose heading or body names the context or its directory."""
    path = root / IMPROVEMENTS_LOG_PATH
    if not path.is_file():
        return []
    needles = [context.name.lower()] + ([context.directory.lower()] if context.directory else [])
    entries: list[dict[str, object]] = []
    for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        m = _ENTRY_RE.match(line.strip())
        if m:
            entries.append({"line": i, "date": m.group(1), "title": m.group(2), "text": [line]})
        elif entries:
            entries[-1]["text"].append(line)
    out = []
    for entry in entries:
        try:
            dated = _dt.date.fromisoformat(str(entry["date"]))
        except ValueError:
            continue
        text = "\n".join(entry["text"]).lower()
        if dated > cutoff and any(n in text for n in needles):
            out.append({"source": f"{_rel(root, path)}:{entry['line']}", "date": entry["date"], "title": entry["title"]})
    return out


def _duplication_row(root: Path) -> tuple[int, str, str] | None:
    """(line, step, what-fails-it) of the first `duplication` row in `_canonical.md` § Build and Run."""
    canonical = root / "_canonical.md"
    if not canonical.is_file():
        return None
    lines = canonical.read_text(encoding="utf-8").splitlines()
    start = next((i for i, l in enumerate(lines) if quality_gates.SECTION_RE.match(l)), None)
    if start is None:
        return None
    header: list[str] | None = None
    for i in range(start + 1, len(lines)):
        line = lines[i]
        if line.startswith("## "):
            break
        if not line.lstrip().startswith("|") or _TABLE_SEP_RE.match(line.strip()):
            continue
        cells = [quality_gates.plain(c) for c in quality_gates.split_row(line)]
        if header is None:
            header = [c.lower() for c in cells]
            if not {"step", "kind", "what fails it"} <= set(header):
                return None
            continue
        if len(cells) >= len(header) and cells[header.index("kind")] == "duplication":
            return i + 1, cells[header.index("step")], quality_gates.split_row(line)[header.index("what fails it")]
    return None


def gather_duplication(root: Path, context: Context) -> dict[str, object]:
    """FR-3 / FR-8: the context's clone figures, or the one-line cause of their absence."""
    result: dict[str, object] = {"status": "absent", "path": None, "clones": None, "lines": None, "reason": None, "source": None}
    row = _duplication_row(root)
    if row is None:
        return result
    line, step, fails_it = row
    result["source"] = f"_canonical.md:{line}"
    na = quality_gates.NA_RE.match(step)
    if na:
        return {**result, "status": "n/a", "reason": na.group(1).strip()}
    found = quality_gates.PATH_RE.search(fails_it.replace("`", ""))
    if not found:
        return {**result, "status": "missing", "reason": "the duplication row names no report path"}
    report_path = found.group(0)
    result["path"] = report_path
    try:
        report = json.loads((root / report_path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {**result, "status": "missing"}
    # jscpd names files relative to its scan root — the context directory with its first segment dropped.
    scoped = [context.directory]
    if context.directory.count("/") > 1:
        scoped.append(context.directory.split("/", 1)[1])
    clones = lines = 0
    for dup in report.get("duplicates", []):
        names = [str((dup.get(side) or {}).get("name", "")).removeprefix("./") for side in ("firstFile", "secondFile")]
        if any(_in_directory(n, d) for n in names for d in scoped):
            clones += 1
            lines += int(dup.get("lines") or 0)
    return {**result, "status": "report", "clones": clones, "lines": lines}


def build_recommendation(root: Path, name: str) -> dict[str, object] | None:
    report, by_id, cutoffs = _count(root)
    record = next((c for c in report["contexts"] if c["context"] == name), None)
    context = next((c for c in read_contexts(root) if c.name == name), None)
    if record is None or context is None:
        return None
    contexts = read_contexts(root)
    counted = [by_id[i] for i in record["closures"] if i in by_id]
    return {
        "schemaVersion": SCHEMA_VERSION,
        "context": name,
        "directory": context.directory,
        "count": record["count"],
        "threshold": record["threshold"],
        "due": record["due"],
        "triggers": record["triggers"],
        "since": cutoffs[name].isoformat(),
        "closures": record["closures"],
        "lastOutcome": record["lastOutcome"],
        "inputs": {
            **gather_spec_inputs(root, counted, context, contexts),
            "improvementsLog": gather_improvements_log(root, context, cutoffs[name]),
            "duplication": gather_duplication(root, context),
        },
    }


def render_recommendation(rec: dict[str, object]) -> str:
    inputs = rec["inputs"]
    state = "due: " + "; ".join(rec["triggers"]) if rec["due"] else "not due"
    lines = [
        f"Consolidation recommendation — {rec['context']} (`{rec['directory']}`), {rec['count']}/{rec['threshold']}, {state}",
        f"Closures since {rec['since']}: " + (", ".join(rec["closures"]) or "none"),
        "",
        "Proposed: a refactor-only IMP for this context (boundaries.md Never do #5), citing the inputs below in its",
        "`## Current State`. Nothing is created until the human accepts; either answer is logged in",
        "docs/consolidation-log.md and resets the counter.",
    ]

    def section(title: str, items: list[str]) -> None:
        lines.extend(["", f"{title} ({len(items)}):"])
        lines.extend(f"  - {item}" for item in items) if items else lines.append("  - none")

    section("Accepted duplication", [f"{x['source']} — {x['text']}" for x in inputs["acceptedDuplication"]])
    section("Rejected reviewer findings", [f"{x['source']} — {x['text']}" for x in inputs["rejectedFindings"]])
    section("Improvements-log entries", [f"{x['source']} — {x['date']} — {x['title']}" for x in inputs["improvementsLog"]])
    dup = inputs["duplication"]
    if dup["status"] == "report":
        figure = f"{dup['clones']} clones, {dup['lines']} duplicated lines ({dup['path']}, row {dup['source']})"
    elif dup["status"] == "missing":
        figure = f"report missing at {dup['path']} (row {dup['source']})" if dup["path"] else f"{dup['reason']} (row {dup['source']})"
    elif dup["status"] == "n/a":
        figure = f"n/a — {dup['reason']} (row {dup['source']})"
    else:
        figure = "no duplication row in _canonical.md § Build and Run"
    lines.extend(["", f"Duplication: {figure}"])
    return "\n".join(lines)


def render_text(report: dict[str, object]) -> str:
    rows = [
        {
            "CONTEXT": str(c["context"]),
            "COUNT": f"{c['count']}/{c['threshold']}",
            "DUE": "due" if c["due"] else "—",
            "TRIGGER": "; ".join(c["triggers"]) or "—",
            "LAST OUTCOME": _render_outcome(c["lastOutcome"]),
        }
        for c in report["contexts"]
    ]
    columns = ["CONTEXT", "COUNT", "DUE", "TRIGGER", "LAST OUTCOME"]
    widths = {col: max([len(col)] + [len(r[col]) for r in rows]) for col in columns}
    lines = ["  ".join(col.ljust(widths[col]) for col in columns).rstrip()]
    lines += ["  ".join(r[col].ljust(widths[col]) for col in columns).rstrip() for r in rows]
    due = sum(1 for c in report["contexts"] if c["due"])
    lines += ["", f"{due} context(s) due; threshold {report['threshold']}, counting since {report['since']}."]
    return "\n".join(lines)


def _render_outcome(outcome: object) -> str:
    if not isinstance(outcome, dict):
        return "—"
    detail = outcome["imp"] if outcome["outcome"] == "accepted" else outcome["reason"]
    return f"{outcome['outcome']} {outcome['date']}" + (f" — {detail}" if detail else "")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="consolidation-due",
        description="Report which bounded contexts are due a consolidation (refactor-only) IMP.",
    )
    parser.add_argument("path", nargs="?", help="project path (default: this repository)")
    parser.add_argument("--json", action="store_true", help="print one JSON report to stdout")
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("--closed", metavar="SPEC-ID", help="only the contexts this spec maps to")
    scope.add_argument("--recommend", metavar="CONTEXT", help="gather one context's recommendation inputs")
    args = parser.parse_args(argv[1:])

    start = Path(args.path).resolve() if args.path else Path(__file__).resolve().parent
    root = find_repo_root(start, tool="consolidation-due")
    if args.recommend:
        rec = build_recommendation(root, args.recommend)
        if rec is None:
            names = ", ".join(c.name for c in read_contexts(root)) or "none"
            parser.error(f"no bounded context named {args.recommend!r} in {MODULE_MAP_PATH} (known: {names})")
        print(json.dumps(rec, indent=2, ensure_ascii=False) if args.json else render_recommendation(rec))
        return 0
    report = build_report(root, args.closed)
    print(json.dumps(report, indent=2, ensure_ascii=False) if args.json else render_text(report))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
