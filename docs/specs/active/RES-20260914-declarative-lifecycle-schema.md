---
id: RES-20260914-declarative-lifecycle-schema
type: RES
date: 2026-09-14
status: specify
owner: alexvolsh
affected-repos:
  - ai-dotfiles
affected-docs: []
affected-code: []
skills:
  - writing-specs
model-suggestion: deep
hypothesis: A declarative lifecycle.yaml plus a small generic engine can express at least 10 of the validator's 15 checks and every template's required-section rules, reproducing the current findings on both spec corpora exactly, in fewer lines than the checks it replaces.
kill-criteria: ≤8 hours
code-location: research/RES-20260914-declarative-lifecycle-schema/
outcome:
depends-on:
  - IMP-20260914-spec-traceability-checks
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-baseline-verification-freshness
  - IMP-20260914-baseline-deltas-and-merge
  - IMP-20260914-machine-readable-spec-reports
---

# RES-20260914-declarative-lifecycle-schema

*Last updated: 2026-09-14*

## Summary

- **Goal:** Find out whether the lifecycle's rules can live in one declarative file that the validator, the
  templates and a future `spec-next` command all read, instead of being restated across prose, templates and
  1 509 lines of Python.
- **Scope:** A sandbox prototype — `lifecycle.yaml` covering types, statuses, lanes, required sections per status,
  front-matter schema and relations — and an engine that runs it against the `ai-dotfiles` and `tobevisit-content`
  corpora, compared finding-for-finding with `validate-specs.py`.
- **Out of scope:** Replacing `validate-specs.py`, changing any rule, or touching `framework/`.

## Hypothesis

A declarative `lifecycle.yaml` plus a generic engine expresses ≥10 of the 15 checks and all required-section rules,
reproduces current findings on both corpora exactly, and totals fewer lines than the checks it replaces. Checks that
need bespoke logic (English-only, Figma frame IDs, inventory overlap) are expected to remain code plug-ins; how many
do is the measurement.

## Kill Criteria

time-box: ≤8 hours of agent work, counted across iterations.

## Iteration Log

| # | Date | Cause | Decision |
|---|---|---|---|
| (rows added on each `in-progress → specify` backflip; initial entry blank) | | | |

## Decision

Pending — filled at the final `specify → in-progress`.

## Outcome

Pending — filled at `status: done`. Expected shapes: `confirmed` → sibling IMP productionises the schema and
`IMP-20260914-spec-next-instructions` reads it; `refuted` → `spec-next` reads canonical-doc anchors instead;
`inconclusive` → record which checks resisted and why.

Measurements to record: checks expressed declaratively / as plug-ins / not at all; finding parity per corpus;
engine + schema lines vs replaced check lines; rules found stated differently in prose and code.

## Design

Skipped — exploratory; architecture decisions deferred to a promoted IMP if applicable.

## Split Decision

Kept as one — RES iterative loop (per spec-lifecycle.md § RES exception).

## Tasks

Pending — Plan stage only. Expected: set up sandbox; express front-matter and status rules; express section rules;
run parity on both corpora; record findings.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Every `in-progress → specify` backflip MUST add
an `## Iteration Log` row before resuming.

## Docs updates required

- None during the loop.

## Rollout / migration notes

- Waits for every other spec changing `scripts/validate-specs.py` in this batch, so the schema describes stable
  rules rather than a moving target.
- Sandbox path `research/RES-20260914-declarative-lifecycle-schema/` is the only place code lives; nothing merges
  into `scripts/` without a promoted sibling IMP reaching `done`.
