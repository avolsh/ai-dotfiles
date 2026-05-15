# Research-lane Closure Evidence

*Captured: 2026-05-14*
*Spec: IMP-20260514-research-lane — Task R6*

End-to-end dry-run of the RES lane on a real (in-session-runnable)
research question. Walks the full `specify → in-progress → specify →
in-progress → specify → in-progress → done` lifecycle with 2 backflips,
recording each in the spec's `## Iteration Log`. Verifies validator +
lint exit zero at every transition.

---

## Research question (real, picked at R6 start)

> *How many of the 12 ai-dotfiles archived specs would have qualified
> for `risk: trivial` had the Trivial lane existed at their Specify-time?*

Hypothesis: *"At most 3 of the 12 archived specs would have qualified —
the Trivial lane is primarily forward-looking, not a retroactive
explanation of past work."*

Kill criteria: `≤3 backflips`

Code location: `research/RES-20260520-trivial-lane-applicability/`
(documented in the spec; sandbox dir not actually created since the
analysis ran in-process via grep)

Deliverable: a memo in the spec body + outcome value.

---

## RES spec created

`docs/specs/archived/RES-20260520-trivial-lane-applicability.md` (moved
from `docs/specs/active/` at the closure gate). Front-matter at archive
time:

```yaml
type: RES
status: done
hypothesis: At most 3 of the 12 ai-dotfiles archived specs would have qualified for `risk: trivial` at their Specify-time — the Trivial lane is primarily forward-looking, not a retroactive explanation of past work.
kill-criteria: ≤3 backflips
code-location: research/RES-20260520-trivial-lane-applicability/
outcome: confirmed
```

All 4 RES-only fields populated; outcome filled at `done`; sandbox path
outside `src/`; kill-criteria matches single shape (`iteration-count`).

## Lifecycle walk-through (the actual flips)

| # | Transition | `make validate-specs` result | Notes |
|---|---|---|---|
| 1 | initial state: `status: specify`, outcome blank | OK | Validator green with newly-added affected-docs/affected-code fields |
| 2 | `specify → in-progress` (iteration 1) | OK | First analysis pass starts |
| 3 | `in-progress → specify` (**BACKFLIP 1**) | OK | Iteration Log row 1 added BEFORE backflip; row recorded "Initial scan returned 1 candidate from front-matter alone; affected-code + affected-docs counts not visible without parsing the spec bodies." → refined to parse bodies |
| 4 | `specify → in-progress` (iteration 2) | OK | Second analysis pass starts with refined approach |
| 5 | `in-progress → specify` (**BACKFLIP 2**) | OK | Iteration Log row 2 added; row recorded "After parsing all 12: 3 specs have ≤2 affected files, but checking forbidden paths is what truly disqualifies them." → refined to apply ALL 7 criteria mechanically |
| 6 | `specify → in-progress` (final iteration) | OK | Decision filled, outcome set to `confirmed` |
| 7 | `in-progress → done` (file still in active/) | red — `status_location` finding fires as designed | Validator catches the missing move |
| 8 | move file `active/ → archived/` | OK | All-green |

Result: **2 backflips, 3 in-progress phases, 1 done — exactly the loop
the lane is designed for.** Final hypothesis confirmed (1 spec
retroactively qualifies, well within "at most 3" prediction).

## Iteration Log content (verbatim from the RES spec)

```
| # | Date | Cause | Decision |
|---|---|---|---|
| 1 | 2026-05-20 | Initial scan returned 1 candidate from front-matter alone; affected-code + affected-docs counts not visible without parsing the spec bodies. | Refine: read both fields, count combined; reject candidates where actual file totals exceed 2 even if front-matter looks small. |
| 2 | 2026-05-20 | After parsing all 12: 3 specs have ≤2 affected files, but checking forbidden paths (boundaries / prompts / lifecycle / baselines) is what truly disqualifies them. | Refine: apply ALL 7 criteria mechanically; don't stop at file-count. Final count = candidates that pass every check. |
```

Both rows have date + cause + decision per AC-9. Recorded BEFORE each
backflip per spec-lifecycle.md § RES exception Rule #2.

## Decision (verbatim from the RES spec)

> After 2 backflips with progressively stricter mechanical application
> of the 7 trivial-lane criteria, the final count is **1 archived
> spec** that would have qualified — `IMP-20260513-makefile-script-targets`.
> The other 11 specs fail eligibility for file-count >2, forbidden
> paths, or schema/template changes. Result is within the hypothesis
> prediction (1 ≤ 3).

## Outcome

`confirmed` — hypothesis validated. No promoted-to sibling needed; the
finding is purely informational (forward-looking calibration). The
Trivial lane genuinely is a forward-looking simplification; the existing
ai-dotfiles archive is deliberately non-trivial work.

---

## 🎯 Bug caught by R6 (the integration test's real value)

R6's first run failed because the RES-TEMPLATE.md I authored in R2 was
**missing `affected-docs:` and `affected-code:` fields**. The validator's
`check_front_matter_schema` requires both fields universally for all
spec types, but I omitted them from RES on the assumption that RES specs
typically don't modify code or docs outside their sandbox.

R4's fixtures always populated these fields (the test scaffolding
included them by default), so the gap wasn't caught by unit-style
testing.

**This is exactly the value of the end-to-end dry-run.** R6's first
status-flip failed with:

```
docs/specs/active/RES-20260520-trivial-lane-applicability.md:16:schema_missing_field:required field 'affected-code' missing
```

**Fix applied in R6 (mid-task):**
- Added `affected-docs: []` and `affected-code: []` to RES-TEMPLATE.md
  (with comments explaining they're typically empty for RES)
- Added the same fields to my dry-run RES spec
- All subsequent lifecycle flips passed

This is logged as a real bug found by integration testing — sibling
unit-style fixtures (R4) missed it because they always included the
fields. R5 docs (RES front-matter constraints) implicitly assumed the
fields existed without saying so explicitly; that note should be added
in a follow-up cleanup.

## Tripwire status — none fired

| Tripwire | Status |
|---|---|
| "Iterative loop semantics cannot be made deterministic for the validator" | Did not fire — validator green at every transition through the loop |
| "Kill-criteria mechanism is unenforceable" | Did not fire — `≤3 backflips` correctly matched the `iteration-count` shape; mixed-shape and unknown-shape fixtures all caught in R4 |
| "research/<spec-id>/ sandbox conflicts with existing workspace research/" | Did not fire — sandbox path lives at `research/RES-20260520-...`, no collision with workspace-root `research/` directory |

---

## Acceptance Criteria coverage (all 10 ACs)

| AC | FR | Evidence | ✅ |
|---|---|---|---|
| AC-1 — RES type marked implemented in spec-types.md | FR-1 | R1: removed `*(future)*`, populated columns with forward refs to R2 artifacts | ✓ |
| AC-2 — RES template has 6 required H2 sections in order | FR-2 | R2: `RES-TEMPLATE.md` H2 order: Summary → Hypothesis → Kill Criteria → Iteration Log → Decision → Outcome (verified by grep) | ✓ |
| AC-3 — Exactly 5 questions in res-questions.md | FR-3 | R2: `res-questions.md` numbered Q count = 5 (verified by `grep -c`) | ✓ |
| AC-4 — research-spec.prompt.md exists + delegates | FR-4 | R3: `framework/prompts/research-spec.prompt.md` (29 lines) delegates Step 3 to spec-author research mode + fallback note | ✓ |
| AC-5 — Lifecycle exception documented | FR-5 | R1: `spec-lifecycle.md § RES exception` (~50 lines) with `#res-exception` anchor; inline prose amended to except RES | ✓ |
| AC-6 — Boundary rule clarified | FR-6 | R1: status-revisit rule (canonical home: `spec-lifecycle.md`, not `boundaries.md`) amended to except RES. AC-6's "boundary rule" wording was Specify-time imprecise; rule's true canonical home is spec-lifecycle. Functionally satisfied. | ⚠ (wording mismatch documented; semantic intent met) |
| AC-7 — Validator enforces 4 RES checks | FR-7, FR-8, FR-9 | R4: `check_res_eligibility` with 6 fixture-verified failure modes (hypothesis empty / kill-criteria mixed / kill-criteria unknown shape / code-location in src/ / outcome invalid / outcome dangling promotion); valid spec passes | ✓ |
| AC-8 — .gitignore covers transient artifacts | FR-10 | R4: `research/*/.tmp/` and `research/**/.tmp/` rules added to `.gitignore` | ✓ |
| AC-9 — End-to-end dry-run with ≥2 backflips | FR-11 | R6 (this artifact): 2 backflips executed; Iteration Log entries verbatim above; outcome `confirmed`; full walk-through recorded | ✓ |
| AC-10 — Sibling validators stay green | FR-12 | Final `make sync-agents-check` → `validate-specs: OK (15 spec(s); 4 agent(s); 11 check(s))` + `lint-rules: OK (8 canonical rule(s) + 4 agent(s); 28 phrase(s))` | ✓ |

---

## Closure-readiness checklist

- [x] All 10 ACs have evidence (AC-6 with documented wording-vs-reality note)
- [x] Rule counts preserved (boundaries 14/5/9; spec-lifecycle top-level Rules 13; new sub-rules correctly scoped to `## RES exception` and `## Trivial lane`)
- [x] No rule's semantic intent changed; existing rules' anchors preserved
- [x] `make sync-agents-check` green
- [x] `tests/research-lane-closure-evidence.md` (this file) committed
- [x] Dry-run RES spec archived (`docs/specs/archived/RES-20260520-trivial-lane-applicability.md`)
- [x] RES-TEMPLATE.md bug fixed mid-R6 (now includes affected-docs/affected-code fields)

Ready for closure gate.
