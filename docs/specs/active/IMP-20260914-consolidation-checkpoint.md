---
id: IMP-20260914-consolidation-checkpoint
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/spec-lifecycle.md
  - framework/skills/avoiding-duplication/SKILL.md
  - docs/agent-protocol.md
  - docs/improvements-log-format.md
affected-code:
  - scripts/consolidation-due.py (new)
  - scripts/test/consolidation-due.test.sh (new)
  - Makefile
skills:
  - writing-specs
  - avoiding-duplication
  - test-driven-development
model-suggestion: default
depends-on:
  - IMP-20260914-machine-readable-spec-reports
siblings:
  - IMP-20260914-baseline-verification-freshness
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-responsive-behaviour-and-design-first-figma
---

# IMP-20260914-consolidation-checkpoint

*Last updated: 2026-09-14*

## Summary

- **Goal:** Schedule the refactoring that "never mix refactoring and feature work" defers, by recommending a
  refactor-only IMP per bounded context after enough change has accumulated there or after one large change.
- **Scope:** A per-context counter, the trigger rules, the inputs a recommendation must gather, persistence of
  accepted-duplication decisions, and a recorded accept/decline outcome that resets the counter.
- **Out of scope:** Performing refactors automatically.

## Current State

`boundaries.md § Never do #5` pushes refactoring out of feature tasks and nothing brings it back: refactor IMPs arise
after defects (e.g. `IMP-20260813-unify-ai-batch-adapters`, `IMP-20260813-dedup-admin-run-gateways`, both in the
week of the 2026-08-13 BUG wave). `Always do #16` records "accepted duplication" decisions only in the Bottom Line,
which is chat — no later tool can read them. A global "every 5–10 specs" counter would fire 6–12 times in a month
like August 2026 (61 closures in `tobevisit-content`).

## Proposed Improvement

Count where the debt accumulates — per bounded context — and make each recommendation carry its evidence.
Decided in chat on 2026-09-14: per-context counter plus a large-spec trigger. Measurable benefit: every context
receives a consolidation decision (accepted or declined with reason) at most N closures after its last one.

## Requirements

- FR-1: `consolidation-due` MUST count, per bounded context, archived specs closed since that context's last
  checkpoint, mapping a spec to contexts by its `affected-code` paths through the project's `module-map.md`.
- FR-2: A recommendation MUST fire when a context's count reaches N (project-configurable, default 5), or at the
  closure of any spec with `risk: high`, more than 8 tasks, or more than 15 `affected-code` entries.
- FR-3: A recommendation MUST gather for the context: accepted-duplication decisions, reviewer findings rejected in
  `Review` rows, improvements-log entries naming it, and the duplication report when the project declares one.
- FR-4: An accepted-duplication decision under `Always do #16` MUST be recorded in the spec's Closure Evidence, not
  only in the Bottom Line.
- FR-5: The agent MUST post the recommendation after the triggering spec's closure summary and MUST NOT create the
  IMP without the human accepting it.
- FR-6: The outcome MUST be logged per context — accepted with the new IMP ID, or declined with a reason — and either
  resets that context's counter.
- FR-7: A recommended IMP MUST be refactor-only (`Never do #5`) and cite the gathered inputs in `## Current State`.

## Acceptance Criteria

### AC-1: The counter and triggers fire where they should (FR-1, FR-2)

Given a fixture project with a module map of two contexts, five closures touching context A and two touching B
When `consolidation-due` runs
Then A is due and B is not; adding one `risk: high` closure in B makes B due as well
Evidence: `consolidation-due.test.sh`

### AC-2: The recommendation carries its evidence (FR-3, FR-4)

Given context A's closures include one Closure Evidence accepted-duplication entry, one rejected reviewer finding
and one improvements-log entry naming A
When the recommendation for A is produced
Then all three appear with their source paths
Evidence: `consolidation-due.test.sh`

### AC-3: A decision resets the counter (FR-5, FR-6)

Given A is due
When a declined outcome with a reason is logged for A
Then `consolidation-due` reports A at count 0 and the reason is retrievable from the log
Evidence: `consolidation-due.test.sh`

## Design

Pending — Visualize sub-step (new closure-time sub-step and a new persisted log).

## Out of Scope

- OS-1: A global counter — declined 2026-09-14.
- OS-2: Automatic refactoring or auto-drafted IMPs without acceptance.
- OS-3: Contexts in repositories without `module-map.md` — reported as `unknown`, same as Split trigger T2.

## Open Questions

- Q1: Default N — 5, or derived from each context's closure rate?
- Q2: Where the checkpoint log lives — tagged entries in `docs/improvements-log.md`, or a dedicated
  `docs/consolidation-log.md` per project?
- Q3: Does FR-7's IMP count toward the next checkpoint of the context it refactors?

## Split Decision

**Kept as one — E2.** Two clusters appear — recording decisions (FR-4) and the checkpoint (FR-1 – FR-3, FR-5 – FR-7)
— but FR-4 exists only to feed FR-3 and shares its acceptance surface; split would be cosmetic. T2 `unknown` for
ai-dotfiles itself; T3–T6 do not fire.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `framework/spec-workflows/spec-lifecycle.md` — consolidation sub-step after closure.
- `framework/skills/avoiding-duplication/SKILL.md` — where accepted duplication is recorded.
- `docs/agent-protocol.md` — post-task checklist and closure summary.
- `docs/improvements-log-format.md` — checkpoint entry format (if Q2 resolves that way).

## Rollout / migration notes

- Reads the duplication report from `tobevisit-content` `IMP-20260914-duplicate-report-and-format-scope` when
  present; works without it (FR-3 lists it as conditional).
- First run on `tobevisit-content` counts from 2026-09-14, not from history, so it does not open with every context due.
