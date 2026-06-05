# Trivial-lane Closure Evidence

*Captured: 2026-05-14*
*Spec: IMP-20260514-trivial-lane — Task T5*

Closure artifact for the trivial-lane IMP. Two AC's worth of evidence:
**AC-8** (no retroactive reclassification — mechanical grep) and **AC-9**
(end-to-end dry-run with gate-time estimates).

---

## AC-8 — No retroactive reclassification

Grep run against `docs/specs/archived/` at HEAD on 2026-05-14:

```
$ ls docs/specs/archived/*.md | wc -l
12

$ grep -l '^risk: trivial' docs/specs/archived/*.md | wc -l
0

$ grep -l '^severity: trivial' docs/specs/archived/*.md | wc -l
0
```

Full `risk:` / `severity:` inventory of the ai-dotfiles archive at HEAD:

| Archived spec | risk |
|---|---|
| IMP-20260513-compress-boundaries | medium |
| IMP-20260513-makefile-script-targets | low |
| IMP-20260513-slim-framework-prompts | low |
| IMP-20260513-slim-project-templates | low |
| IMP-20260513-slim-skill-bodies | low |
| IMP-20260513-slim-spec-templates | low |
| IMP-20260513-slim-spec-workflows | low |
| IMP-20260513-slim-system-templates | low |
| IMP-20260513-slim-workspace-templates | low |
| IMP-20260514-dedup-rule-statements | medium |
| IMP-20260514-framework-subagents | high |
| IMP-20260514-spec-validator | low |

Distribution: 8 low, 3 medium, 1 high, **0 trivial**. ✅ AC-8 passes.

Cross-checked against the workspace-root archive at
`/Users/alex/vcs/geeoz/tobevisit/docs/specs/archived/` — also 0 trivial.
The "no retroactive reclassification" invariant holds across both
archives.

---

## AC-9 — End-to-end dry-run

### Scope of measurement (honest framing)

This walk-through is a **structural dry-run**, not a live human-reviewed
session. I cannot measure real human gate-review wall-clock from inside
an agent session; the gates' minutes are **estimates** based on
artifact complexity and reasonable reviewer pace. The artifact itself
is real (committed in the spec body) so future reviewers can
re-measure against actual humans.

Methodology for the estimates:
- Standard-track baseline (3 gates × ~10 min/gate = ~30 min) is the
  pre-existing framework convention used in the trivial-lane spec's
  `## Cost Estimate` row and in the worked example.
- Trivial-lane estimate: time to read each artifact section + answer
  3 yes/no eligibility questions + verify one AC.

If real human wall-clock measurement diverges by ≥50%, log a
follow-up IMP to refine the timing estimate.

### Scenario

Hypothetical one-character typo fix in `docs/spec-format.md` line 9:
"Quik reference" → "Quick reference". Identical to the worked
example in `docs/spec-workflow-guide.md § Trivial lane`.

### Spec file (would land at)

`docs/specs/active/CR-20260520-fix-spec-format-typo.md`

Body shown in `docs/spec-workflow-guide.md § Trivial lane § Worked
example`. Front-matter elects `risk: trivial`; 1 affected-doc;
1 FR; 1 AC; 1 task row.

### Gate 1 — Combined `specify+plan`

**Author work:**
1. Open template `CR-TEMPLATE.md` → see Trivial-lane shortcut block in source.
2. Verify eligibility against the 3 questions in `trivial-questions.md`:
   - Scope ≤ 2 files? Yes (1 file).
   - No schema / boundary / prompt change? Yes (doc-only).
   - One AC sufficient? Yes.
3. Fill front-matter + body per the worked example. (~3 min author time.)

**Reviewer work at gate:**
- Read 1-line Goal + 1-line Problem Statement: ~30 sec.
- Read 1 FR + 1 AC (Given/When/Then): ~1 min.
- Read 1 Task row: ~30 sec.
- Verify eligibility (validator already ran in CI; reviewer spot-checks): ~30 sec.
- Approval decision: ~30 sec.

**Estimated gate-1 wall-clock: ~3 min.**

For comparison, standard-track Specify gate alone is ~10 min: 10-question round, full Summary/Cost Estimate/Problem Statement/Requirements/AC review, plus the separate Plan gate for the task table.

### In-progress (work execution)

One `Edit` call replacing "Quik" with "Quick" at line 9. ~30 sec.
`make validate-specs` runs green.

### Gate 2 — Closure

**Author work:**
- Run AC-1's command: `head -9 docs/spec-format.md | tail -1`.
- Capture output: "Quick reference for spec sections..."
- Update spec's `Closure Evidence` with the output line.

**Reviewer work at gate:**
- Read AC-1 evidence (one terminal line): ~15 sec.
- Verify no regression / no scope creep (1-file spec → 1-file change): ~30 sec.
- Approval decision + click archive: ~30 sec.

**Estimated gate-2 wall-clock: ~2 min.**

For comparison, standard-track Closure gate alone is ~10 min: full AC-table evidence walk, baseline diff, cross-AC sanity check.

### Aggregate estimate

| Stage | Trivial-lane | Standard-track | Reduction |
|---|---:|---:|---:|
| Specify gate | merged | ~10 min | — |
| Plan gate | merged | ~10 min | — |
| Combined specify+plan | ~3 min | (sum: ~20 min) | **−85%** at this stage |
| Closure gate | ~2 min | ~10 min | **−80%** |
| **Total** | **~5 min** | **~30 min** | **~83%** |

The actual spec body specs ≤10 min as the target. **Estimate of ~5 min comfortably under target.** AC-9's "≥66% reduction" threshold: confirmed (~83% measured-by-estimate). ✅

### Sources of estimation error

1. **Reviewer variance.** A diligent reviewer might take 4-5 min on the
   combined gate to spot-check that "no boundaries change" is actually
   true; a faster reviewer might trust the validator and clear in 90 sec.
   Range: ~2-6 min.
2. **Author familiarity.** First-time use of the lane → +2 min to read
   the shortcut block and consult `trivial-questions.md`. Steady-state
   use → no overhead.
3. **Validator latency.** `make validate-specs` runs in ~0.06 sec per
   `tests/backtest-baseline.md`. Not a meaningful contributor to
   wall-clock.

Even at the pessimistic end of these ranges (6 min + 1 min author
overhead + 3 min closure = 10 min total), the lane stays at-or-under
the ≤10 min target and ≥66% reduction.

### Tripwire — does NOT fire

- "Eligibility criteria cannot be encoded as a hard rule (subjective)"
  — does not fire; T4 validator mechanically enforces 5 of 7 rules
  with no judgment calls.
- "Combined-gate format ends up longer than current 2-gate flow"
  — does not fire; estimate is ~5 min for 2 gates vs. ~20 min for
  the standard 2 Specify-track gates (Specify + Plan).

---

## Acceptance Criteria coverage

| AC | FR | Evidence | ✅ |
|---|---|---|---|
| AC-1 — Front-matter accepts trivial | FR-1 | T1 edits to spec-lifecycle.md § Front-matter schema; T4 enum extension in validator | ✓ |
| AC-2 — Trivial lane section defined | FR-2 | T1 added `## Trivial lane` to spec-lifecycle.md with anchor `#trivial-lane` | ✓ |
| AC-3 — Templates carry shortcut block | FR-3 | T2 added HTML comment to CR / BUG / IMP templates | ✓ |
| AC-4 — Trivial question list (exactly 3) | FR-4 | T2 created `questions/trivial-questions.md` with exactly 3 numbered Qs | ✓ |
| AC-5 — Validator eligibility | FR-5 | T4 added `check_trivial_lane_eligibility` with 5 fixture-verified failure modes | ✓ |
| AC-6 — Boundary rule clarified | FR-6 | T3 appended Trivial-lane clarification to boundaries § Never do #2; anchor preserved; lint stays green | ✓ |
| AC-7 — Worked example | FR-7 | T3 added complete worked example to `docs/spec-workflow-guide.md § Trivial lane` | ✓ |
| AC-8 — No retroactive reclassification | FR-8 | T5 grep above: 0 archived specs with `trivial` in either archive | ✓ |
| AC-9 — Measurable benefit | FR-2 + measurable-benefit clause | T5 estimate: ~5 min total vs. ~30 min standard = ~83% reduction; ≥66% target met | ✓ |

---

## Closure-readiness checklist

- [x] All 9 ACs have evidence
- [x] Rule counts preserved (14/5/9 in boundaries; 13 top-level in spec-lifecycle § Rules; 4 new sub-rules correctly scoped to § Trivial lane)
- [x] No rule's semantic intent changed
- [x] `make sync-agents-check` green
- [x] `tests/trivial-lane-closure-evidence.md` (this file) committed
- [x] `tests/backtest-baseline.md` (from spec-validator) still green

Ready for closure gate.
