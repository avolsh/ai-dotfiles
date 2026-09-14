---
id: IMP-20260914-spec-next-instructions
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/agent-protocol.md
  - framework/skills/writing-specs/SKILL.md
  - framework/prompts/create-spec.prompt.md
  - framework/prompts/plan-spec.prompt.md
affected-code:
  - scripts/spec-next.py (new)
  - scripts/test/spec-next.test.sh (new)
  - Makefile
skills:
  - writing-specs
  - test-driven-development
model-suggestion: default
depends-on:
  - RES-20260914-declarative-lifecycle-schema
siblings:
  - IMP-20260914-baseline-deltas-and-merge
  - IMP-20260914-baseline-verification-freshness
  - IMP-20260914-consolidation-checkpoint
  - IMP-20260914-machine-readable-spec-reports
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-resume-spec-prompt
---

# IMP-20260914-spec-next-instructions

*Last updated: 2026-09-14*

## Summary

- **Goal:** Give an agent exactly the rules, questions and template text that apply to one spec's next step, so it
  stops reading the whole canonical corpus to find the part that applies.
- **Scope:** A read-only `spec-next <spec>` command with text and JSON output, driven by the lifecycle source the RES
  settles; the create and plan prompts call it first.
- **Out of scope:** Removing or shortening canonical docs.

## Current State

At a spec stage `agent-protocol.md` has the agent load its own 472 lines, `spec-lifecycle.md` (424),
`boundaries.md` (140) and `authoring-steps.md` (96) — about 1 100 lines — whether the spec is a one-FR Trivial-lane
change or a high-risk CR. The one-hop convention ("link, don't restate") keeps those docs consistent and makes the
reader follow links to assemble the rules for one case. OpenSpec's `openspec instructions` prints the template and
instruction for the next artifact only.

## Proposed Improvement

Resolve type × status × lane × risk to the applicable subset. Measurable benefit: lines an agent must read before
the Specify step, measured at Plan for a Trivial CR and a high-risk IMP, with a target of ≥50% reduction for the
Trivial case.

## Requirements

- FR-1: `spec-next <spec>` MUST print the spec's next step, its required sections still empty or placeholder, the
  question list for the step, the gate to request, and the applicable rules as anchor links with one line each.
- FR-2: The output MUST contain nothing specific to another type, lane or status.
- FR-3: The rule content MUST come from the lifecycle source chosen by
  `RES-20260914-declarative-lifecycle-schema` — the schema if confirmed, otherwise an anchor map checked by
  `validate-anchors.py` — never from a hand-maintained second copy.
- FR-4: `--json` MUST emit the same content structured by field.
- FR-5: `create-spec.prompt.md` and `plan-spec.prompt.md` MUST run `spec-next` first and load only its output plus
  the files it lists.

## Acceptance Criteria

### AC-1: The output is scoped to the case (FR-1, FR-2, FR-4)

Given a Trivial-lane CR at `specify` and a high-risk IMP at `plan` as fixtures
When `spec-next` runs on each, as text and JSON
Then the first lists the combined gate and ≤3 questions and no Split / Visualize content; the second lists the
Plan-stage safety net and task-table format and no question list
Evidence: `spec-next.test.sh`

### AC-2: No second copy of the rules (FR-3)

Given one rule's anchor text changed in its canonical doc
When the anchor check runs
Then a stale `spec-next` mapping is reported
Evidence: `spec-next.test.sh` + `validate-anchors` run

### AC-3: Prompts load less (FR-5)

Given the two prompts after the change
When a Trivial CR is authored with them
Then the recorded lines loaded before the question round meet the Plan-stage target
Evidence: measurement recorded in Closure Evidence

## Design

Pending — Visualize sub-step (new data flow from lifecycle source to prompts).

## Out of Scope

- OS-1: Rewriting canonical docs.
- OS-2: Harness-specific integrations (slash commands, hooks calling `spec-next`).

## Split Decision

**Kept as one — no trigger.** FR-5 has no acceptance surface without FR-1; one cluster. T2 `unknown`.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Changes framework prompts —
`boundaries.md § Ask first #3/#4` applies.

## Docs updates required

- `docs/agent-protocol.md § Context loading order` — `spec-next` as the first read for spec work.
- `writing-specs/SKILL.md`, both prompts.

## Rollout / migration notes

- `## Current State` MUST be re-verified when the RES closes (`spec-lifecycle.md § Rules #10`); FR-3 depends on its
  outcome.
