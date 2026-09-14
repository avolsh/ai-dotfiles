---
id: CR-20260914-design-decisions-and-architecture-profile
type: CR
date: 2026-09-14
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/spec-lifecycle.md
  - framework/spec-workflows/templates/CR-TEMPLATE.md
  - framework/spec-workflows/templates/IMP-TEMPLATE.md
  - framework/spec-workflows/questions/cr-questions.md
  - framework/spec-workflows/questions/imp-questions.md
  - framework/spec-workflows/questions/design-questions.md (new)
  - framework/templates/project/docs/architecture/profile.md (new)
  - framework/skills/bootstrapping-project/references/scaffold-manifest.md
  - docs/adr-conventions.md
  - docs/spec-templates-guide.md
affected-code:
  - scripts/ai-project.sh
skills:
  - writing-specs
  - writing-docs
  - bootstrapping-project
model-suggestion: deep
siblings:
  - IMP-20260914-baseline-deltas-and-merge
  - IMP-20260914-quality-gates-contract
  - IMP-20260914-baseline-verification-freshness
  - IMP-20260914-consolidation-checkpoint
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-responsive-behaviour-and-design-first-figma
---

# CR-20260914-design-decisions-and-architecture-profile

*Last updated: 2026-09-14*

## Summary

- **Goal:** Settle architecture once per project in a written profile, and ask design-approach questions in a spec
  only when the change touches architecture — recording decisions with their rejected alternatives before the
  requirements gate.
- **Scope:** A project architecture profile template and bootstrap questions; a triggered Design Decisions sub-step
  in Specify with its question list; `### Decisions`, `### Risks / Trade-offs`, `### Open Questions` under
  `## Design`; an ADR when a decision departs from the profile.
- **Out of scope:** Deciding any project's architecture — `tobevisit-content` compiles its profile in its own IMP.

## Problem Statement

Specify asks which bounded contexts a change touches (CR Q1) and Visualize draws the result, but nothing asks which
approaches were weighed. Decisions land informally — `CR-20260831-geo-availability-flag § Design` lists "three
decisions the frames settle" — and ADRs are written ad hoc (14 in `tobevisit-content`). The architecture itself is
nowhere stated as a whole: it lives across conventions docs, ADRs, a DDD skill and two lint checks, and project
bootstrap never asks for it. Asking "DDD or monolith?" on every spec would re-litigate settled choices; never asking
lets a spec diverge from them unseen. OpenSpec's `design.md` (Decisions with alternatives, Risks → Mitigation,
deferrable-only Open Questions) is the borrowed shape.

## Requirements

- FR-1: The project scaffold MUST include `docs/architecture/profile.md` stating architectural style, domain
  modelling approach, code organisation, programming style (paradigm, error model, immutability, concurrency), and
  integration style — each linked to an ADR or marked `convention — no ADR`.
- FR-2: Project bootstrap MUST ask the profile questions from `design-questions.md § Project` and write the profile.
- FR-3: Specify MUST run a Design Decisions sub-step before the requirements gate when any trigger fires: a bounded
  context is added or reshaped; data flows between contexts change; a new architectural pattern or external
  dependency is introduced; a persistence or schema model changes; a choice departs from the profile or an ADR;
  risk is `high`.
- FR-4: The sub-step MUST ask at most five questions from `design-questions.md § Spec`, and MUST NOT ask what the
  profile or an ADR already settles.
- FR-5: `## Design` MUST gain `### Decisions` (each decision with alternatives considered and why rejected),
  `### Risks / Trade-offs` (risk → mitigation) and `### Open Questions` (only questions answerable later without
  changing requirements, approach or task breakdown).
- FR-6: A decision that departs from the profile or sets a new project-wide convention MUST link a proposed ADR
  before the requirements gate is requested.
- FR-7: When no trigger fires, `### Decisions` MUST read `Skipped — <reason>` on one line.

## Acceptance Criteria

### AC-1: A new project states its architecture (FR-1, FR-2)

Given a scratch directory
When `ai-project` scaffolds a project and the profile questions are answered
Then `docs/architecture/profile.md` exists with every FR-1 item filled or marked `unrecorded`
Evidence: scaffold self-test

### AC-2: Architecture questions fire only on triggers (FR-3, FR-4, FR-7)

Given the lifecycle, templates and question lists after the change
When a spec adding a bounded context and a spec changing one label are each walked through Specify
Then the first runs the sub-step with ≤5 questions, none re-asking a profile item; the second records
`Skipped — <reason>`
Evidence: two worked examples in `docs/spec-templates-guide.md`

### AC-3: Departures leave a record (FR-5, FR-6)

Given a spec whose decision contradicts a profile item
When the requirements gate is requested
Then `### Decisions` names the rejected alternatives and links a proposed ADR, and `### Open Questions` holds nothing
that changes a requirement
Evidence: worked example + `docs/adr-conventions.md` diff

## Design

Pending — Visualize sub-step (spec-format and project-scaffold schema change).

## Out of Scope

- OS-1: `tobevisit-content`'s profile — `IMP-20260914-architecture-profile` in that repository.
- OS-2: A validator check for the Decisions sub-section — deferred to `RES-20260914-declarative-lifecycle-schema`.
- OS-3: A separate `design.md` file per spec (OpenSpec's layout) — the one-file spec is kept.

## Open Questions

- Q1: The request named "monolith, atc architecture and programming styles" — is "atc" "etc.", or a specific style to
  include in the profile list?
- Q2: Should the profile also carry non-functional targets (latency, cost budgets), or stay strictly structural?

## Split Decision

**Split recommended — T1; human decision at the gate.** C1 (FR-1, FR-2: profile + bootstrap) verifies on the
scaffold alone; C2 (FR-3 – FR-7: the spec sub-step) verifies against a stub profile, which § 1 permits. No exception
applies — C2 reads C1's output but does not share its write path. Proposed siblings:
`CR-…-architecture-profile-scaffold` (C1) and `CR-…-design-decisions-substep` (C2). Kept as one draft here so the
human sees both halves before choosing. T2 `unknown`; T3–T6 do not fire.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Changes spec templates, workflow definitions and
the scaffold — `boundaries.md § Ask first #3/#4` applies at every gate.

## Docs updates required

- `spec-lifecycle.md` — Design Decisions sub-step beside Visualize, triggers.
- CR / IMP templates — `## Design` sub-sections; CR / IMP question lists — pointer to `design-questions.md`.
- `scaffold-manifest.md`, `docs/adr-conventions.md`, `docs/spec-templates-guide.md` — profile, ADR link rule, examples.

## Rollout / migration notes

- Shares the CR / IMP templates with `IMP-20260914-baseline-deltas-and-merge` and the scaffold with
  `IMP-20260914-quality-gates-contract`; sequence after both to avoid concurrent template edits.
