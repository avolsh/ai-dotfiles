"""yamlite.py — a YAML subset loader, stdlib only, so validate-specs.py stays zero-dependency.

Supports what framework/spec-workflows/lifecycle.yaml uses: block mappings and sequences (including `- key: v`
items), flow `[...]` / `{...}` (nested, may span lines), plain / 'single' / "double"
scalars, `#` comments, and true/false/null/int. Everything it accepts is valid YAML.
"""
from __future__ import annotations

import re

_INT = re.compile(r"^-?\d+$")


def _scalar(tok: str) -> object:
    if tok[:1] == "'":
        return tok[1:-1].replace("''", "'")
    if tok[:1] == '"':
        return tok[1:-1].encode().decode("unicode_escape") if "\\" in tok else tok[1:-1]
    if tok in ("true", "false"):
        return tok == "true"
    if tok in ("null", "~", ""):
        return None
    return int(tok) if _INT.match(tok) else tok


def _strip_comment(line: str) -> str:
    q = None
    for i, ch in enumerate(line):
        if q:
            q = None if ch == q else q
        elif ch in "'\"" and (i == 0 or line[i - 1] in " [{,:"):
            q = ch
        elif ch == "#" and (i == 0 or line[i - 1] == " "):
            return line[:i].rstrip()
    return line.rstrip()


def _flow(text: str) -> object:
    toks = re.findall(r"'(?:[^']|'')*'|\"(?:[^\"\\]|\\.)*\"|[\[\]{},]|:(?=[\s,\]}]|$)|[^\s\[\]{},:'\"](?:[^\[\]{},:]|:(?![\s,\]}]))*", text)
    pos = 0

    def val():
        nonlocal pos
        t = toks[pos]; pos += 1
        if t == "[":
            out = []
            while toks[pos] != "]":
                out.append(val())
                pos += toks[pos] == ","
            pos += 1
            return out
        if t == "{":
            out = {}
            while toks[pos] != "}":
                k = val(); pos += 1  # ':'
                out[k] = val() if toks[pos] not in ",}" else None
                pos += toks[pos] == ","
            pos += 1
            return out
        return _scalar(t.strip())

    return val()


def _value(text: str) -> object:
    return _flow(text) if text[:1] in "[{" else _scalar(text)


def load(text: str) -> object:
    lines: list[tuple[int, str]] = []
    buf, depth = "", 0
    for raw in text.splitlines():
        s = _strip_comment(raw)
        if not s.strip():
            continue
        if depth:
            buf += " " + s.strip()
        else:
            buf = s
        depth += sum(s.count(c) for c in "[{") - sum(s.count(c) for c in "]}")
        if depth <= 0:
            depth = 0
            lines.append((len(buf) - len(buf.lstrip()), buf.strip()))

    def block(i: int, ind: int) -> tuple[object, int]:
        if lines[i][1].startswith("- ") or lines[i][1] == "-":
            out: list = []
            while i < len(lines) and lines[i][0] == ind and lines[i][1][:1] == "-":
                rest = lines[i][1][1:].strip()
                if not rest:
                    v, i = block(i + 1, lines[i + 1][0]); out.append(v); continue
                if re.match(r"^[^\[{'\"][^:]*:(\s|$)", rest):  # `- key: v` opens a mapping
                    lines[i] = (ind + 2, rest)
                    v, i = block(i, ind + 2); out.append(v); continue
                out.append(_value(rest)); i += 1
            return out, i
        out_m: dict = {}
        while i < len(lines) and lines[i][0] == ind:
            key, _, rest = lines[i][1].partition(":")
            key, rest = _scalar(key.strip()), rest.strip()
            if rest:
                out_m[key] = _value(rest); i += 1
            elif i + 1 < len(lines) and lines[i + 1][0] > ind:
                out_m[key], i = block(i + 1, lines[i + 1][0])
            elif i + 1 < len(lines) and lines[i + 1][0] == ind and lines[i + 1][1][:1] == "-":
                out_m[key], i = block(i + 1, ind)
            else:
                out_m[key] = None; i += 1
        return out_m, i

    return block(0, lines[0][0])[0] if lines else None
