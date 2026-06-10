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


def collect_anchors(text: str) -> set[str]:
    """All valid fragment targets in a markdown file."""
    anchors: set[str] = set()
    slug_counts: dict[str, int] = {}
    for line in _strip_fences(text):
        for m in _ID_RE.finditer(line):
            anchors.add(m.group(1))
        h = _HEADING_RE.match(line)
        if h:
            slug = _slugify(h.group(1))
            n = slug_counts.get(slug, 0)
            anchors.add(slug if n == 0 else f"{slug}-{n}")
            slug_counts[slug] = n + 1
    return anchors


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
    print("validate-anchors: self-test OK (1 deliberate breakage caught).", file=sys.stderr)
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
