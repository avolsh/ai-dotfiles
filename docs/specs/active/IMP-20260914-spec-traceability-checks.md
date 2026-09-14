---
id: IMP-20260914-spec-traceability-checks
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/writing-specs.md
  - docs/acceptance-criteria-patterns.md
affected-code:
  - scripts/validate-specs.py
  - scripts/test/validate-specs.test.sh
skills:
  - writing-specs
  - test-driven-development
model-suggestion: default
siblings:
  - IMP-20260914-responsive-behaviour-and-design-first-figma
---

# IMP-20260914-spec-traceability-checks

*Last updated: 2026-09-14*

## Summary

- **Goal:** Make the FR → AC → Task → Closure Evidence chain a validated property of every new spec, not a
  convention a reader has to re-derive.
- **Scope:** Four checks in `validate-specs.py` over the sections every CR / IMP / BUG already carries, plus the
  authoring docs naming them.
- **Out of scope:** Judging whether an AC actually tests its FR — that stays the reviewer's Coverage dimension.

## Current State

The check registry holds 13 corpus checks plus the agent and REQ-ID checks; none reads the relations between
requirements, criteria, tasks and evidence, although specs write them explicitly (`### AC-1: … (FR-1)`,
`FR-4 → AC-2` in task rows). Over the 69 archived `tobevisit-content` specs that define FRs, a heuristic scan
(IDs and `FR-a – FR-b` ranges inside the AC section) found **13 specs with an FR no AC cites** and **2 whose ACs
cite an FR that does not exist**. Example: `CR-20260831-geo-availability-flag` — FR-1 and FR-3 are cited by no AC
block, while its closure table reads complete.

## Proposed Improvement

Four mechanical checks that fire at the status where the relation first has to exist. Measurable benefit: the
two counts above go to zero for specs dated on or after this IMP's closure; the heuristic becomes the check.

## Requirements

- FR-1: The validator MUST report every FR defined under `## Requirements` that no block under
  `## Acceptance Criteria` (BUG: `## Fix Criteria`) cites, counting single IDs and `FR-a – FR-b` ranges.
- FR-2: The validator MUST report an acceptance block that cites an FR ID the spec does not define.
- FR-3: At `status: plan`, `in-progress` or `done`, the validator MUST report an FR that no `## Tasks` row cites.
- FR-4: At `status: done`, the validator MUST report an AC ID with no row in the Closure Evidence table.
- FR-5: The checks MUST NOT judge specs whose `date:` precedes this IMP's closure date — history is not rewritten,
  the same terms the deprecated `draft` status is kept on.
- FR-6: RES specs are exempt (no FR/AC contract); Trivial-lane specs are judged like any other.

## Acceptance Criteria

### AC-1: An uncited FR is named (FR-1, FR-6)

Given a fixture CR defining FR-1 – FR-3 whose ACs cite `FR-1` and `FR-2`
When the validator runs
Then exactly one finding names FR-3 with the line it is defined on; a variant citing `(FR-1 – FR-3)` produces none;
a RES fixture produces none
Evidence: `validate-specs.test.sh` fixtures

### AC-2: A dangling citation is named (FR-2)

Given a fixture whose AC cites `FR-9` and defines FR-1 – FR-3
When the validator runs
Then one finding names `FR-9` at the AC's line
Evidence: `validate-specs.test.sh` fixture

### AC-3: Task and closure coverage follow status (FR-3, FR-4)

Given one fixture at `plan` whose Tasks omit FR-2, and one at `done` whose Closure Evidence omits AC-2
When the validator runs
Then each produces one finding naming the missing ID, and the same bodies at `specify` produce none
Evidence: `validate-specs.test.sh` fixtures

### AC-4: History is not judged (FR-5)

Given the live `tobevisit-content` corpus
When the validator runs with the new checks registered
Then no finding is raised against any spec dated before the cut-off
Evidence: `make validate-specs` in both corpora, finding counts before and after

## Design

Skipped — checks over sections that already exist; no format or data-flow change.

## Out of Scope

- OS-1: Semantic coverage (does the AC exercise the FR) — reviewer Coverage dimension.
- OS-2: Detecting unmarked observation-shaped criteria — needs judgement of the `When` clause, not a pattern.
- OS-3: Repairing the 13 archived specs — archived history is not rewritten.
- OS-4: A warning severity level — the validator has one severity today; introducing another is its own change.

## Open Questions

- Q1: Cut-off for FR-5 — this IMP's closure date, or its `date:`?
- Q2: Should FR-3 accept an FR cited only by an AC that a task cites (transitive), or require a direct citation?

## Split Decision

**Human decision needed at the gate.** T1 fires: FR-1/FR-2, FR-3 and FR-4 are each testable without the others.
No E1–E5 exception applies cleanly — the closest is shared surface (one file, one test harness), which is not an
exception in `splitting-rules.md § 4`. Recommendation: keep as one by election — four small checks over one parser,
split would triple the fixture scaffolding for ≤60 lines of check code each. T2 `unknown` (no module map in
ai-dotfiles); T3–T6 do not fire.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `docs/writing-specs.md` — self-review additions name the four checks.
- `docs/acceptance-criteria-patterns.md` — range citation form `FR-a – FR-b` stated as the recognised form.

## Rollout / migration notes

- First of the 2026-09-14 framework batch; `IMP-20260914-mandatory-review-for-high-risk` reuses its Closure
  Evidence parser.
