---
id: RES-20260914-declarative-lifecycle-schema
type: RES
date: 2026-09-14
status: in-progress
owner: alexvolsh
affected-repos:
  - ai-dotfiles
affected-docs: []
affected-code: []
skills:
  - writing-specs
model-suggestion: deep
hypothesis: A declarative lifecycle.yaml plus a small generic engine can express at least 15 of the validator's 22 checks and every template's required-section rules, reproducing the current findings on both spec corpora and on the validate-specs test fixtures exactly, in fewer lines than the checks it replaces.
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

*Last updated: 2026-09-17*

## Summary

- **Goal:** Find out whether the lifecycle's rules can live in one declarative file that the validator, the
  templates and a future `spec-next` command all read, instead of being restated across prose, templates and
  2 020 lines of Python (`scripts/validate-specs.py`, plus shared readers in `scripts/speclib.py`).
- **Scope:** A sandbox prototype — `lifecycle.yaml` covering types, statuses, lanes, required sections per status,
  front-matter schema and relations — and an engine that runs it against the `ai-dotfiles` and `tobevisit-content`
  corpora and the `scripts/test/validate-specs.test.sh` fixtures, compared finding-for-finding with
  `validate-specs.py`.
- **Out of scope:** Replacing `validate-specs.py`, changing any rule, or touching `framework/`.

## Hypothesis

A declarative `lifecycle.yaml` plus a generic engine expresses ≥15 of the 22 checks and all required-section rules,
reproduces current findings exactly on both corpora and on the validator's test fixtures, and totals fewer lines than
the checks it replaces. Checks that need bespoke logic (English-only, Figma frame IDs, inventory overlap, review
disposition, baseline deltas) are expected to remain code plug-ins; how many do is the measurement.

The 22 checks are the 17 in `CHECK_REGISTRY` plus the five run outside it: agent front-matter, domain REQ-IDs,
baseline freshness, log `Closed`, baseline deltas. The ≥15 bar keeps the original two-thirds ratio (10 of 15), set
when the validator had 15.

Parity on the live corpora alone is weak: at 2026-09-16 `ai-dotfiles` yields 0 findings and `tobevisit-content` 3
(`deps_dangling`, `english_only`, `link_broken`), so an engine that reports nothing nearly passes. The fixture suite
supplies the violating inputs; parity is counted on both.

"Lines replaced" is the check functions plus their private helpers in `validate-specs.py`, measured when the sandbox
is set up; the shared `speclib.py` readers are reused by both sides and excluded.

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

> **Before starting Task T1, set status: in-progress in the front-matter above.**

Time-box started 2026-09-16. Paths are relative to the workspace root; `validate-specs.py` is only read, never edited.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Sandbox + parity harness: a shim that runs `validate-specs.py` and the engine on the same input and logs finding-set differences, a runner over both corpora and the fixture suite (run through the shim), and the lines-replaced baseline | `research/RES-20260914-declarative-lifecycle-schema/README.md` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/shim.py` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/parity.sh` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/measure_lines.py` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/engine.py` *(new, empty engine)* | `env/ai-dotfiles/scripts/validate-specs.py`, `env/ai-dotfiles/scripts/speclib.py`, `env/ai-dotfiles/scripts/test/validate-specs.test.sh` | — | writing-specs | default | ☑ done |
| T2 | Mutation fixtures for the 26 finding ids the self-tests never trigger (T1 finding), then schema v0 — front-matter fields, enums, types, statuses, lanes, status/location invariants, naming and filename–id parity; engine interprets them | `research/RES-20260914-declarative-lifecycle-schema/fixtures.sh` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/parity.sh`, `research/RES-20260914-declarative-lifecycle-schema/lifecycle.yaml` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/yamlite.py` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/engine.py` | `env/ai-dotfiles/framework/spec-workflows/spec-lifecycle.md`, `env/ai-dotfiles/framework/spec-workflows/spec-types.md` | T1 | writing-specs | deep | ☑ done |
| T3 | Required-section rules per type and status, read from the four templates; freshness | `research/RES-20260914-declarative-lifecycle-schema/lifecycle.yaml`, `research/RES-20260914-declarative-lifecycle-schema/engine.py` | `env/ai-dotfiles/framework/spec-workflows/templates/` | T2 | writing-specs | deep | ☐ pending |
| T4 | Relations — depends-on / siblings graph, promotion targets, link integrity | `research/RES-20260914-declarative-lifecycle-schema/lifecycle.yaml`, `research/RES-20260914-declarative-lifecycle-schema/engine.py` | `env/ai-dotfiles/scripts/validate-specs.py` | T2 | writing-specs | deep | ☐ pending |
| T5 | Wire every remaining check as a plug-in; full parity run on both corpora and all fixtures | `research/RES-20260914-declarative-lifecycle-schema/plugins.py` *(new)*, `research/RES-20260914-declarative-lifecycle-schema/engine.py` | `env/ai-dotfiles/scripts/validate-specs.py` | T3, T4 | writing-specs | default | ☐ pending |
| T6 | Record measurements, prose-vs-code rule drift, Decision and Outcome | `env/ai-dotfiles/docs/specs/active/RES-20260914-declarative-lifecycle-schema.md`, `research/RES-20260914-declarative-lifecycle-schema/README.md` | `research/RES-20260914-declarative-lifecycle-schema/` | T5 | writing-specs | default | ☐ pending |

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Every `in-progress → specify` backflip MUST add
an `## Iteration Log` row before resuming.

## Docs updates required

- None during the loop.

## Rollout / migration notes

- Waited for every other spec changing `scripts/validate-specs.py` in this batch, so the schema describes stable
  rules rather than a moving target. All five `depends-on` IMPs are `done` (checked 2026-09-16); the counts above
  were re-measured against the validator they left behind.
- Sandbox path `research/RES-20260914-declarative-lifecycle-schema/` is the only place code lives; nothing merges
  into `scripts/` without a promoted sibling IMP reaching `done`.
