#!/usr/bin/env python3
"""lifecycle_engine.py — interprets framework/spec-workflows/lifecycle.yaml.

The schema declares constants, lanes, macros, rules and plug-ins (grammar in its
header). `run(root, corpora, plugins)` evaluates every rule over the documents the
caller discovered and calls every plug-in the schema names; `load_schema(plugins)`
refuses a schema naming an op, lane, macro or plug-in that does not resolve, so a
broken schema fails loudly instead of silently checking less
(IMP-20260917-lifecycle-schema-engine FR-3).

`python3 lifecycle_engine.py --advisory [PATH]` prints the advisory findings
(required sections) for the project containing PATH.
"""
from __future__ import annotations

import datetime as _dt
import re
import sys
from pathlib import Path
from typing import Callable

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import yamlite  # noqa: E402
from speclib import Finding, Spec, _h2_section_lines, discover_specs, find_repo_root  # noqa: E402

SCHEMA_PATH = Path(__file__).resolve().parents[1] / "framework" / "spec-workflows" / "lifecycle.yaml"
_STATUS_ORDER = ["specify", "plan", "in-progress", "done"]
_EXPR_KEYS = ("where", "when", "line")
_BINDING_KEYS = ("with", "each", "let")


class SchemaError(Exception):
    """lifecycle.yaml names something the engine cannot resolve."""


def _date(v: object) -> _dt.date | None:
    try:
        return _dt.date.fromisoformat(v) if isinstance(v, str) else None
    except ValueError:
        return None


def _citations(rx: str, text: str) -> list[int]:
    cited: set[int] = set()
    for m in re.finditer(rx, text):
        a = int(m.group(1)); b = int(m.group(2)) if m.group(2) else a
        cited.update(range(a, b + 1) if b >= a else (a, b))
    return sorted(cited)


def _has_h2(doc: Spec, title: str) -> bool:
    fence = None
    for line in doc.body.splitlines():
        s = line.lstrip()
        if fence:
            fence = None if s.startswith(fence) else fence
        elif s.startswith(("```", "~~~")):
            fence = s[:3]
        elif s.startswith("## ") and s[3:].strip().lower() == title.lower():
            return True
    return False


def _docview(d: Spec, root: Path) -> dict:
    sid = d.front_matter.get("id")
    return {"path": d.path, "name": d.path.name, "stem": d.path.stem, "dir": d.path.parent.name,
            "folder": d.path.parent, "fm": d.front_matter, "sid": sid if isinstance(sid, str) else d.path.stem,
            "fm_end": d.front_matter_end_line or 1, "body_offset": d.front_matter_end_line or 0,
            "body": d.body, "root": root, "root_name": root.name}


class Ctx:
    def __init__(self, doc: Spec, env: dict, world: dict):
        self.doc, self.env, self.world = doc, env, world
        self.view = _docview(doc, world["root"])

    def ev(self, x: object) -> object:
        if isinstance(x, str) and x.startswith("$"):
            head, *path = x[1:].split(".", 1 if x.startswith(("$fm.", "$doc.")) else -1)
            val = {"fm": self.doc.front_matter, "doc": self.view}[head] if head in ("fm", "doc") else self.env[head]
            for key in path:
                val = val[int(key)] if isinstance(val, list) else (val.get(key) if isinstance(val, dict) else None)
            return val
        if isinstance(x, list):
            return [self.ev(i) for i in x]
        if isinstance(x, dict) and len(x) == 1:
            (op, arg), = x.items()
            return OPS[op](self, arg)
        return x

    def with_(self, **kv) -> "Ctx":
        c = Ctx.__new__(Ctx)
        c.doc, c.env, c.world, c.view = self.doc, {**self.env, **kv}, self.world, self.view
        return c


def _a(c: Ctx, a):
    return [c.ev(i) for i in a] if isinstance(a, list) else [c.ev(a)]


def _lam(c: Ctx, a, fn):  # [list, expr-over-$it]
    return fn((i, c.with_(it=i).ev(a[1])) for i in (c.ev(a[0]) or []))


OPS: dict[str, Callable] = {
    # logic and comparison
    "not": lambda c, a: not c.ev(a),
    "all": lambda c, a: all(c.ev(i) for i in a),
    "any": lambda c, a: any(c.ev(i) for i in a),
    "if": lambda c, a: c.ev(a[1]) if c.ev(a[0]) else c.ev(a[2]),
    "eq": lambda c, a: (lambda x, y: x == y)(*_a(c, a)),
    "in": lambda c, a: (lambda x, y: isinstance(y, (list, set, dict, str)) and x in y)(*_a(c, a)),
    "gt": lambda c, a: (lambda x, y: x is not None and y is not None and x > y)(*_a(c, a)),
    "ge": lambda c, a: (lambda x, y: x is not None and y is not None and x >= y)(*_a(c, a)),
    # front matter and types
    "has": lambda c, a: c.ev(a) in c.doc.front_matter,
    "is_str": lambda c, a: isinstance(c.ev(a), str),
    "is_list": lambda c, a: isinstance(c.ev(a), list),
    "blank": lambda c, a: (lambda v: not isinstance(v, str) or not v.strip())(c.ev(a)),
    "typename": lambda c, a: type(c.ev(a)).__name__,
    "get": lambda c, a: (lambda m, k: m.get(k) if isinstance(m, dict) else (m[k] if isinstance(m, list) and isinstance(k, int) and -len(m) <= k < len(m) else None))(*_a(c, a)),
    "list": lambda c, a: (lambda v: v if isinstance(v, list) else [])(c.ev(a)),
    # strings and regex
    "matches": lambda c, a: (lambda v, rx: isinstance(v, str) and re.search(rx, v) is not None)(*_a(c, a)),
    "startswith": lambda c, a: (lambda v, p: isinstance(v, str) and v.startswith(tuple(p) if isinstance(p, list) else p))(*_a(c, a)),
    "strip": lambda c, a: (lambda v, ch=None: v.strip(ch) if isinstance(v, str) else v)(*_a(c, a)),
    "rstrip": lambda c, a: (lambda v, ch=None: v.rstrip(ch) if isinstance(v, str) else v)(*_a(c, a)),
    "split": lambda c, a: (lambda v, sep: v.split(sep) if isinstance(v, str) else [])(*_a(c, a)),
    "sub": lambda c, a: (lambda v, rx, rep: re.sub(rx, rep, v, count=1) if isinstance(v, str) else v)(*_a(c, a)),
    "group": lambda c, a: (lambda v, rx, n: (m.group(n) if isinstance(v, str) and (m := re.match(rx, v)) else None))(*_a(c, a)),
    "search": lambda c, a: (lambda v, rx, n: (m.group(n) if isinstance(v, str) and (m := re.search(rx, v)) else None))(*_a(c, a)),
    "finditer": lambda c, a: (lambda v, rx, n: [m.group(n) for m in re.finditer(rx, v)])(*_a(c, a)),
    "matching": lambda c, a: (lambda v, t: [k for k, rx in t.items() if isinstance(v, str) and re.search(rx, v)])(*_a(c, a)),
    "citations": lambda c, a: _citations(*_a(c, a)),
    "join": lambda c, a: (lambda v, sep: sep.join(v))(*_a(c, a)),
    # numbers, dates, collections
    "len": lambda c, a: len(c.ev(a)),
    "add": lambda c, a: sum(_a(c, a)),
    "date": lambda c, a: _date(c.ev(a)),
    "today": lambda c, a: _dt.date.today(),
    "days": lambda c, a: (lambda x, y: (x - y).days if x and y else None)(*_a(c, a)),
    "concat": lambda c, a: [i for part in _a(c, a) for i in part],
    "sorted": lambda c, a: sorted(c.ev(a)),
    "unique": lambda c, a: sorted(set(c.ev(a))),
    "intersect": lambda c, a: sorted(set(_a(c, a)[0]) & set(_a(c, a)[1])),
    "minus": lambda c, a: (lambda x, y: sorted(set(x) - set(y)))(*_a(c, a)),
    "keys": lambda c, a: list(c.ev(a)),
    "items": lambda c, a: [list(kv) for kv in c.ev(a).items()],
    "map": lambda c, a: _lam(c, a, lambda it: [v for _, v in it]),
    "filter": lambda c, a: _lam(c, a, lambda it: [i for i, v in it if v]),
    "flatmap": lambda c, a: _lam(c, a, lambda it: [x for _, v in it for x in v]),
    "first": lambda c, a: _lam(c, a, lambda it: next((i for i, v in it if v), None)),
    "call": lambda c, a: c.with_(it=c.ev(a[1])).ev(c.world["macros"][a[0]]),
    # markdown structure (via the shared reader)
    "body_lines": lambda c, a: [{"n": i, "text": t} for i, t in enumerate(c.doc.body.splitlines(), start=1)],
    "section_lines": lambda c, a: [{"n": n, "text": t} for n, t in _h2_section_lines(c.doc, set(c.ev(a)))],
    "has_section": lambda c, a: _has_h2(c.doc, c.ev(a)),
    "first_lines": lambda c, a: (lambda lines, rx: {int(m.group(1)): ln["n"] for ln in reversed(lines) if (m := re.match(rx, ln["text"]))})(*_a(c, a)),
    "status_at_least": lambda c, a: (lambda s, floor: s in _STATUS_ORDER and _STATUS_ORDER.index(s) >= _STATUS_ORDER.index(floor))(*_a(c, a)),
    # corpus and filesystem
    "ids": lambda c, a: c.world["ids"][c.ev(a)],
    "fm_of": lambda c, a: (lambda d: d.front_matter if d else None)(c.world["by_id"]["specs"].get(c.ev(a))),
    "later_docs": lambda c, a: [_docview(d, c.world["root"]) for d in sorted(c.world["corpora"]["specs"], key=lambda d: d.path)
                                if d.path.parent.name == c.ev(a) and d.path > c.doc.path],
    "exists": lambda c, a: (lambda base, rel: (Path(base) / rel).resolve().exists())(*_a(c, a)),
}


def _check_expr(x: object, where: str, macros: dict) -> None:
    if isinstance(x, list):
        for i in x:
            _check_expr(i, where, macros)
    elif isinstance(x, dict) and x:  # `{}` is an empty-map literal
        if len(x) != 1:
            raise SchemaError(f"{where}: expression must be a single-key map, got keys {sorted(x)}")
        (op, arg), = x.items()
        if op not in OPS:
            raise SchemaError(f"{where}: unknown op {op!r}")
        if op == "call" and (not isinstance(arg, list) or arg[:1] and arg[0] not in macros):
            raise SchemaError(f"{where}: call to unknown macro {arg[0] if isinstance(arg, list) and arg else arg!r}")
        _check_expr(arg, where, macros)


def load_schema(plugins: dict[str, Callable], path: Path = SCHEMA_PATH) -> dict:
    """Parse the schema and refuse any name that does not resolve."""
    try:
        schema = yamlite.load(path.read_text(encoding="utf-8"))
    except (OSError, IndexError, KeyError, ValueError) as exc:
        raise SchemaError(f"{path}: cannot load ({type(exc).__name__}: {exc})") from exc
    macros, lanes = schema.get("macros") or {}, schema.get("lanes") or {}
    for name, expr in macros.items():
        _check_expr(expr, f"macro {name}", macros)
    for name, expr in lanes.items():
        _check_expr(expr, f"lane {name}", macros)
    for section in ("rules", "advisory"):
        for rule in schema.get(section) or []:
            where = f"{section} {rule.get('id', '<no id>')}"
            if not rule.get("id") or "when" not in rule or "message" not in rule:
                raise SchemaError(f"{where}: a rule needs id, when and message")
            if "lane" in rule and rule["lane"] not in lanes:
                raise SchemaError(f"{where}: unknown lane {rule['lane']!r}")
            if rule.get("corpus", "specs") not in ("specs", "agents"):
                raise SchemaError(f"{where}: unknown corpus {rule['corpus']!r}")
            for key in _EXPR_KEYS:
                _check_expr(rule.get(key), where, macros)
            for key in _BINDING_KEYS:
                for expr in (rule.get(key) or {}).values():
                    _check_expr(expr, where, macros)
    named = [p.get("fn") for p in schema.get("plugins") or []]
    for fn in named:
        if fn not in plugins:
            raise SchemaError(f"plugins: {fn!r} has no implementation")
    for p in schema.get("plugins") or []:
        if not set(p.get("args") or []) <= {"specs", "root"}:
            raise SchemaError(f"plugins {p['fn']}: unknown args {p.get('args')}")
    for fn in plugins:
        if fn not in named:
            raise SchemaError(f"plugins: {fn!r} is implemented but not named in {path.name}")
    return schema


def _iterate(ctx: Ctx, each: dict):
    if not each:
        yield ctx
        return
    (name, source), *rest = each.items()
    for item in ctx.ev(source) or []:
        yield from _iterate(ctx.with_(**{name: item}), dict(rest))


def run(root: Path, corpora: dict[str, list], plugins: dict[str, Callable],
        advisory: bool = False, schema: dict | None = None) -> list[Finding]:
    """Evaluate the schema's rules (or advisory rules) and plug-ins over `corpora`."""
    schema = schema or load_schema(plugins)
    world = {
        "root": root, "corpora": corpora, "macros": schema.get("macros") or {},
        "ids": {n: {d.front_matter["id"] for d in docs if isinstance(d.front_matter.get("id"), str)} for n, docs in corpora.items()},
        "by_id": {n: {d.front_matter["id"]: d for d in docs if isinstance(d.front_matter.get("id"), str)} for n, docs in corpora.items()},
    }
    consts = {**(schema.get("consts") or {}), "required_sections": schema.get("required_sections") or {}}
    lanes = schema.get("lanes") or {}
    findings: list[Finding] = []
    for rule in schema.get("advisory" if advisory else "rules") or []:
        for doc in corpora[rule.get("corpus", "specs")]:
            base = Ctx(doc, dict(consts), world)
            if "lane" in rule and not base.ev(lanes[rule["lane"]]):
                continue
            for k, v in (rule.get("with") or {}).items():
                base = base.with_(**{k: base.ev(v)})
            if "where" in rule and not base.ev(rule["where"]):
                continue
            for ctx in _iterate(base, rule.get("each") or {}):
                for k, v in (rule.get("let") or {}).items():
                    ctx = ctx.with_(**{k: ctx.ev(v)})
                if ctx.ev(rule["when"]):
                    line = ctx.ev(rule.get("line", "$doc.fm_end"))
                    message = rule["message"].format(doc=ctx.view, fm=doc.front_matter, **ctx.env)
                    findings.append(Finding(doc.path, line, rule["id"], message))
    if not advisory:
        args = {"specs": corpora["specs"], "root": root}
        for p in schema.get("plugins") or []:
            findings += plugins[p["fn"]](*[args[x] for x in p["args"]])
    return findings


if __name__ == "__main__":
    argv = [a for a in sys.argv[1:] if a != "--advisory"]
    if "--advisory" not in sys.argv:
        sys.exit("usage: lifecycle_engine.py --advisory [PATH]  (enforced rules run through validate-specs.py)")
    root = find_repo_root(Path(argv[0]).resolve() if argv else Path.cwd())
    specs, _ = discover_specs(root)
    schema = yamlite.load(SCHEMA_PATH.read_text(encoding="utf-8"))
    names = {p["fn"]: None for p in schema.get("plugins") or []}
    for f in run(root, {"specs": specs, "agents": []}, names, advisory=True, schema=load_schema(names)):
        print(f.render(root))
