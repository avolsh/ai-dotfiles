---
id: IMP-20260914-explore-mode-and-lane-review
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/prompts/explore.prompt.md (new)
  - framework/prompts/create-spec.prompt.md
  - framework/spec-workflows/spec-lifecycle.md
  - framework/spec-workflows/spec-types.md
  - docs/ai-agent-framework.md
affected-code: []
skills:
  - writing-specs
model-suggestion: deep
siblings:
  - RES-20260914-declarative-lifecycle-schema
  - IMP-20260914-spec-next-instructions
  - CR-20260914-design-decisions-and-architecture-profile
  - IMP-20260914-baseline-deltas-and-merge
  - IMP-20260914-baseline-verification-freshness
  - IMP-20260914-consolidation-checkpoint
  - IMP-20260914-machine-readable-spec-reports
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-responsive-behaviour-and-design-first-figma
---

# IMP-20260914-explore-mode-and-lane-review

*Last updated: 2026-09-14*

## Summary

- **Goal:** Add a no-artifact thinking mode that feeds its conclusions into spec creation, then decide with evidence
  whether the RES and Trivial lanes earn what they cost to maintain.
- **Scope:** `explore.prompt.md` with a hand-off mapped to create-spec's inputs; a measured usage-and-footprint review
  of the RES, Trivial and Direct lanes ending in keep / simplify / remove per lane.
- **Out of scope:** Changing the standard lane.

## Current State

Across 141 archived specs (107 `tobevisit-content`, 34 `ai-dotfiles`) the RES lane has been used once
(`RES-20260520-trivial-lane-applicability`, itself the lane's dry-run) and the Trivial lane once
(`CR-20260728-dedup-dismiss-note-inline`). Both carry lifecycle sections, templates or template comments, question
lists, validator checks and tests. Direct-lane volume is not visible from specs. Exploration happens today as free
chat before `create-spec`, and its conclusions are not carried into the Q1 / Q2 round — the 2026-09-14 audit that
produced this batch is an example. OpenSpec's `explore` writes nothing and hands off to `propose` with the settled
context.

## Proposed Improvement

Give exploration a shape so the heavy RES lane is only for spikes that run code, then measure every non-standard
lane. Measurable benefit: each lane has a recorded keep / simplify / remove decision citing usage count and
maintenance footprint in lines.

## Requirements

- FR-1: `explore.prompt.md` MUST read code and docs, ask questions and compare options, and MUST NOT write files or
  code.
- FR-2: Its hand-off MUST produce a summary mapped to create-spec inputs — Q1 scope, Q2 separability, candidate type,
  candidate risk, candidate splits — which `create-spec.prompt.md` MUST treat as answered rather than re-ask.
- FR-3: The lane review MUST count RES, Trivial and Direct usage across all corpora, Direct from improvements-log
  entries, and measure each lane's footprint: lifecycle lines, template lines, validator check lines and test lines.
- FR-4: The review MUST record one decision per lane — keep, simplify or remove — with its evidence in
  `spec-lifecycle.md` or the improvements log.
- FR-5: Removing or simplifying a lane MUST keep archived specs valid: the validator keeps accepting the old field
  values on specs dated before the change.
- FR-6: The experience of `RES-20260914-declarative-lifecycle-schema` MUST be an input to the RES decision.

## Acceptance Criteria

### AC-1: Explore writes nothing and hands off (FR-1, FR-2)

Given a session that runs the explore prompt on a feature idea and then create-spec
When the file tree is compared before and after exploring, and the create-spec question round is read
Then exploring changed no file, and create-spec asks neither Q1 nor Q2 when the hand-off answered them
Evidence: recorded worked example

### AC-2: Every lane is measured and decided (FR-3, FR-4, FR-6)

Given the corpora on the review date
When the review is written
Then each of RES, Trivial and Direct has a usage count, a footprint in lines, and one decision with reasons
Evidence: review section + counts reproducible by a stated command

### AC-3: History survives a lane change (FR-5)

Given a decision that removes or simplifies a lane
When `make validate-specs` runs on both corpora
Then no archived spec gains a finding
Evidence: command output

## Design

Skipped — a prompt and a documented decision; if a lane is removed, the removal is its own follow-up change.

## Out of Scope

- OS-1: Executing a removal — a follow-up IMP carries it if FR-4 decides so.
- OS-2: Changing the standard lane's gates.

## Split Decision

**Kept as one — no trigger.** C1 (explore, FR-1, FR-2) and C2 (lane review, FR-3 – FR-6) look separable, but the
RES decision in C2 depends on whether C1 absorbs the exploratory use RES was built for, so C2's AC cannot be signed
off without C1 — T1 does not fire. T2 `unknown`; T3–T6 do not fire.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Adds a framework prompt and may change lane
definitions — `boundaries.md § Ask first #3/#4` applies.

## Docs updates required

- New `explore.prompt.md`; `create-spec.prompt.md` hand-off intake.
- `spec-lifecycle.md`, `spec-types.md`, `docs/ai-agent-framework.md` — per the FR-4 decisions.

## Rollout / migration notes

- Runs after the RES closes (FR-6).
