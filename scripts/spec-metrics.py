#!/usr/bin/env python3
"""Monthly framework-vs-product spec share (FR-6,
IMP-20260610-mechanize-framework-guardrails).

Scans ``docs/specs/archived/`` under each given root, classifies every spec
by its ``affected-repos`` front-matter — only framework repos (``ai-dotfiles``)
=> *framework*, anything else => *product* — and prints per-month counts with
the framework share. A rising framework share means the framework is feeding
on itself instead of shipping product (>30%/month is the watch threshold).

Usage:
    spec-metrics.py [root ...]     # default: repo of this script
"""
from __future__ import annotations

import os
import re
import sys
from collections import defaultdict

FRAMEWORK_REPOS = {"ai-dotfiles"}
WATCH_THRESHOLD = 0.30


def parse_front_matter(path: str) -> dict:
    """Minimal YAML front-matter parse: scalars + one-level string lists."""
    data: dict = {}
    key = None
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return data
    if not lines or lines[0].strip() != "---":
        return data
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if re.match(r"^\s+-\s+", line) and key:
            data.setdefault(key, []).append(line.split("-", 1)[1].strip())
        elif ":" in line and not line.startswith(" "):
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip()
            if value:
                data[key] = value
                key = None
    return data


def classify(front: dict) -> str:
    repos = front.get("affected-repos") or []
    if isinstance(repos, str):
        repos = [repos]
    repos = {r.strip() for r in repos if r.strip()}
    if repos and repos - FRAMEWORK_REPOS:
        return "product"
    return "framework"


def collect(roots: list[str]) -> dict[str, dict[str, int]]:
    months: dict[str, dict[str, int]] = defaultdict(lambda: {"framework": 0, "product": 0})
    for root in roots:
        archived = os.path.join(root, "docs", "specs", "archived")
        if not os.path.isdir(archived):
            continue
        for name in sorted(os.listdir(archived)):
            if not name.endswith(".md"):
                continue
            front = parse_front_matter(os.path.join(archived, name))
            if not front.get("id"):
                continue  # non-spec artifact
            date = str(front.get("date", ""))
            month = date[:7] if re.match(r"^\d{4}-\d{2}", date) else "unknown"
            months[month][classify(front)] += 1
    return months


def main(argv: list[str]) -> int:
    roots = argv or [os.path.dirname(os.path.dirname(os.path.abspath(__file__)))]
    months = collect(roots)
    if not months:
        print("spec-metrics: no archived specs found under:", ", ".join(roots))
        return 0
    print(f"{'month':<10} {'framework':>9} {'product':>8} {'fw-share':>9}")
    total_fw = total_prod = 0
    for month in sorted(months):
        fw = months[month]["framework"]
        prod = months[month]["product"]
        total_fw += fw
        total_prod += prod
        share = fw / (fw + prod) if fw + prod else 0.0
        flag = "  ⚠" if share > WATCH_THRESHOLD else ""
        print(f"{month:<10} {fw:>9} {prod:>8} {share:>8.0%}{flag}")
    share = total_fw / (total_fw + total_prod) if total_fw + total_prod else 0.0
    print(f"{'total':<10} {total_fw:>9} {total_prod:>8} {share:>8.0%}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
