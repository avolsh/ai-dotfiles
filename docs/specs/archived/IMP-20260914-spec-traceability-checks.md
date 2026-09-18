---
id: IMP-20260914-spec-traceability-checks
type: IMP
date: 2026-09-14
status: done
owner: alexvolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/writing-specs.md
  - docs/acceptance-criteria-patterns.md
  - docs/improvements-log.md
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

*Last updated: 2026-09-15*

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
- FR-3: At `status: plan`, `in-progress` or `done`, the validator MUST report an FR that no `## Tasks` row cites
  directly — a task citing only an AC that cites the FR does not count.
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

- Q1: Cut-off for FR-5 — this IMP's closure date, or its `date:`? **Resolved (2026-09-15):** closure date; pinned in
  the validator at closure.
- Q2: Should FR-3 accept an FR cited only by an AC that a task cites (transitive), or require a direct citation?
  **Resolved (2026-09-15):** direct citation — FR-3 amended.

## Split Decision

**keep-as-one — elected by the human at the Specify gate (2026-09-15).** T1 fires: FR-1/FR-2, FR-3 and FR-4 are each testable without the others.
No E1–E5 exception applies cleanly — the closest is shared surface (one file, one test harness), which is not an
exception in `splitting-rules.md § 4`. Recommendation: keep as one by election — four small checks over one parser,
split would triple the fixture scaffolding for ≤60 lines of check code each. T2 `unknown` (no module map in
ai-dotfiles); T3–T6 do not fire.

## Tasks

> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Test-first: shared section reader (FR/AC definitions with lines; citations as single IDs and `FR-a – FR-b` ranges, en dash or hyphen; `## Fix Criteria` for BUG); applicability gate (RES exempt, `date:` before the cut-off constant exempt, Trivial lane judged); `check_fr_ac_coverage` (uncited FR, dangling FR citation) registered (FR-1, FR-2, FR-5, FR-6; AC-1, AC-2) | `scripts/validate-specs.py`, `scripts/test/validate-specs.test.sh` | `docs/acceptance-criteria-patterns.md`, `framework/spec-workflows/spec-lifecycle.md` | — | test-driven-development | default | ☑ done |
| T2 | Test-first: `check_fr_task_coverage` — at `plan` / `in-progress` / `done`, an FR no `## Tasks` row cites directly; `specify` silent (FR-3; AC-3 first half) | `scripts/validate-specs.py`, `scripts/test/validate-specs.test.sh` | — | T1 | test-driven-development | fast | ☑ done |
| T3 | Test-first: Closure Evidence table parser as a standalone helper (reused by `IMP-20260914-mandatory-review-for-high-risk`); `check_ac_closure_coverage` — at `done`, an AC ID with no row; earlier statuses silent (FR-4; AC-3 second half) | `scripts/validate-specs.py`, `scripts/test/validate-specs.test.sh` | `docs/specs/archived/IMP-20260914-responsive-behaviour-and-design-first-figma.md` | T1 | test-driven-development | default | ☑ done |
| T4 | Docs: self-review additions in `writing-specs.md` name the four checks and the cut-off; `acceptance-criteria-patterns.md` states `FR-a – FR-b` as the recognised range form; register any new rule sentence if `make lint-rules` flags it | `docs/writing-specs.md`, `docs/acceptance-criteria-patterns.md`, `docs/rule-canonical-map.md` | `scripts/lint-rules.py` | T2, T3 | writing-specs | fast | ☑ done |
| T5 | Verification: finding counts before/after in ai-dotfiles and `tobevisit-content` (`python3 scripts/validate-specs.py <path>`), zero new findings on pre-cut-off specs; pin the cut-off to the closure date; improvements-log entry; `make check` green (FR-5; AC-4) | `scripts/validate-specs.py`, `docs/improvements-log.md` | `../../src/github.com/tobeverse/tobevisit-content/docs/specs/` | T4 | test-driven-development | fast | ☑ done |

## Closure Evidence

Closed 2026-09-15, review-after (`risk: low`). Cut-off `_TRACEABILITY_CUTOFF = 2026-09-15`; no spec in either corpus is
dated on or after it, so the checks judge only specs written from here on.

| AC | Evidence |
|---|---|
| AC-1 | `validate-specs.test.sh`: `CR-20270101-uncited` yields exactly one `traceability_fr_uncited` at FR-3's defining line; the `(FR-1 – FR-3)` variant and the RES fixture yield none. Red before T1 (`no finding matching …traceability_fr_uncited…`), green after. |
| AC-2 | `CR-20270101-dangling` yields `traceability_fr_dangling` naming FR-9 at the `### AC-2` line. Red before T1, green after. |
| AC-3 | At `plan`, `CR-20270101-tasks` (T2 cites only AC-2) yields one `traceability_fr_no_task` naming FR-2; at `specify` none. At `done`, `CR-20270101-closure` yields one `traceability_ac_no_evidence` naming AC-2 (a `Review` row is read as a label, not an AC); at `specify` and `in-progress` none. Each red before its task, green after. |
| AC-4 | Registry without vs with the three new checks, `validate-specs.py <corpus>`: ai-dotfiles 0 → 0 findings (rc 0); `tobevisit-content` 7 → 7 (rc 1, all pre-existing: `domain_req_id_duplicate` ×2, `figma_frame_id` ×2, `link_broken`, `english_only`, `deps_dangling`), `traceability_*` 0. With the cut-off lowered to 2000-01-01 the checks do fire on that history: 13 specs with an uncited FR and 2 with a dangling citation — the Current State counts, `CR-20260831-geo-availability-flag` FR-1/FR-3 among them. `make check` exit 0. |

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `docs/writing-specs.md` — self-review additions name the four checks.
- `docs/acceptance-criteria-patterns.md` — range citation form `FR-a – FR-b` stated as the recognised form.

## Rollout / migration notes

- First of the 2026-09-14 framework batch; `IMP-20260914-mandatory-review-for-high-risk` reuses its Closure
  Evidence parser.
