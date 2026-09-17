---
id: IMP-20260917-remove-trivial-lane
type: IMP
date: 2026-09-17
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/lifecycle.yaml
  - framework/spec-workflows/questions/trivial-questions.md
  - framework/spec-workflows/templates/CR-TEMPLATE.md
  - framework/spec-workflows/templates/IMP-TEMPLATE.md
  - framework/spec-workflows/templates/BUG-TEMPLATE.md
  - docs/spec-workflow-guide.md
affected-code:
  - scripts/test/validate-specs.test.sh
  - scripts/test/lifecycle-mutations.test.sh
  - scripts/test/spec-next.test.sh
skills:
  - writing-specs
  - test-driven-development
model-suggestion: default
depends-on:
  - IMP-20260914-explore-mode-and-lane-review
baseline-impact: none — ai-dotfiles has no docs/domain/ baselines; the change removes a framework lane
---

# IMP-20260917-remove-trivial-lane

*Last updated: 2026-09-17*

> **Draft from the 2026-09-17 lane review.** Created by `IMP-20260914-explore-mode-and-lane-review` T4 to carry the
> owner's `remove` decision. The Specify question round (IMP Q1 + Q2 at least) has **not** run; the requirements
> below are seeds for it, not approved requirements.

## Summary

- **Goal:** Remove the Trivial lane, which one spec in 160 used, without invalidating the specs that used it.
- **Scope:** Its prose, template comments, question list, `lifecycle.yaml` lane, rules and `stages:` entries, and
  tests; archived specs keep validating.
- **Out of scope:** The Direct lane and the standard track's gates.

## Current State

The 2026-09-17 lane review (`docs/specs/archived/artifacts/IMP-20260914-explore-mode-and-lane-review-lane-review.md`)
counted one Trivial-lane spec (`CR-20260728-dedup-dismiss-note-inline`, tobevisit-content) against a footprint of 328
lines: `spec-lifecycle.md § Trivial lane` (61), `spec-workflow-guide.md` (100), `spec-types.md` (4),
`trivial-questions.md` (58), comments in three templates (28), `lifecycle.yaml` (42) and ≥35 test lines. The Direct
lane (≤2 files, ≤30 lines, owner-approved) covers the small end with 8 uses.

## Proposed Improvement

Delete the lane from every place the review measured and date-gate the old values, so the framework carries two
spec tracks plus Direct. Measurable benefit: 328 lines of lane footprint to ≤20 (the date gate and its fixture).

## Requirements

- FR-1: The Trivial lane MUST be removed from the prose, templates, question list, `lifecycle.yaml` (lane, rules, `stages:`, question list) and `spec-next` fixtures the review measured.
- FR-2: A spec dated before the removal date MUST keep validating with `risk: trivial` or `severity: trivial`.
- FR-3: A spec dated on or after the removal date that elects `trivial` MUST get a validator finding naming the Direct lane and the standard track.
- FR-4: `spec-next` MUST never offer a trivial step.

## Acceptance Criteria

### AC-1: History survives (FR-2)

Given `CR-20260728-dedup-dismiss-note-inline` and a fixture dated before the removal
When `make validate-specs` runs on both corpora and the fixtures
Then neither gains a finding
Evidence: command output

### AC-2: New elections are refused and nothing offers the lane (FR-1, FR-3, FR-4)

Given a fixture dated after the removal with `risk: trivial`
When the validator and `spec-next` run on it
Then the validator reports the removed lane and `spec-next` prints the standard track
Evidence: `validate-specs.test.sh` + `spec-next.test.sh`

## Design

Pending — Design Decisions / Visualize not yet run.

## Out of Scope

- OS-1: The Direct lane and RES lane — kept by the same review.
- OS-2: Rewriting archived specs that used the lane.

## Split Decision

Pending — Split check not yet run.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`; changes lane definitions — `§ Ask first #3/#4`.

## Docs updates required

- `spec-lifecycle.md § Trivial lane`, `spec-types.md`, `spec-workflow-guide.md`, `docs/ai-agent-framework.md` — remove or tombstone.

## Rollout / migration notes

- Run the Specify question round before anything else; the seeds above may change.
