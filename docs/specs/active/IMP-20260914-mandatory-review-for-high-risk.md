---
id: IMP-20260914-mandatory-review-for-high-risk
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/spec-lifecycle.md
  - framework/skills/reviewing-changes/SKILL.md
  - framework/agents/reviewer.md
  - docs/agent-protocol.md
  - docs/ai-agent-framework.md
affected-code:
  - scripts/validate-specs.py
  - scripts/test/validate-specs.test.sh
skills:
  - writing-specs
  - reviewing-changes
  - test-driven-development
model-suggestion: default
depends-on:
  - IMP-20260914-spec-traceability-checks
siblings:
  - IMP-20260914-responsive-behaviour-and-design-first-figma
---

# IMP-20260914-mandatory-review-for-high-risk

*Last updated: 2026-09-14*

## Summary

- **Goal:** Make the cold review a closure precondition for high-risk work, with every finding answered, so the
  human approves an explicit disposition rather than an absence of review.
- **Scope:** `risk: high` and `severity: high | critical` specs: reviewer run required before the closure gate, a
  `Review` row in Closure Evidence with a per-finding disposition, the gate summary format, and a validator check.
- **Out of scope:** Medium and low risk, which keep the recommended sub-step.

## Current State

`spec-lifecycle.md § Reviewer sub-step` makes the reviewer "recommended, non-blocking" for medium/high. In
`tobevisit-content` the word *reviewer* appears in **7 of 25** archived high-risk/severity specs and **4 of 51**
medium ones — an upper bound on runs, since a mention is not a run. Findings, when a run happens, are applied or
dropped in chat; nothing persisted records which were rejected and why, so the closure gate cannot see them.

## Proposed Improvement

Turn the sub-step into a precondition for the highest tier only, and persist its outcome where the closure gate
and later consolidation (`IMP-20260914-consolidation-checkpoint`) can read it. Measurable benefit: share of
high-tier specs closed with a recorded review goes from ≤28% to 100% for specs dated after closure.

Decided in chat on 2026-09-14: mandatory for high tier with per-finding disposition; medium stays recommended;
plan-stage cold review declined.

## Requirements

- FR-1: A spec with `risk: high` or `severity: high | critical` MUST NOT flip to `done` until the reviewer has run
  against the final diff of the change.
- FR-2: Closure Evidence MUST carry a `Review` row stating run date, diff reference, harness path (sub-agent or
  empty-context session), and result (`PASS` or finding count).
- FR-3: Every reviewer finding MUST carry a disposition — `applied` with the fixing `path:line`, or `rejected` with
  a one-line reason; a finding without one blocks closure.
- FR-4: The closure gate request MUST state findings N / applied M / rejected K and list each rejection reason.
- FR-5: The existing cap of two review cycles MUST remain; findings still open at the cap are dispositioned as
  `rejected` with reason, never left unrecorded.
- FR-6: The validator MUST report a high-tier spec at `done` with no `Review` row or with a finding lacking a
  disposition; specs dated before this IMP's closure are not judged.

## Acceptance Criteria

### AC-1: A high-tier closure without review is refused (FR-1, FR-2, FR-6)

Given a fixture CR with `risk: high` at `status: done` whose Closure Evidence has no `Review` row
When the validator runs
Then one finding names the missing row; the same fixture at `risk: medium` produces none
Evidence: `validate-specs.test.sh` fixtures

### AC-2: Every finding is answered (FR-3, FR-5, FR-6)

Given a high-tier fixture whose `Review` row lists three findings, one with no disposition
When the validator runs
Then one finding names the undispositioned entry; with all three dispositioned it produces none
Evidence: `validate-specs.test.sh` fixtures

### AC-3: The gate shows the disposition (FR-4)

Given the lifecycle and protocol docs after this change
When the closure-gate format is read
Then it requires the N / M / K counts and each rejection reason, and `reviewing-changes` points to the `Review` row
as where its output is recorded
Evidence: diff of `spec-lifecycle.md`, `agent-protocol.md`, `reviewing-changes/SKILL.md`

## Design

Pending — Visualize sub-step (changes the Closure Evidence contract of the spec format).

## Out of Scope

- OS-1: Mandatory review for medium risk — declined 2026-09-14 on cost.
- OS-2: Cold review of the plan before the plan gate — declined 2026-09-14.
- OS-3: Changing the reviewer checklist dimensions.
- OS-4: Running the reviewer automatically from a hook — a harness integration, not a lifecycle rule.

## Open Questions

- Q1: `Review` as one table row with an inline list, or a `### Review` sub-table under Closure Evidence?
- Q2: When a change spans several commits, is "final diff" the range from the spec's first task commit?

## Split Decision

**Human decision needed at the gate.** T1 fires: the rule (FR-1 – FR-5) is verifiable by doc diff without the check
(FR-6), and the check is testable on fixtures without the rule text. No E1–E5 exception applies. Recommendation:
keep as one by election — the evidence above is precisely that the rule without a check is not followed, so
shipping the rule alone reproduces the current state. T2 `unknown`; T3–T6 do not fire.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `framework/spec-workflows/spec-lifecycle.md` — Reviewer sub-step: high tier mandatory; transition table row.
- `framework/skills/reviewing-changes/SKILL.md`, `framework/agents/reviewer.md` — where output is recorded.
- `docs/agent-protocol.md` — closure gate format.
- `docs/ai-agent-framework.md` — reviewer description no longer "recommended" for high tier.

## Rollout / migration notes

- Active high-tier specs at the moment of closure adopt the row at their own closure; none are rewritten.
