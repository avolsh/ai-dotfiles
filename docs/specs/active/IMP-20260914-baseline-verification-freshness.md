---
id: IMP-20260914-baseline-verification-freshness
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
  - tobevisit-content
affected-docs:
  - framework/spec-workflows/spec-lifecycle.md
  - docs/baseline-citations.md
  - docs/agent-protocol.md
affected-code:
  - scripts/validate-specs.py
  - scripts/test/validate-specs.test.sh
skills:
  - writing-specs
  - test-driven-development
model-suggestion: default
siblings:
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-responsive-behaviour-and-design-first-figma
  - IMP-20260914-spec-traceability-checks
---

# IMP-20260914-baseline-verification-freshness

*Last updated: 2026-09-14*

## Summary

- **Goal:** Make the `Last src verified` obligation of Rule 13 mechanically checked, so a closing spec cannot update
  a baseline's body and leave its verification date behind.
- **Scope:** A validator check comparing each baseline's `Last src verified` date with the closure date of the
  newest archived spec naming it; a declared `closed:` front-matter field so that date is read, not inferred.
- **Out of scope:** Repairing the current drift — `tobevisit-content` `BUG-20260914-baseline-last-verified-stale`.

## Current State

Rule 13 requires the bump at closure. In `tobevisit-content` **13 of 21** baselines carry a date older than the
newest archived spec that lists them in `affected-docs` (comparison run 2026-09-14). The project's
`verify-baselines.sh` checks the row exists; `validate-specs.py` checks only duplicate REQ-IDs. Closure dates have
no field: the comparison had to fall back from a `*Closed*` body line to the `*Last updated:*` stamp, which can
postdate closure — so today the check could only be written as a heuristic.

## Proposed Improvement

Record closure as data, then compare. Measurable benefit: stale-baseline count is reported by `make validate-specs`
in any project with `docs/domain/`, and stays at zero after the BUG closes.

## Requirements

- FR-1: The front-matter schema MUST gain `closed: YYYY-MM-DD`, required at `status: done` for specs dated after this
  IMP's closure and optional before it.
- FR-2: For each baseline under the project's `docs/domain/`, the validator MUST report a `Last src verified` date
  older than the closure date of the newest archived spec listing that baseline in `affected-docs`.
- FR-3: Where a spec has no `closed:`, the check MUST fall back to its `*Closed YYYY-MM-DD*` line, then to its
  `*Last updated:*` stamp, and name the fallback used in the finding.
- FR-4: A finding MUST name the baseline, its row date, the spec ID and the closure date.
- FR-5: A baseline with no `Last src verified` row MUST be reported.
- FR-6: The check MUST be a no-op in a corpus without `docs/domain/`.
- FR-7: Rule 13 MUST name the check as its enforcement instead of restating the obligation.

## Acceptance Criteria

### AC-1: A stale baseline is reported with its cause (FR-2, FR-4)

Given a fixture project with a baseline verified 2026-08-01 and an archived spec with `closed: 2026-08-10` naming it
When the validator runs on the project
Then one finding names the baseline, 2026-08-01, the spec ID and 2026-08-10; bumping the row clears it
Evidence: `validate-specs.test.sh` fixture

### AC-2: Closure date is read in declared order (FR-1, FR-3)

Given three archived specs — one with `closed:`, one with only `*Closed*`, one with only `*Last updated:*`
When the validator runs
Then each finding names the source of the date it used, and a post-cut-off `done` spec without `closed:` is reported
Evidence: `validate-specs.test.sh` fixtures

### AC-3: Missing row and absent corpus (FR-5, FR-6)

Given a baseline with no `Last src verified` row, and separately a corpus with no `docs/domain/`
When the validator runs
Then the first produces one finding and the second none
Evidence: `validate-specs.test.sh` fixtures

### AC-4: The live corpus is green after the repair (FR-2, FR-7)

Given `tobevisit-content` after `BUG-20260914-baseline-last-verified-stale` closes
When `make validate-specs` runs there
Then no `baseline_stale` finding is raised, and Rule 13 links the check
Evidence: command output + `spec-lifecycle.md` diff

## Design

Pending — Visualize sub-step (adds a front-matter field to the spec schema).

## Out of Scope

- OS-1: Checking that the baseline body matches source — only a person or an agent reading source can.
- OS-2: Verification scenarios per REQ — `IMP-20260914-baseline-deltas-and-merge`.
- OS-3: Back-filling `closed:` into archived specs — history is not rewritten; FR-3 covers them.

## Open Questions

- Q1: Should `closed:` also be required on the Direct-lane improvements-log entry format, for symmetry?

## Split Decision

**Kept as one — E4.** FR-1 (the field) is a ≤1-FR extension whose only consumer is FR-2; FR-5 is the same parse.
T3 fires on `affected-repos` by the letter, but every changed file is in ai-dotfiles — `tobevisit-content` is
listed because its corpus is where AC-4 is observed, not where code changes. T2 `unknown`.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `framework/spec-workflows/spec-lifecycle.md` — schema gains `closed:`; Rule 13 names the check.
- `docs/baseline-citations.md` — `Last src verified` row: checked, and against what.
- `docs/agent-protocol.md` — post-task checklist: the baseline item names the bump explicitly.

## Rollout / migration notes

- Cross-repo order: `tobevisit-content` `BUG-20260914-baseline-last-verified-stale` closes first, otherwise
  AC-4 ships red. The dependency is stated here because `depends-on:` cannot resolve across corpora.
- Shares `scripts/validate-specs.py` with `IMP-20260914-mandatory-review-for-high-risk`; implement after it.
