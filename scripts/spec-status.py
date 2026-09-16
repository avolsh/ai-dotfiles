#!/usr/bin/env python3
"""spec-status.py — what is active, at which status, how far along, blocked on what.

Reads a project's `docs/specs/` through `speclib.py` and reports one record per
active spec: ID, type, status, risk or severity, owner, tasks done/total, unmet
`depends-on:` IDs, and days since `*Last updated:*`
(IMP-20260914-machine-readable-spec-reports FR-3 – FR-5). Read-only: it never
writes a file, and it always exits 0 — judging the corpus is validate-specs' job.

Usage:
    spec-status.py [path] [--json | --view] [--today YYYY-MM-DD]
    make specs-view [PROJECT=path] [TODAY=YYYY-MM-DD]
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import sys
from pathlib import Path

# The corpus reader lives beside this script; a direct run has no package to import it through.
# No bytecode cache either: these commands write nothing, not even `__pycache__/` beside them.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from speclib import (  # noqa: E402
    _LAST_UPDATED_RE,
    discover_specs,
    find_repo_root,
    task_counts,
)

SCHEMA_VERSION = 1
_LIFECYCLE = ("specify", "plan", "in-progress", "done")
def _as_list(value: object) -> list[str]:
    if isinstance(value, list):
        return [str(v) for v in value]
    return [str(value)] if value not in (None, "") else []


def _optional(value: object) -> str | None:
    return None if value in (None, "") else str(value)


def build_report(root: Path, today: _dt.date) -> dict[str, object]:
    specs, _ = discover_specs(root)
    status_by_id = {str(s.front_matter.get("id")): s.front_matter.get("status") for s in specs}

    records = []
    for spec in specs:
        if spec.path.parent.name != "active":
            continue
        fm = spec.front_matter
        stamp = _LAST_UPDATED_RE.search(spec.body)
        try:
            last_updated = _dt.date.fromisoformat(stamp.group(1)) if stamp else None
        except ValueError:
            last_updated = None  # validate-specs reports the malformed stamp
        records.append(
            {
                "id": str(fm.get("id") or spec.path.stem),
                "path": str(spec.path.relative_to(root)),
                "type": _optional(fm.get("type")),
                "status": _optional(fm.get("status")),
                "risk": _optional(fm.get("risk")),
                "severity": _optional(fm.get("severity")),
                "owner": _optional(fm.get("owner")),
                "tasks": task_counts(spec),
                # Unresolvable IDs are unmet too; validate-specs names them as dangling.
                "unmetDependsOn": [
                    dep for dep in _as_list(fm.get("depends-on")) if status_by_id.get(dep) != "done"
                ],
                "lastUpdated": last_updated.isoformat() if last_updated else None,
                "ageDays": (today - last_updated).days if last_updated else None,
            }
        )

    def order(record: dict[str, object]) -> tuple[int, str]:
        status = record["status"]
        rank = _LIFECYCLE.index(status) if status in _LIFECYCLE else len(_LIFECYCLE)
        return rank, str(record["id"])

    records.sort(key=order)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "root": str(root),
        "today": today.isoformat(),
        "specs": records,
    }


def _cells(record: dict[str, object]) -> dict[str, str]:
    tasks = record["tasks"]
    tier_field = "severity" if record["severity"] else "risk"
    tier = record[tier_field]
    return {
        "ID": str(record["id"]),
        "TYPE": str(record["type"] or "—"),
        "STATUS": str(record["status"] or "—"),
        "TIER": f"{tier_field}:{tier}" if tier else "—",
        "OWNER": str(record["owner"] or "—"),
        "TASKS": f"{tasks['done']}/{tasks['total']}" if isinstance(tasks, dict) else "—",
        "AGE": f"{record['ageDays']}d" if record["ageDays"] is not None else "—",
        "BLOCKED ON": ", ".join(record["unmetDependsOn"]) or "—",  # type: ignore[arg-type]
    }


def _table(rows: list[dict[str, str]], columns: list[str], indent: str = "") -> list[str]:
    widths = {c: max([len(c), *(len(r[c]) for r in rows)]) for c in columns}
    lines = [indent + "  ".join(c.ljust(widths[c]) for c in columns).rstrip()]
    for r in rows:
        lines.append(indent + "  ".join(r[c].ljust(widths[c]) for c in columns).rstrip())
    return lines


def render_text(report: dict[str, object]) -> str:
    records = report["specs"]
    columns = ["ID", "TYPE", "STATUS", "TIER", "OWNER", "TASKS", "AGE", "BLOCKED ON"]
    lines = _table([_cells(r) for r in records], columns) if records else []  # type: ignore[union-attr]
    lines.append(f"{len(records)} active spec(s).")  # type: ignore[arg-type]
    return "\n".join(lines)


def render_view(report: dict[str, object]) -> str:
    """The records grouped under their status, lifecycle order, blocked rows flagged."""
    records: list[dict[str, object]] = report["specs"]  # type: ignore[assignment]
    columns = ["FLAG", "ID", "TYPE", "TIER", "OWNER", "TASKS", "AGE", "BLOCKED ON"]
    lines: list[str] = []
    statuses = [s for s in _LIFECYCLE if any(r["status"] == s for r in records)]
    statuses += sorted({str(r["status"]) for r in records} - set(_LIFECYCLE))
    blocked_total = 0
    for status in statuses:
        group = [r for r in records if str(r["status"]) == status]
        blocked = sum(1 for r in group if r["unmetDependsOn"])
        blocked_total += blocked
        rows = [{**_cells(r), "FLAG": "BLOCKED" if r["unmetDependsOn"] else ""} for r in group]
        if lines:
            lines.append("")
        lines.append(f"{status} ({len(group)}" + (f", {blocked} blocked)" if blocked else ")"))
        lines.extend(_table(rows, columns, indent="  "))
    if lines:
        lines.append("")
    lines.append(f"{len(records)} active spec(s); {blocked_total} blocked.")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="spec-status",
        description="Report every active spec's status, task progress and unmet dependencies.",
    )
    parser.add_argument("path", nargs="?", help="project path (default: this repository)")
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--json", action="store_true", help="print one JSON report to stdout")
    output.add_argument("--view", action="store_true", help="group the records by status, flag blocked specs")
    parser.add_argument(
        "--today",
        type=_dt.date.fromisoformat,
        default=_dt.date.today(),
        help="date ages are measured against (default: today)",
    )
    args = parser.parse_args(argv[1:])

    start = Path(args.path).resolve() if args.path else Path(__file__).resolve().parent
    report = build_report(find_repo_root(start, tool="spec-status"), args.today)
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    elif args.view:
        print(render_view(report))
    else:
        print(render_text(report))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
