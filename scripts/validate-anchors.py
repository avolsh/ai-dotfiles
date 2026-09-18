#!/usr/bin/env python3
"""validate-anchors.py — markdown anchor-fragment resolver.

For every relative markdown link with a `#fragment` across
`framework/**/*.md` + `docs/**/*.md` (minus vendored/template trees),
verifies the fragment resolves in the target file to either:

  - an explicit `<a id="...">` anchor, or
  - a GitHub-style heading slug (lowercase, punctuation stripped,
    spaces to hyphens; duplicate slugs get `-1`, `-2`, ... suffixes).

`check-md-links.sh` validates that the target *file* exists; this script
covers the gap where a renamed heading or anchor breaks `#fragment`
links silently (e.g. the R10 side-finding in docs/rule-canonical-map.md).

Excluded trees (vendored or placeholder content):
  - framework/templates/**     placeholder links by design
  - framework/upstream/**      vendored, not ours to lint
  - framework/skills/.system/** vendored upstream skill mirrors

Output format mirrors `validate-specs.py` / `lint-rules.py`:
`path:lineno:check:message`. Exit non-zero on any finding.

Self-test: `python3 scripts/validate-anchors.py --self-test` builds a
temporary tree containing one resolving and one deliberately broken
fragment link and asserts both outcomes.

Per spec IMP-20260610-reduce-self-referential-overhead FR-1, stdlib only.
"""

from __future__ import annotations

import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

SEARCH_GLOBS = ("framework/**/*.md", "docs/**/*.md")
EXCLUDE_PREFIXES = (
    "framework/templates/",
    "framework/upstream/",
    "framework/skills/.system/",
)


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    check: str
    message: str

    def render(self, root: Path) -> str:
        return f"{self.path.relative_to(root).as_posix()}:{self.line}:{self.check}:{self.message}"


# ---------------------------------------------------------------------------
# Anchor inventory
# ---------------------------------------------------------------------------

_FENCE_RE = re.compile(r"^(```|~~~)")
_ID_RE = re.compile(r'<a\s+id="([^"]+)"')
_HEADING_RE = re.compile(r"^#{1,6}\s+(.*)$")
_TAG_RE = re.compile(r"<[^>]+>")
_MD_LINK_RE = re.compile(r"\[([^\]]*)\]\([^)]*\)")


def _slugify(heading: str) -> str:
    """GitHub-style heading slug."""
    text = _TAG_RE.sub("", heading)
    text = _MD_LINK_RE.sub(r"\1", text)
    text = text.replace("`", "").replace("*", "").strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def _strip_fences(text: str) -> list[str]:
    """Return lines with fenced code blocks blanked out (line count kept)."""
    out: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if _FENCE_RE.match(line.strip()):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else line)
    return out


def anchor_lines(text: str) -> dict[str, int]:
    """Every valid fragment target in a markdown file, with its 0-based line index.

    `spec-next.py` reads the text at these positions, so both tools resolve a
    fragment the same way.
    """
    anchors: dict[str, int] = {}
    slug_counts: dict[str, int] = {}
    for i, line in enumerate(_strip_fences(text)):
        for m in _ID_RE.finditer(line):
            anchors.setdefault(m.group(1), i)
        h = _HEADING_RE.match(line)
        if h:
            slug = _slugify(h.group(1))
            n = slug_counts.get(slug, 0)
            anchors.setdefault(slug if n == 0 else f"{slug}-{n}", i)
            slug_counts[slug] = n + 1
    return anchors


def collect_anchors(text: str) -> set[str]:
    """All valid fragment targets in a markdown file."""
    return set(anchor_lines(text))


# ---------------------------------------------------------------------------
# Link extraction and validation
# ---------------------------------------------------------------------------

# Link targets: capture the (...) payload of markdown links; the text part
# may span lines, so match the target alone and recover line numbers after.
_TARGET_RE = re.compile(r"\]\(([^)\s]+)\)")
_EXTERNAL_RE = re.compile(r"^[a-z][a-z0-9+.-]*:")  # http:, https:, mailto:, ...


def find_repo_root(start: Path) -> Path:
    """Walk up until docs/specs/ is found, mirroring validate-specs.py."""
    cur = start.resolve()
    for candidate in [cur, *cur.parents]:
        if (candidate / "docs" / "specs").is_dir():
            return candidate
    raise SystemExit(f"validate-anchors: no docs/specs/ ancestor found starting at {start}")


def discover_files(root: Path) -> list[Path]:
    out: list[Path] = []
    for pattern in SEARCH_GLOBS:
        for path in root.glob(pattern):
            rel = path.relative_to(root).as_posix()
            if any(rel.startswith(p) for p in EXCLUDE_PREFIXES):
                continue
            out.append(path)
    return sorted(set(out))


def validate(root: Path, files: list[Path]) -> tuple[list[Finding], int]:
    anchor_cache: dict[Path, set[str]] = {}

    def anchors_of(path: Path) -> set[str]:
        if path not in anchor_cache:
            anchor_cache[path] = collect_anchors(path.read_text(encoding="utf-8"))
        return anchor_cache[path]

    findings: list[Finding] = []
    checked = 0
    for path in files:
        lines = _strip_fences(path.read_text(encoding="utf-8"))
        for lineno, line in enumerate(lines, start=1):
            for m in _TARGET_RE.finditer(line):
                target = m.group(1)
                if _EXTERNAL_RE.match(target) or "#" not in target:
                    continue
                file_part, fragment = target.split("#", 1)
                if not fragment:
                    continue
                dest = path if not file_part else (path.parent / file_part).resolve()
                if not dest.is_file() or dest.suffix != ".md":
                    continue  # missing files are check-md-links.sh territory
                checked += 1
                if fragment not in anchors_of(dest):
                    findings.append(
                        Finding(
                            path=path,
                            line=lineno,
                            check="anchor_missing",
                            message=(
                                f"fragment '#{fragment}' not found in "
                                f"{dest.relative_to(root).as_posix() if dest.is_relative_to(root) else dest.as_posix()!s}"
                            ),
                        )
                    )
    return findings, checked


# ---------------------------------------------------------------------------
# lifecycle.yaml references — `stages:` and `question_lists:` point into the docs
# (IMP-20260914-spec-next-instructions FR-6); `spec-next.py` reads the text there.
# ---------------------------------------------------------------------------

_SCHEMA = Path("framework") / "spec-workflows" / "lifecycle.yaml"
_STAGE_REF_RE = re.compile(r"^[\w./-]+\.md#[\w-]+$")


def _stage_refs(node: object) -> list[str]:
    if isinstance(node, str):
        return [node] if _STAGE_REF_RE.match(node) else []
    if isinstance(node, dict):
        return [r for v in node.values() for r in _stage_refs(v)]
    if isinstance(node, list):
        return [r for v in node for r in _stage_refs(v)]
    return []


def validate_stage_refs(root: Path) -> tuple[list[Finding], int]:
    schema_path = root / _SCHEMA
    if not schema_path.is_file():
        return [], 0
    sys.dont_write_bytecode = True  # like the other scripts: a check writes nothing, not even __pycache__/
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import yamlite  # noqa: PLC0415 — only needed when a schema exists

    text = schema_path.read_text(encoding="utf-8")
    schema = yamlite.load(text) or {}
    lines = text.splitlines()
    findings: list[Finding] = []
    refs = _stage_refs({k: schema.get(k) for k in ("question_lists", "stages")})
    for ref in refs:
        file_part, fragment = ref.split("#", 1)
        dest = root / file_part
        line = next((i for i, t in enumerate(lines, start=1) if ref in t), 1)
        if not dest.is_file():
            problem = f"stage reference '{ref}': file {file_part} does not exist"
        elif fragment not in collect_anchors(dest.read_text(encoding="utf-8")):
            problem = f"stage reference '{ref}': fragment '#{fragment}' not found in {file_part}"
        else:
            continue
        findings.append(Finding(path=schema_path, line=line, check="stage_ref_missing", message=problem))
    return findings, len(refs)


# ---------------------------------------------------------------------------
# Self-test fixture (deliberate broken anchor)
# ---------------------------------------------------------------------------


def self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "docs" / "specs").mkdir(parents=True)
        (root / "framework").mkdir()
        target = root / "framework" / "target.md"
        target.write_text(
            "# Target\n\n## Real Section <a id=\"real-id\"></a>\n", encoding="utf-8"
        )
        source = root / "framework" / "source.md"
        source.write_text(
            "[ok-slug](target.md#real-section)\n"
            "[ok-id](target.md#real-id)\n"
            "[broken](target.md#no-such-anchor)\n",
            encoding="utf-8",
        )
        findings, checked = validate(root, [source, target])
        assert checked == 3, f"expected 3 checked fragments, got {checked}"
        assert len(findings) == 1, f"expected 1 finding, got {findings}"
        assert findings[0].check == "anchor_missing"
        assert "no-such-anchor" in findings[0].message

        # lifecycle.yaml `stages:` / `question_lists:` references (IMP-20260914-spec-next-instructions FR-6).
        schema = root / "framework" / "spec-workflows" / "lifecycle.yaml"
        schema.parent.mkdir(parents=True)
        schema.write_text(
            "question_lists:\n"
            "  CR: {ref: framework/target.md#real-id, limit: '≤10', mandatory: [1]}\n"
            "stages:\n"
            "  specify:\n"
            "    standard:\n"
            "      - {id: author, until: required, refs: [framework/target.md#real-section, framework/target.md#gone]}\n"
            "      - {id: gate, gate: Requirements gate, refs: [framework/missing.md#x]}\n",
            encoding="utf-8",
        )
        stage_findings, stage_checked = validate_stage_refs(root)
        assert stage_checked == 4, f"expected 4 stage references, got {stage_checked}"
        got = sorted(f.message for f in stage_findings)
        assert len(got) == 2 and "#gone" in got[1] and "missing.md" in got[0], got
        assert all(f.check == "stage_ref_missing" for f in stage_findings)
    print("validate-anchors: self-test OK (1 fragment + 2 stage-reference breakages caught).", file=sys.stderr)
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    here = Path(__file__).resolve().parent
    root = find_repo_root(here)
    files = discover_files(root)
    findings, checked = validate(root, files)
    stage_findings, stage_checked = validate_stage_refs(root)
    findings += stage_findings
    checked += stage_checked
    for f in findings:
        print(f.render(root))
    if findings:
        print(
            f"\nvalidate-anchors: {len(findings)} finding(s); "
            f"{checked} fragment link(s) across {len(files)} file(s).",
            file=sys.stderr,
        )
        return 1
    print(
        f"validate-anchors: OK ({checked} fragment link(s) across {len(files)} file(s)).",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
