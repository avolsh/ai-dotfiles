#!/usr/bin/env python3
"""spec-next.py — the rules, questions and gate for one spec's next step.

    spec-next.py [--json] <spec path | spec id>

Reads the spec's type, lane and status, picks the next step from `stages:` in
`framework/spec-workflows/lifecycle.yaml` (the first step whose `until` is not
met), and prints only that step: the sections it still needs, its questions one
line each, the gate that ends the status, and its rules as `path#anchor` with the
first sentence read from the canonical doc at run time — the schema holds no copy
of rule text (IMP-20260914-spec-next-instructions). `--json` emits the same fields.

Read-only. Exit 0 with a step; exit 2 when the spec, the schema or a reference
does not resolve — prompts fall back to their full loading step on that exit.
"""
from __future__ import annotations

import importlib.util
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lifecycle_engine  # noqa: E402
import yamlite  # noqa: E402
from speclib import Spec, _h2_section_lines, _parse_front_matter, _row_cells, find_repo_root  # noqa: E402

FRAMEWORK_ROOT = HERE.parent
_STATUS_ORDER = ["specify", "plan", "in-progress", "done"]
_SEP_RE = re.compile(r"^\s*\|(?:\s*:?-+:?\s*\|)+\s*$")
_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
_PLACEHOLDER_RE = re.compile(r"^(?:<.*>|Pending\b.*|.*\.\.\.)$")
_QUESTION_RE = re.compile(r"^(\d+)\.\s+\*\*(.+?)\*\*")
_HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
_ANCHOR_TAG_RE = re.compile(r"</?a\b[^>]*>")
_LINK_RE = re.compile(r"\[([^\]]*)\]\([^)]*\)")
_ITEM_RE = re.compile(r"^\s*(?:[-*]|\d+\.)\s+")
_LINE_CAP = 280
_SHORT_LEAD = 40  # characters; a lead this short names its rule rather than stating it


class Unresolved(Exception):
    """The spec, the schema or a reference cannot be resolved."""


def _anchor_lines() -> callable:
    spec = importlib.util.spec_from_file_location("validate_anchors", HERE / "validate-anchors.py")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod  # its dataclass resolves annotations through sys.modules
    spec.loader.exec_module(mod)
    return mod.anchor_lines


anchor_lines = _anchor_lines()


# ---------------------------------------------------------------------------
# Reading the canonical docs
# ---------------------------------------------------------------------------


def _clean(text: str) -> str:
    text = _ANCHOR_TAG_RE.sub("", text)
    text = _LINK_RE.sub(r"\1", text).replace("**", "")
    return re.sub(r"\s+", " ", text).strip()


def _sentences(text: str) -> list[str]:
    out, start, in_code = [], 0, False
    for i, ch in enumerate(text):
        if ch == "`":
            in_code = not in_code
        elif ch in ".!?" and not in_code and (i + 1 == len(text) or text[i + 1] == " "):
            out.append(text[start: i + 1].strip())
            start = i + 1
    tail = text[start:].strip()
    return out + ([tail] if tail else [])


def _cap(text: str) -> str:
    return text if len(text) <= _LINE_CAP else text[: _LINE_CAP - 1].rstrip() + "…"


def _summary(paragraphs: list[str]) -> str:
    """The first sentence. A short lead ("Baseline deltas.") names its rule rather than stating it, so it is
    followed by the section's first bold statement, else its first MUST, else its first Never."""
    first = _sentences(paragraphs[0]) if paragraphs else []
    if not first:
        return ""
    lead = _clean(first[0])
    if len(lead) >= _SHORT_LEAD:
        return _cap(lead)
    later = first[1:] + [x for para in paragraphs[1:] for x in _sentences(para)]
    rule = (next((x for x in later if x.startswith("**") and x.rstrip(".").endswith("**")), None)
            or next((x for x in later if re.search(r"\bMUST\b", x)), None)
            or next((x for x in later if re.search(r"\b[Nn]ever\b", x)), None)
            or (first[1] if len(first) > 1 else None))
    return _cap(f"{lead} {_clean(rule)}" if rule else lead)


def _section_paragraphs(lines: list[str], start: int, first: str = "") -> list[str]:
    """Prose paragraphs from `start` to the next heading or anchor; fences, tables and later list items skipped.

    `first` is the anchored line's own text, which opens the first paragraph.
    """
    paragraphs: list[str] = []
    current = [first.strip()] if first.strip() else []
    fence = None

    def close() -> None:
        if current:
            paragraphs.append(" ".join(current))
            current.clear()

    for line in lines[start:]:
        s = line.strip()
        if fence:
            fence = None if s.startswith(fence) else fence
            continue
        if _HEADING_RE.match(s) or ("<a id=" in s and (current or paragraphs)):
            break
        if s.startswith(("```", "~~~")):
            close()
            fence = s[:3]
        elif not s or s.startswith(("|", "<!--")):
            close()
        elif _ITEM_RE.match(line):
            close()
            if not paragraphs:  # a section that opens with a list: its first item is the lead
                current.append(_ITEM_RE.sub("", s, count=1))
        else:
            current.append(s)
    close()
    return [_ANCHOR_TAG_RE.sub("", _LINK_RE.sub(r"\1", p)) for p in paragraphs]  # bold kept for _summary


def _doc(path: str) -> tuple[list[str], dict[str, int]]:
    file = FRAMEWORK_ROOT / path
    if not file.is_file():
        raise Unresolved(f"reference file does not exist: {path}")
    text = file.read_text(encoding="utf-8")
    return text.splitlines(), anchor_lines(text)


def rule_line(ref: str) -> str:
    """First sentence at `path#anchor`: a heading's title plus its first paragraph, or the anchored sentence."""
    path, _, fragment = ref.partition("#")
    lines, anchors = _doc(path)
    if fragment not in anchors:
        raise Unresolved(f"anchor not found: {ref}")
    pos = anchors[fragment]
    heading = _HEADING_RE.match(lines[pos])
    if heading:
        title = _clean(heading.group(2))
        body = _summary(_section_paragraphs(lines, pos + 1))
        return f"{title} — {body}" if body else title
    tag = next((t for t in _ANCHOR_TAG_RE.finditer(lines[pos]) if fragment in t.group(0)), None)
    rest = lines[pos][tag.end():] if tag else _ITEM_RE.sub("", lines[pos], count=1)
    return _summary(_section_paragraphs(lines, pos + 1, first=rest))


def section_span(ref: str) -> dict:
    """1-based line range of the section a heading anchor opens, up to the next heading of its level or higher."""
    path, _, fragment = ref.partition("#")
    lines, anchors = _doc(path)
    if fragment not in anchors:
        raise Unresolved(f"anchor not found: {ref}")
    start = anchors[fragment]
    heading = _HEADING_RE.match(lines[start])
    level = len(heading.group(1)) if heading else 7
    end, fence = len(lines), None
    for i in range(start + 1, len(lines)):
        s = lines[i].strip()
        if fence:
            fence = None if s.startswith(fence) else fence
        elif s.startswith(("```", "~~~")):
            fence = s[:3]
        elif (m := _HEADING_RE.match(s)) and len(m.group(1)) <= level:
            end = i
            break
    return {"ref": ref, "path": str(FRAMEWORK_ROOT / path), "start": start + 1, "end": end}


def questions(entry: dict) -> dict:
    path, _, fragment = entry["ref"].partition("#")
    lines, anchors = _doc(path)
    if fragment not in anchors:
        raise Unresolved(f"anchor not found: {entry['ref']}")
    mandatory = set(entry.get("mandatory") or [])
    items = []
    for line in lines[anchors[fragment] + 1:]:
        if _HEADING_RE.match(line):
            break
        m = _QUESTION_RE.match(line)
        if m:
            n = int(m.group(1))
            items.append({"n": n, "title": _clean(m.group(2)).rstrip(":."), "mandatory": n in mandatory})
    if not items:
        raise Unresolved(f"no numbered questions under {entry['ref']}")
    return {"list": entry["ref"], "limit": entry.get("limit"), "items": items}


# ---------------------------------------------------------------------------
# Reading the spec
# ---------------------------------------------------------------------------


def _load_spec(arg: str) -> tuple[Path, Spec]:
    path = Path(arg)
    if not path.is_file() and re.match(r"^(CR|BUG|IMP|RES)-\d{8}-[a-z0-9-]+$", arg):
        root = find_repo_root(Path.cwd(), tool="spec-next")
        path = next((root / "docs" / "specs" / d / f"{arg}.md" for d in ("active", "archived")
                     if (root / "docs" / "specs" / d / f"{arg}.md").is_file()), path)
    if not path.is_file():
        raise Unresolved(f"spec not found: {arg}")
    path = path.resolve()
    fm, body, end, found = _parse_front_matter(path.read_text(encoding="utf-8"), path)
    if found:
        raise Unresolved(f"{path.name}: front matter does not parse")
    return path, Spec(path, fm, body, end)


def filled(spec: Spec, title: str) -> bool:
    lines = _h2_section_lines(spec, {title.lower()})
    text = _COMMENT_RE.sub("", "\n".join(t for _, t in lines))
    content = [s.strip() for s in text.splitlines() if s.strip()]
    return bool(content) and not all(_PLACEHOLDER_RE.match(s) for s in content)


def tasks(spec: Spec) -> list[dict]:
    rows, body = [], False
    for n, line in _h2_section_lines(spec, {"tasks"}):
        if _SEP_RE.match(line):
            body = True
        elif body and line.strip().startswith("|"):
            cells = _row_cells(line.strip())
            if len(cells) >= 3:
                rows.append({"id": cells[0], "description": cells[1], "files": cells[2] if len(cells) > 3 else "",
                             "status": cells[-1], "line": n})
        elif body and not line.strip():
            body = False
    return rows


# ---------------------------------------------------------------------------
# Resolving the next step
# ---------------------------------------------------------------------------


def _lane(spec: Spec, schema: dict, root: Path) -> str:
    ctx = lifecycle_engine.Ctx(spec, {}, {"root": root, "corpora": {}, "macros": {}, "ids": {}, "by_id": {}})
    lanes = schema.get("lanes") or {}
    for name in ("trivial", "research"):
        if name in lanes and ctx.ev(lanes[name]):
            return name
    return "standard"


def _required(schema: dict, doc_type: str, status: str) -> list[str]:
    floors = (schema.get("required_sections") or {}).get(doc_type) or {}
    reach = _STATUS_ORDER.index(status)
    return [s for floor, secs in floors.items() if _STATUS_ORDER.index(floor) <= reach for s in secs]


def _until(step: dict, schema: dict, spec: Spec, status: str) -> list[str]:
    until = step.get("until")
    items = [until] if isinstance(until, str) else list(until or [])
    doc_type = str(spec.front_matter.get("type"))
    return [s for item in items for s in (_required(schema, doc_type, status) if item == "required" else [item])
            if s != "tasks_done"]


def resolve(arg: str) -> dict:
    path, spec = _load_spec(arg)
    fm = spec.front_matter
    status, doc_type = fm.get("status"), fm.get("type")
    if status not in _STATUS_ORDER or not isinstance(doc_type, str):
        raise Unresolved(f"{path.name}: status={status!r} type={doc_type!r} is not a lifecycle state")
    schema = yamlite.load(lifecycle_engine.SCHEMA_PATH.read_text(encoding="utf-8"))
    lane = _lane(spec, schema, path.parent)
    report = {"spec": str(path), "id": fm.get("id", path.stem), "type": doc_type, "lane": lane, "status": status,
              "step": None, "procedure": None, "missing_sections": [], "questions": None, "task": None,
              "gate": None, "rules": [], "files": [], "sections": []}
    if status == "done":
        return report
    by_lane = (schema.get("stages") or {}).get(status)
    if not by_lane:
        raise Unresolved(f"lifecycle.yaml has no stages for status {status!r}")
    steps = by_lane.get(lane) or by_lane.get("standard")
    gate_step = next((s for s in reversed(steps) if s.get("gate")), None)

    step = None
    for candidate in steps:
        missing = [s for s in _until(candidate, schema, spec, status) if not filled(spec, s)]
        pending = [t for t in tasks(spec) if not t["status"].startswith(("☑", "⊘"))] if candidate.get("until") == "tasks_done" else []
        if missing or pending or not candidate.get("until"):
            step = candidate
            report["missing_sections"] = missing
            report["task"] = pending[0] if pending else None
            break
    step = step or gate_step
    report["step"] = {"id": step["id"], "label": step["label"]}
    if step.get("procedure"):
        report["procedure"] = {"ref": step["procedure"], "line": rule_line(step["procedure"])}
    if step.get("questions"):
        key = doc_type if step["questions"] == "by_type" else step["questions"]
        entry = (schema.get("question_lists") or {}).get(key)
        if not entry:
            raise Unresolved(f"lifecycle.yaml has no question list {key!r}")
        report["questions"] = questions(entry)
    if gate_step:
        report["gate"] = {"label": gate_step["label"], "text": gate_step["gate"]}
    report["rules"] = [{"ref": ref, "line": rule_line(ref)} for ref in step.get("refs") or []]

    template = FRAMEWORK_ROOT / "framework" / "spec-workflows" / "templates" / f"{doc_type}-TEMPLATE.md"
    report["files"] = [str(template)] if step["id"] == "author" and template.is_file() else []
    report["sections"] = [section_span(step["procedure"])] if step.get("procedure") else []
    return report


def render(r: dict) -> str:
    out = [f"{r['id']} — {r['type']} · {r['lane']} lane · status {r['status']}"]
    if r["step"] is None:
        out.append("No next step: the spec is done.")
        return "\n".join(out)
    out.append(f"Next step: {r['step']['label']}")
    if r["task"]:
        t = r["task"]
        out.append(f"Task: {t['id']} ({t['status']}) — {t['description']}")
        if t["files"]:
            out.append(f"Task files: {t['files']}")
    if r["procedure"]:
        out.append(f"Procedure: {r['procedure']['ref']} — {r['procedure']['line']}")
    out.append("Missing sections: " + (", ".join(r["missing_sections"]) or "none"))
    q = r["questions"]
    if q:
        out.append(f"Questions ({q['limit']} — {q['list'].partition('#')[0]}):")
        out += [f"  Q{i['n']} {i['title']}" + (" (mandatory)" if i["mandatory"] else "") for i in q["items"]]
    else:
        out.append("Questions: none for this step")
    if r["gate"]:
        out.append(f"Gate: {r['gate']['label']} — {r['gate']['text']}")
    out.append("Rules:")
    out += [f"  - {x['ref']} — {x['line']}" for x in r["rules"]]
    if r["files"] or r["sections"]:
        out.append("Load:")
        out += [f"  - {f}" for f in r["files"]]
        out += [f"  - {x['path']} lines {x['start']}–{x['end']} (the procedure section only)" for x in r["sections"]]
    return "\n".join(out)


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if a != "--json"]
    if len(args) != 1:
        print("usage: spec-next.py [--json] <spec path | spec id>", file=sys.stderr)
        return 2
    try:
        report = resolve(args[0])
    except (Unresolved, OSError, ValueError, KeyError) as exc:
        print(f"spec-next: {exc}", file=sys.stderr)
        return 2
    except SystemExit as exc:  # speclib.find_repo_root reports a missing docs/specs/ this way
        print(exc, file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2, ensure_ascii=False) if "--json" in argv else render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
