# IMP-20260914-explore-mode-and-lane-review — lane review

*Last updated: 2026-09-17*

Evidence for FR-3 / FR-6 (T3) and the decisions of FR-4 (T4). Counted on 2026-09-17 over both corpora:
`env/ai-dotfiles` and `src/github.com/tobeverse/tobevisit-content`, run from the ai-dotfiles root.

## Usage

| Lane | ai-dotfiles | tobevisit-content | Total | Specs / entries |
|---|---|---|---|---|
| RES | 2 | 0 | 2 | `RES-20260520-trivial-lane-applicability` (the lane's dry-run), `RES-20260914-declarative-lifecycle-schema` |
| Trivial | 0 | 1 | 1 | `CR-20260728-dedup-dismiss-note-inline` |
| Direct | 4 | 4 | 8 | improvements-log entries whose `Spec / task` names `Direct lane` |
| (all archived specs) | 49 | 111 | 160 | — |

```bash
C=../../src/github.com/tobeverse/tobevisit-content
for r in . $C; do
  echo "$r archived=$(ls $r/docs/specs/archived/*.md | grep -vc README.md)" \
       "RES=$(grep -l '^type: RES' $r/docs/specs/*/*.md | wc -l)" \
       "Trivial=$(grep -lE '^(risk|severity): trivial' $r/docs/specs/*/*.md | wc -l)" \
       "Direct=$(grep -cE '^\s*-\s*\*\*Spec / task:\*\*.*Direct lane' $r/docs/improvements-log.md)"
done
```

## Footprint in lines

Prose is the lane's own sections (heading to next heading of its level): `spec-lifecycle.md`, `spec-workflow-guide.md`,
and for RES `spec-templates-guide.md` + `authoring-steps.md § D`, for Trivial `spec-types.md`, for Direct the
`Direct` / `Closed` lines of `improvements-log-format.md`. `lifecycle.yaml` counts the lane's rule blocks, constants,
lane expression, `stages:` entry and question list. Test lines are lines naming the lane in the three validator /
spec-next test scripts — a lower bound.

| Lane | prose | prompt+questions+template | lifecycle.yaml | plug-in code | tests (keyword lines) | Total |
|---|---|---|---|---|---|---|
| RES | 207 | 209 | 75 | 0 | 33 | 524 |
| Trivial | 165 | 86 | 42 | 0 | 35 | 328 |
| Direct | 46 | 0 | 1 | 61 | 14 | 122 |

Reproduce with the script below (`python3 lane_footprint.py --detail` prints each term):

```python
#!/usr/bin/env python3
"""Lane footprint in lines — run from the ai-dotfiles root: python3 lane_footprint.py [--detail]."""
import importlib.util
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("va", "scripts/validate-anchors.py")
va = importlib.util.module_from_spec(spec)
sys.modules["va"] = va
spec.loader.exec_module(va)
HEADING = re.compile(r"^(#{1,6})\s")


def section(path, anchor):
    """Lines from the anchored heading to the next heading of its level or higher (fence-aware)."""
    lines = Path(path).read_text().splitlines()
    start = va.anchor_lines("\n".join(lines))[anchor]
    level = len(HEADING.match(lines[start]).group(1))
    fence = False
    for i in range(start + 1, len(lines)):
        if lines[i].strip().startswith(("```", "~~~")):
            fence = not fence
        elif not fence and (m := HEADING.match(lines[i])) and len(m.group(1)) <= level:
            return i - start
    return len(lines) - start


def whole(path):
    return len(Path(path).read_text().splitlines())


def yaml_blocks(pattern):
    """lifecycle.yaml lines of every `- id:` rule block, const, lane, stage or question list whose head matches."""
    lines = Path("framework/spec-workflows/lifecycle.yaml").read_text().splitlines()
    total, i = 0, 0
    while i < len(lines):
        if re.search(pattern, lines[i]):
            indent = len(lines[i]) - len(lines[i].lstrip(" "))
            j = i + 1
            while j < len(lines) and lines[j].strip() and (len(lines[j]) - len(lines[j].lstrip(" "))) > indent:
                j += 1
            total += j - i
            i = j
        else:
            i += 1
    return total


def template_comment(path):
    text = Path(path).read_text()
    m = re.search(r"<!--\nTrivial-lane shortcut.*?-->", text, re.S)
    return m.group(0).count("\n") + 1 if m else 0


def function(path, name, consts=()):
    lines = Path(path).read_text().splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith(f"def {name}("))
    end = next((i for i in range(start + 1, len(lines)) if lines[i] and not lines[i][0].isspace() and lines[i][0] not in ")#"), len(lines))
    return end - start + sum(1 for l in lines if any(l.startswith(c) for c in consts))


def keyword_lines(paths, pattern):
    return sum(1 for p in paths for l in Path(p).read_text().splitlines() if re.search(pattern, l))


L, G, T = "framework/spec-workflows/spec-lifecycle.md", "docs/spec-workflow-guide.md", "docs/spec-templates-guide.md"
TESTS = ["scripts/test/validate-specs.test.sh", "scripts/test/lifecycle-mutations.test.sh", "scripts/test/spec-next.test.sh"]
LANES = {
    "RES": {
        "prose": [section(L, "res-exception"), section(G, "res-lane-iterative-research--spike--poc"),
                  section(T, "res-only-front-matter-fields"), section(T, "-iteration-log-section-res-only"),
                  section("framework/skills/writing-specs/references/authoring-steps.md", "d-research-authoring-res")],
        "prompt+questions+template": [whole("framework/prompts/research-spec.prompt.md"),
                                      whole("framework/spec-workflows/questions/res-questions.md"),
                                      whole("framework/spec-workflows/templates/RES-TEMPLATE.md")],
        "lifecycle.yaml": [yaml_blocks(r"^  - id: res_|^  kill_criteria_shapes:|^  res_outcomes:|^  research:|^    research:|^  RES: \{ref")],
        "plug-in code": [0],
        "tests (keyword lines)": [keyword_lines(TESTS, r"\bRES\b|res_|research")],
    },
    "Trivial": {
        "prose": [section(L, "trivial-lane"), section(G, "trivial-lane-when-3-gates-is-overkill"),
                  section("framework/spec-workflows/spec-types.md", "trivial-lane-applicable-to-cr--bug--imp")],
        "prompt+questions+template": [whole("framework/spec-workflows/questions/trivial-questions.md")]
        + [template_comment(f"framework/spec-workflows/templates/{t}-TEMPLATE.md") for t in ("CR", "IMP", "BUG")],
        "lifecycle.yaml": [yaml_blocks(r"^  - id: trivial_|^  trivial_fix:|^  trivial_forbidden_markers:|^  trivial:|^    trivial:|^  trivial: \{ref")],
        "plug-in code": [0],
        "tests (keyword lines)": [keyword_lines(TESTS, r"[Tt]rivial")],
    },
    "Direct": {
        "prose": [section(L, "direct-lane"), section(G, "direct-lane-when-even-one-gate-is-overkill"),
                  keyword_lines(["docs/improvements-log-format.md"], r"Direct|Closed")],
        "prompt+questions+template": [0],
        "lifecycle.yaml": [yaml_blocks(r"check_log_closed")],
        "plug-in code": [function("scripts/validate-specs.py", "check_log_closed", ("_LOG_",))],
        "tests (keyword lines)": [keyword_lines(TESTS, r"log_closed|Direct lane|Closed:")],
    },
}
cols = list(next(iter(LANES.values())))
print("| Lane | " + " | ".join(cols) + " | Total |")
print("|---|" + "---|" * (len(cols) + 1))
for lane, parts in LANES.items():
    sums = [sum(v) for v in parts.values()]
    print(f"| {lane} | " + " | ".join(map(str, sums)) + f" | {sum(sums)} |")
    if "--detail" in sys.argv:
        print("  ", {k: v for k, v in parts.items()})
```

Per use: RES 262 lines per spec, Trivial 328, Direct 15 per entry.

## RES-20260914 as input (FR-6)

- **Shape.** Hypothesis with a numeric bar (≥15 of 22 checks), an 8-hour time-box, sandbox at
  `research/RES-20260914-declarative-lifecycle-schema/`, outside every repo.
- **Run.** ≈5 of 8 hours, no backflip, `## Iteration Log` empty. Closed `confirmed` on 2026-09-17.
- **Yield.** Parity harness and 89 mutation fixtures (ported by `IMP-20260917-lifecycle-schema-engine`), 7 prose↔code
  mismatches (all fixed there), and the schema that `IMP-20260914-spec-next-instructions` built on — two IMPs closed
  the same day.
- **What the lane mechanics did.** The sandbox kept a 1 300-line prototype out of `scripts/` until parity was proven;
  the time-box and the numeric hypothesis made `confirmed` a measurement, not an opinion; `outcome:` named the
  follow-ups. The iterative loop — the lane's defining feature — was not used.
- **Explore overlap.** The question needed running code (a parity harness over 185 findings), so it was a RES by
  `explore.prompt.md`'s own rule; explore absorbs the no-code part of what RES was built for.

## Decisions (FR-4, T4 — owner, 2026-09-17)

| Lane | Decision | Reasons | Recorded |
|---|---|---|---|
| RES | keep | The only lane for questions that need running code; its one real use paid for itself the same day; `explore.prompt.md` now takes the no-code part | `spec-lifecycle.md § RES exception` |
| Trivial | remove | One use in 160 specs, highest footprint per use; Direct covers the small end, the standard track the rest | `spec-lifecycle.md § Trivial lane`, `spec-types.md`; carried out by `IMP-20260917-remove-trivial-lane` (FR-5 → its FR-2 / AC-1) |
| Direct | keep | Most used, cheapest per use | `spec-lifecycle.md § Direct lane` |

Nothing is removed by this spec (OS-1).
