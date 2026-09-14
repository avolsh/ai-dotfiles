---
id: IMP-20260914-resume-spec-prompt
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/prompts/resume-spec.prompt.md (new)
  - docs/agent-protocol.md
  - docs/spec-workflow-guide.md
affected-code: []
skills:
  - writing-specs
model-suggestion: default
siblings:
  - IMP-20260914-baseline-verification-freshness
  - IMP-20260914-consolidation-checkpoint
  - IMP-20260914-mandatory-review-for-high-risk
---

# IMP-20260914-resume-spec-prompt

*Last updated: 2026-09-14*

## Summary

- **Goal:** Let a new session pick up an in-progress spec at the right task without guessing whether the previous
  task was approved.
- **Scope:** A `resume-spec.prompt.md` procedure and a task-status value that distinguishes "done, awaiting
  approval" from "done and approved".
- **Out of scope:** Changing how approval is given.

## Current State

Progress lives in the spec — status and the task table updated in place (`boundaries.md § Always do #11`). Approval
does not: the Bottom Line and the human's "continue" live in chat, and `☑ done` is set when the task completes,
before approval. A session that starts after an interruption sees `☑` and cannot tell whether the human approved it,
while `Never do #6` makes a one-word "continue" approve only the immediately preceding task. There is no prompt for
resuming; the agent reconstructs state ad hoc. OpenSpec resumes at the first unchecked task with "no hidden state".

## Proposed Improvement

Persist the one bit that is hidden, then give resumption a procedure. Measurable benefit: a resumed session never
starts a task whose predecessor's approval is unknown.

## Requirements

- FR-1: The task Status column MUST distinguish `◐ awaiting approval` (Bottom Line posted) from `☑ done` (approved);
  the agent sets `☑` only after approval.
- FR-2: `resume-spec.prompt.md` MUST locate the spec — by ID, or the single active `in-progress` spec — and read its
  Summary, status and first task not at `☑`.
- FR-3: When that task is `◐`, the prompt MUST re-post its Bottom Line and ask for approval before anything else.
- FR-4: Before editing, the prompt MUST report uncommitted changes touching the next task's Files column.
- FR-5: The prompt MUST then run the existing task-start preflight by reference, not restate it.
- FR-6: At `specify` or `plan`, the prompt MUST route to create-spec or plan-spec and make no code edit.

## Acceptance Criteria

### AC-1: An unapproved task is not skipped (FR-1, FR-3)

Given a fixture spec whose Task 2 is `◐ awaiting approval`
When a fresh session runs the resume prompt
Then it re-posts Task 2's Bottom Line and asks for approval, and starts nothing
Evidence: recorded worked example

### AC-2: A clean resume reaches preflight (FR-2, FR-4, FR-5)

Given Task 2 `☑` and Task 3 `☐`, with one uncommitted change to a Task 3 file
When the resume prompt runs
Then it names Task 3, reports the uncommitted file, and posts the standard preflight
Evidence: recorded worked example

### AC-3: Early statuses route away (FR-6)

Given a spec at `plan`
When the resume prompt runs
Then it hands over to plan-spec and edits nothing
Evidence: recorded worked example

## Design

Pending — Visualize sub-step (adds a value to the task-table schema).

## Out of Scope

- OS-1: Recording approvals outside the spec (for example in git notes).
- OS-2: Back-filling `◐` into archived specs.

## Split Decision

**Kept as one — E4.** FR-1 is a one-value schema extension whose only consumer is the prompt. T2 `unknown`.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Adds a framework prompt and changes a spec-format
value — `boundaries.md § Ask first #3` applies; if `IMP-20260914-spec-traceability-checks` has shipped, its
task-row parsing must accept `◐`.

## Docs updates required

- New prompt; `docs/agent-protocol.md § Interpreting "continue" in spec work`; `docs/spec-workflow-guide.md`.

## Rollout / migration notes

- Independent of the rest of the batch; can run whenever a slot is free.
