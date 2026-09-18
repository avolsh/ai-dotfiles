#!/usr/bin/env python3
"""baseline-merge.py — merge a spec's `## Baseline Deltas` into its baselines.

`--check` is the preflight: every delta target exists, new IDs follow
req-id-lifecycle.md § Numbering, and no two unrelated active specs change one
REQ-ID. `--diff` prints the merge for the requirements gate and writes
nothing. `--apply` writes the merge at the closure gate, and writes nothing
unless the check is clean (IMP-20260914-baseline-deltas-and-merge FR-6 – FR-8).
Stdlib only; the grammar is shared with validate-specs.py through speclib.py.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import difflib
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from speclib import (  # noqa: E402
    _REQ_DEF_RE,
    BaselineDelta,
    Spec,
    _spec_id,
    check_deltas,
    discover_specs,
    find_repo_root,
    index_baseline,
    parse_baseline_deltas,
)

_VERIFIED_ROW_RE = re.compile(r"^(\|\s*Last src verified\s*\|).*?(\|\s*)$")
_LAST_UPDATED_RE = re.compile(r"^([*_]Last updated:\s*)\d{4}-\d{2}-\d{2}([*_])")


def _annotate(
    lines: tuple[str, ...],
    req_id: str,
    suffix: str,
    new_id: str | None = None,
    trail: str = "",
) -> list[str]:
    """Append `; <suffix>` inside the annotation defining `req_id`.

    An annotation with nothing after its ID takes `trail` — the citations and
    amendments the baseline already carried — so a replacement the author did
    not re-annotate keeps its history.
    """
    out: list[str] = []
    for line in lines:
        m = next((m for m in _REQ_DEF_RE.finditer(line) if m.group(1) == req_id), None)
        if m:
            rest = m.group(2) or trail
            line = f"{line[: m.start()]}*({new_id or req_id}{rest}; {suffix}){line[m.end():]}"
        out.append(line)
    return out


def _trail(lines: list[str], line: int, req_id: str) -> str:
    """What follows `req_id` inside its defining annotation on 1-indexed `line`."""
    m = next(m for m in _REQ_DEF_RE.finditer(lines[line - 1]) if m.group(1) == req_id)
    return m.group(2)


def _sentence(text: str) -> str:
    return text.rstrip(". ") + "."


def render_merge(text: str, delta: BaselineDelta, spec_id: str, closed: str) -> str:
    """The baseline as it reads once `delta` is merged — pure, writes nothing."""
    lines = text.splitlines()
    index = index_baseline(text)
    edits: list[tuple[int, int, list[str]]] = []  # (start, end, replacement) on original lines

    for m in delta.modified:
        entry = index.entries[m.req_id]
        amended = f"amended by {spec_id}" + (f" — {m.why}" if m.why else "")
        trail = _trail(lines, entry.line, m.req_id)
        edits.append((entry.start, entry.end, _annotate(m.lines, m.req_id, amended, trail=trail)))
    for r in delta.removed:
        entry = index.entries[r.req_id]
        tombstone = (
            f"- ~~{r.req_id}~~ deleted — Why: {_sentence(r.reason)} "
            f"Migration: {_sentence(r.migration)}"
        )
        edits.append((entry.start, entry.end, [tombstone]))
    for r in delta.renamed:
        entry = index.entries[r.from_id]
        why = f" — Why: {_sentence(r.why)}" if r.why else ""
        taken = tuple(lines[entry.start : entry.end])
        renamed = _annotate(taken, r.from_id, f"renamed from {r.from_id} by {spec_id}", r.to_id)
        tombstone = f"- ~~{r.from_id}~~ superseded by {r.to_id}{why}"
        edits.append((entry.start, entry.end, [tombstone, *renamed]))

    insertions: dict[int, list[str]] = {}
    for a in delta.added:
        at = next(i for i, heading in index.headings if heading == a.heading)
        end = next((i for i, _ in index.headings if i > at), len(lines))
        while end > at + 1 and not lines[end - 1].strip():
            end -= 1
        insertions.setdefault(end, []).extend(a.lines)
    edits += [(at, at, added) for at, added in insertions.items()]

    for start, end, replacement in sorted(edits, key=lambda e: (e[0], e[1]), reverse=True):
        lines[start:end] = replacement

    for i, line in enumerate(lines):
        row = _VERIFIED_ROW_RE.match(line)
        if row:
            lines[i] = f"{row.group(1)} {closed} ({spec_id}) {row.group(2).lstrip()}"
            break
    for i, line in enumerate(lines):
        stamp = _LAST_UPDATED_RE.match(line)
        if stamp:
            lines[i] = _LAST_UPDATED_RE.sub(rf"\g<1>{closed}\g<2>", line, count=1)
            break
    return "\n".join(lines) + ("\n" if text.endswith("\n") else "")


def _closed(spec: Spec) -> str | None:
    raw = str(spec.front_matter.get("closed", ""))
    try:
        return _dt.date.fromisoformat(raw).isoformat()
    except ValueError:
        return None


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="baseline-merge",
        description="Check or merge a spec's Baseline Deltas into its baselines.",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="preflight only; writes nothing")
    mode.add_argument(
        "--diff", action="store_true", help="print the merge as a unified diff; writes nothing"
    )
    mode.add_argument(
        "--apply", action="store_true", help="merge at the closure gate (needs closed:)"
    )
    parser.add_argument(
        "spec",
        nargs="?",
        help="spec file (--check default: every active spec of the project around "
        "the working directory)",
    )
    args = parser.parse_args(argv[1:])
    if (args.apply or args.diff) and not args.spec:
        parser.error("--apply and --diff need a spec file")

    start = Path(args.spec).resolve().parent if args.spec else Path.cwd()
    root = find_repo_root(start, tool="baseline-merge")
    specs, _ = discover_specs(root)
    if args.spec:
        target = Path(args.spec).resolve()
        chosen = [s for s in specs if s.path.resolve() == target]
        if not chosen:
            print(
                f"baseline-merge: {args.spec} is not a spec under {root}/docs/specs/",
                file=sys.stderr,
            )
            return 2
    else:
        chosen = [s for s in specs if s.path.parent.name == "active"]

    findings = [f for spec in chosen for f in check_deltas(root, spec, specs)]
    for finding in findings:
        print(finding.render(root))
    if findings:
        return 1
    if args.check:
        print(f"baseline-merge: OK ({len(chosen)} spec(s) checked)")
        return 0

    spec = chosen[0]
    deltas = parse_baseline_deltas(spec)
    if deltas is None:
        print(
            f"baseline-merge: {args.spec} has no ## Baseline Deltas; nothing to merge",
            file=sys.stderr,
        )
        return 1
    closed = _closed(spec)
    if args.diff:
        for delta in deltas.baselines:
            before = (root / delta.path).read_text(encoding="utf-8")
            after = render_merge(before, delta, _spec_id(spec), closed or "YYYY-MM-DD")
            sys.stdout.writelines(
                difflib.unified_diff(
                    before.splitlines(keepends=True),
                    after.splitlines(keepends=True),
                    fromfile=f"a/{delta.path}",
                    tofile=f"b/{delta.path}",
                )
            )
        return 0
    if closed is None:
        print(
            f"baseline-merge: set closed: YYYY-MM-DD on {args.spec} before --apply",
            file=sys.stderr,
        )
        return 1
    merged = {
        delta.path: render_merge(
            (root / delta.path).read_text(encoding="utf-8"), delta, _spec_id(spec), closed
        )
        for delta in deltas.baselines
    }
    for path, text in merged.items():
        (root / path).write_text(text, encoding="utf-8")
    print(f"baseline-merge: applied {len(merged)} baseline(s) from {_spec_id(spec)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
