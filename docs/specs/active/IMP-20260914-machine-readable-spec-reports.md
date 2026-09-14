---
id: IMP-20260914-machine-readable-spec-reports
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/ai-agent-framework.md
affected-code:
  - scripts/validate-specs.py
  - scripts/spec-status.py (new)
  - scripts/test/validate-specs.test.sh
  - scripts/test/spec-status.test.sh (new)
  - Makefile
skills:
  - writing-specs
  - test-driven-development
model-suggestion: default
siblings:
  - IMP-20260914-spec-traceability-checks
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-baseline-verification-freshness
  - IMP-20260914-responsive-behaviour-and-design-first-figma
---

# IMP-20260914-machine-readable-spec-reports

*Last updated: 2026-09-14*

## Summary

- **Goal:** Let tools and agents read the spec corpus's state — findings, statuses, task progress, unmet
  dependencies — as data, and let a person see it on one screen.
- **Scope:** `--json` and a findings-only report on `validate-specs`; a new read-only `spec-status` command with text
  and JSON output; `make specs-view` dashboard.
- **Out of scope:** Aggregating several repositories into one view.

## Current State

`validate-specs.py` prints `path:line:check:message` lines and a count; `spec-metrics.py` prints one table. There is
no command answering "what is active, at which status, how far along, blocked on what" — a reader lists
`docs/specs/active/` and opens each file. `tobevisit-content/Makefile` documents that `validate-specs` is kept out of
`docs-check` because its output cannot be filtered by check; the consolidation checkpoint
(`IMP-20260914-consolidation-checkpoint`) needs spec inventories and closure data as input.

## Proposed Improvement

Structured output first, dashboard on top of it. Measurable benefit: one command replaces opening every active spec,
and downstream scripts consume JSON instead of re-parsing Markdown.

## Requirements

- FR-1: `validate-specs --json` MUST emit `{findings: [{path, line, check, message}], summary: {total, byCheck}}` with
  the current exit-code semantics unchanged.
- FR-2: `validate-specs --report findings` MUST print only finding lines and the summary.
- FR-3: `spec-status` MUST list every active spec with ID, type, status, risk or severity, owner, tasks done/total
  (parsed from `## Tasks` rows), unmet `depends-on:` IDs, and days since `*Last updated:*`, as text or `--json`.
- FR-4: `make specs-view` MUST print the `spec-status` data grouped by status with unmet dependencies flagged.
- FR-5: Both commands MUST accept a project path argument, as `validate-specs.py` does, and MUST NOT write any file.

## Acceptance Criteria

### AC-1: Validator output is data (FR-1, FR-2)

Given a fixture corpus with two findings of different checks
When the validator runs with `--json`, then with `--report findings`
Then the JSON parses with two findings and `byCheck` counts of 1 and 1; the findings report has two lines plus the
summary; both exit 1
Evidence: `validate-specs.test.sh`

### AC-2: Status reads the corpus (FR-3, FR-5)

Given a fixture with an `in-progress` spec at 3 of 5 tasks and a `specify` spec with one unmet `depends-on:`
When `spec-status --json <fixture>` runs
Then both appear with `3/5` and the unmet ID, and the fixture tree is byte-identical afterwards
Evidence: `spec-status.test.sh`

### AC-3: The dashboard groups by status (FR-4)

Given the same fixture
When `make specs-view` runs
Then specs appear under their status headings and the blocked one is flagged
Evidence: `spec-status.test.sh` snapshot

## Design

Pending — Visualize sub-step (defines a JSON output contract consumed by other scripts).

## Out of Scope

- OS-1: Multi-repository aggregation — deferred with OpenSpec Stores until `tobevisit-web` carries specs.
- OS-2: Per-check suppression in `validate-specs` — a separate decision about the English-only rule's data
  exemption.
- OS-3: A web or TUI dashboard.

## Split Decision

**Split check: T1 fires, recommendation keep as one by election — human decision at the gate.** FR-1/FR-2 and
FR-3/FR-4 are independently testable. No exception applies. Both are small read-only reporting surfaces sharing a
Markdown parser that the second would otherwise duplicate (`boundaries.md § Always do #16`).

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `docs/ai-agent-framework.md` — sync-workflow cheat sheet gains `spec-status` and `specs-view`.

## Rollout / migration notes

- Siblings share `scripts/validate-specs.py`; implement after them to avoid rebasing four parsers at once.
