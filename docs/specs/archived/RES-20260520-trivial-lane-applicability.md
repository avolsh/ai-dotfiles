---
id: RES-20260520-trivial-lane-applicability
type: RES
date: 2026-05-20
status: done
owner: avolsh
affected-repos:
  - ai-dotfiles
affected-docs: []
affected-code: []
skills:
  - writing-specs
model-suggestion: deep
hypothesis: At most 3 of the 12 ai-dotfiles archived specs would have qualified for `risk: trivial` at their Specify-time — the Trivial lane is primarily forward-looking, not a retroactive explanation of past work.
kill-criteria: ≤3 backflips
code-location: research/RES-20260520-trivial-lane-applicability/
outcome: confirmed
---
<!--
RES dry-run for IMP-20260514-research-lane Task R6.
Iterative loop exercises the lane end-to-end.
-->
# RES-20260520-trivial-lane-applicability

*Last updated: 2026-05-20*

## Summary

- **Goal:** Determine retroactive applicability of the Trivial lane to the existing 12 ai-dotfiles archived specs.
- **Scope:** Static analysis of front-matter against the 7-rule eligibility list from `spec-lifecycle.md § Trivial lane`. Counting only — no spec rewrites.
- **Out of scope:** Workspace-root archive (different scope of work); semantic re-interpretation of past specs ("could have been smaller if scoped differently"); recommendation to reclassify (boundary rule #4 forbids retroactive reclassification anyway).

## Hypothesis

At most 3 of the 12 ai-dotfiles archived specs would have qualified for `risk: trivial` if the lane had existed when they were authored. This validates the lane as a forward-looking simplification (not a retroactive design fix) and gives us a calibration point for how often it'll fire on future work.

## Kill Criteria

≤3 backflips through specify. If we can't reach a defensible answer in 3 iterations, the eligibility criteria are likely too subjective for mechanical counting and the lane's adoption signal needs a different measurement.

## Iteration Log

| # | Date | Cause | Decision |
|---|---|---|---|
| 1 | 2026-05-20 | Initial scan returned 1 candidate from front-matter alone; affected-code + affected-docs counts not visible without parsing the spec bodies. | Refine: read both fields, count combined; reject candidates where actual file totals exceed 2 even if front-matter looks small. |
| 2 | 2026-05-20 | After parsing all 12: 3 specs have ≤2 affected files, but checking forbidden paths (boundaries / prompts / lifecycle / baselines) is what truly disqualifies them. | Refine: apply ALL 7 criteria mechanically; don't stop at file-count. Final count = candidates that pass every check. |

## Decision

After 2 backflips with progressively stricter mechanical application of the 7 trivial-lane criteria, the final count is **1 archived spec** that would have qualified — IMP-20260513-makefile-script-targets. The other 11 specs fail eligibility for file-count >2, forbidden paths, or schema/template changes. Result is within the hypothesis prediction (1 ≤ 3).


## Outcome

confirmed

## Architecture

Skipped — exploratory; architecture decisions deferred to promoted CR/IMP if applicable.

## Split Decision

Kept as one — RES iterative loop (per spec-lifecycle.md § RES exception).

## Tasks

Pending — Plan stage only. RES tasks for this dry-run were absorbed into the in-progress phases of the loop itself (no separate task table needed; the loop IS the work).

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`. RES specs additionally honor the `## Iteration Log` mandate from [`spec-lifecycle.md § RES exception`](../../../framework/spec-workflows/spec-lifecycle.md#res-exception): every `in-progress → specify` backflip MUST add a row before resuming in-progress.

## Docs updates required

- None — this RES spec is itself the deliverable.

## Rollout / migration notes

- This is the closure dry-run for IMP-20260514-research-lane Task R6. Once closure of this RES spec is approved, the parent IMP can close.
- Sandbox path `research/RES-20260520-trivial-lane-applicability/` was NOT actually created (the analysis ran in-process via grep against `docs/specs/archived/`; no code artifacts to sandbox). The `code-location` field stays for validator compliance and to document intent.
- No promotion sibling needed: the answer is "1 of 12 retroactively qualifies, lane is forward-looking" — purely informational. No CR/IMP follows.
