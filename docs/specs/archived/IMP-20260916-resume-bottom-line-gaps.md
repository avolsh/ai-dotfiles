---
id: IMP-20260916-resume-bottom-line-gaps
type: IMP
date: 2026-09-16
status: done
closed: 2026-09-16
owner: alexvolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/prompts/resume-spec.prompt.md
affected-code: []
skills:
  - writing-specs
model-suggestion: default
baseline-impact: none — framework prompt wording only; no docs/domain baseline
siblings:
  - IMP-20260914-resume-spec-prompt
  - BUG-20260916-system-docs-prefix-unresolved
---

# IMP-20260916-resume-bottom-line-gaps

*Last updated: 2026-09-16*

## Summary

- **Goal:** Close the two step-5 gaps a cold run of `resume-spec.prompt.md` reported.
- **Scope:** Step 5 of the prompt: what a re-posted Bottom Line field says when nothing is on record, and what happens
  to a later task's file already present.
- **Out of scope:** The Bottom Line format itself; the `<system>/docs/` path defect (sibling BUG).

## Current State

The AC-1 cold re-run of `IMP-20260914-resume-spec-prompt`
([worked examples § AC-1 cold re-run](artifacts/IMP-20260914-resume-spec-prompt-worked-examples.md))
reported: step 5 rebuilds the Bottom Line "from the row and the git history" but does not say what a field with no
record holds, so the agent chose its own wording; and step 5 is silent on a later task's file already committed or
modified, while the no-discard rule sits only in step 6.

## Proposed Improvement

State both behaviours in step 5. Measurable benefit: a second cold run on the same fixture reports neither gap.

## Requirements

- FR-1: Step 5 MUST say a Bottom Line field with nothing on record reads `none on record`, never an inferred value.
- FR-2: Step 5 MUST say a file belonging to a later task that is already committed or modified is listed under
  Divergences flagged and left untouched.

## Acceptance Criteria

### AC-1: A cold run finds no step-5 gap (FR-1, FR-2)

Given the `ac1` fixture of `IMP-20260914-resume-spec-prompt` (T2 `◐`, T3's `src/cli.py` committed early)
When a fresh agent with no history runs the resume prompt
Then it stops at step 5 using `none on record` for empty fields, lists `src/cli.py` under Divergences, and reports no
ambiguity about either
Evidence: recorded cold run

## Design

Skipped — wording change to one prompt step; no flow, schema or UI change.

## Out of Scope

- OS-1: Resolving `<system>/docs/` — `BUG-20260916-system-docs-prefix-unresolved`.

## Split Decision

**Kept as one — E4.** Two sentences in one step of one file; neither is worth shipping alone.

## Tasks

> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Add the two step-5 sentences, then re-run AC-1 cold and record it (FR-1, FR-2; AC-1). | `framework/prompts/resume-spec.prompt.md`, this spec | `docs/specs/archived/artifacts/IMP-20260914-resume-spec-prompt-worked-examples.md` | — | writing-specs | fast | ☑ done |

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Owner approved requirements, plan and execution in
one message on 2026-09-16 ("just do it all now").

## Docs updates required

- `framework/prompts/resume-spec.prompt.md` step 5.

## Rollout / migration notes

- None.

## Closure Evidence

| AC | Evidence |
|---|---|
| AC-1 | Cold sub-agent runs (Claude Opus 5, no history, fixture `ac1` of `IMP-20260914-resume-spec-prompt`, 2026-09-16). Run 2 (first wording "a field with nothing on record reads `none on record`"): `src/cli.py` under Divergences, empty fields `none on record` — but it wrote `none on record` for Open questions and flagged the clash with the canonical `none`. Wording narrowed to *Acceptance criteria satisfied* / *Tests / verification run*. Run 3: those two read `none on record`, Open questions `none`, `src/cli.py` under Divergences and left untouched; stopped at step 5; no ambiguity reported about either FR. Residual notes were fixture-shaped (one commit holds T1–T3 files) |
| Suites | `make check` exit 0 |


- **Divergences:** FR-1 as first written ("a field with nothing on record") was narrowed in T1 after run 2 exposed the clash with the canonical `none`; FR-1's intent unchanged.
- **Accepted duplication:** none.

### Review

Not run — `risk: low`; closed review-after, owner approved execution in chat on 2026-09-16.
