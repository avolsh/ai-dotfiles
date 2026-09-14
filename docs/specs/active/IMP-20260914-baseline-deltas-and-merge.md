---
id: IMP-20260914-baseline-deltas-and-merge
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: high
affected-repos:
  - ai-dotfiles
  - tobevisit-content
affected-docs:
  - framework/spec-workflows/spec-lifecycle.md
  - framework/spec-workflows/templates/CR-TEMPLATE.md
  - framework/spec-workflows/templates/IMP-TEMPLATE.md
  - framework/spec-workflows/templates/BUG-TEMPLATE.md
  - framework/skills/writing-specs/references/authoring-steps.md
  - docs/baseline-citations.md
  - docs/req-id-lifecycle.md
  - docs/writing-specs.md
affected-code:
  - scripts/baseline-merge.py (new)
  - scripts/test/baseline-merge.test.sh (new)
  - scripts/validate-specs.py
  - Makefile
skills:
  - writing-specs
  - writing-docs
  - test-driven-development
model-suggestion: deep
depends-on:
  - IMP-20260914-baseline-verification-freshness
siblings:
  - IMP-20260914-spec-traceability-checks
  - IMP-20260914-mandatory-review-for-high-risk
  - IMP-20260914-machine-readable-spec-reports
  - IMP-20260914-consolidation-checkpoint
  - IMP-20260914-responsive-behaviour-and-design-first-figma
---

# IMP-20260914-baseline-deltas-and-merge

*Last updated: 2026-09-14*

<!-- Body over the 120-line budget: 10 FRs across format, tool and rule, which the Split Decision argues must ship
     together. The overage shrinks if the human splits the authoring rules (FR-4, FR-5) out. -->

## Summary

- **Goal:** Change a baseline by writing a delta against it and merging that delta at closure with a tool, so the
  description of the system as built is maintained by a command rather than by a rule.
- **Scope:** A `## Baseline Deltas` section (ADDED / MODIFIED / REMOVED / RENAMED keyed by REQ-ID); an explicit
  `baseline-impact: none` marker; scenarios on new or modified REQs; behaviour-only REQ text; `baseline-merge` with
  preflight, diff and apply; Rule 13 rewritten around it.
- **Out of scope:** Rewriting existing REQs; multi-repository baselines.

## Current State

Rule 13 asks the closing agent to hand-edit `docs/domain/<feature>.md`. It works when followed —
`CR-20260831-geo-availability-flag` produced `REQ-GEO-CAN-020` – `REQ-GEO-CAN-023` with FR citations — and fails
silently otherwise: 13 of 21 `tobevisit-content` baselines carry a stale verification date. No step shows the human,
at the requirements gate, how the baseline will read afterwards; a MODIFIED target that does not exist is found at
closure; two active specs rewriting one REQ collide only if they happen to share a file path in `affected-code`.
Existing REQs mix behaviour with implementation (`REQ-GEO-CAN-021` names `shared/domain/effective-review-status.ts`),
so a refactor ages them without a behaviour change. REQs carry no scenarios. OpenSpec solves the maintenance half
with delta specs merged at archive (comparative audit, `tobevisit-docs/research/ai-framework-vs-openspec.md`).

## Proposed Improvement

Adopt the delta mechanic, keep the framework's richer baseline format (Why, header table, amendment trail).
Measurable benefit: stale-baseline findings (`IMP-20260914-baseline-verification-freshness`) stay at zero without
manual bumps; a REQ collision between active specs is reported at `specify`, not at closure.

## Requirements

- FR-1: CR, IMP and BUG templates MUST carry `## Baseline Deltas`, one sub-heading per baseline file, with
  `ADDED`, `MODIFIED`, `REMOVED` and `RENAMED` blocks keyed by REQ-ID.
- FR-2: A MODIFIED block MUST carry the full replacement requirement; REMOVED MUST carry `Reason` and `Migration`;
  RENAMED MUST carry FROM and TO; ADDED IDs MUST follow `req-id-lifecycle.md § Numbering`.
- FR-3: A spec dated after closure MUST carry either `## Baseline Deltas` or front-matter
  `baseline-impact: none — <reason>`; the validator reports a spec with neither.
- FR-4: A new or modified REQ MUST carry at least one verification scenario (Given / When / Then, or a pointer to the
  test asserting it); unmodified REQs are not required to.
- FR-5: REQ text in a delta MUST state externally observable behaviour; file paths and symbol names belong in the
  baseline header's `Source files read` or the module map — authoring guidance and a reviewer Contract check, since
  the validator cannot judge it.
- FR-6: `baseline-merge --check` MUST report a MODIFIED / REMOVED / RENAMED target absent from the baseline, an ADDED
  ID already present, and two active specs naming one REQ-ID with no `siblings:` / `depends-on:` between them; the
  validator runs it at every status.
- FR-7: `baseline-merge --diff <spec>` MUST print, per baseline, the unified diff the merge would produce.
- FR-8: `baseline-merge --apply <spec>` MUST write the deltas, append `(amended by <spec-id>)` to each touched REQ,
  set `Last src verified` to the spec's `closed:` date with the spec ID, and write nothing when `--check` fails.
- FR-9: Rule 13 MUST require `--apply` at closure; a hand edit to a baseline REQ outside a delta is permitted only
  through the Direct lane with its improvements-log entry.
- FR-10: Archived specs MUST NOT be rewritten; the checks judge only specs dated after closure.

## Acceptance Criteria

### AC-1: A delta round-trips into the baseline (FR-1, FR-2, FR-8)

Given a fixture baseline with REQ-X-001 – REQ-X-003 and a spec that ADDs REQ-X-004, MODIFIES REQ-X-002 and REMOVES
REQ-X-003 with reason and migration
When `baseline-merge --apply` runs on the spec at `closed: 2026-10-01`
Then the baseline holds REQ-X-001, the new REQ-X-002 text with its amendment marker, REQ-X-004, a removal tombstone
per `req-id-lifecycle.md § Deletion`, and `Last src verified | 2026-10-01 (<spec-id>)`
Evidence: `baseline-merge.test.sh` golden file

### AC-2: Bad deltas are refused before anything is written (FR-6, FR-8)

Given a spec MODIFYING REQ-X-009, which does not exist, and a second active spec modifying REQ-X-002 unrelated to a
first
When `--check` runs, then `--apply`
Then `--check` reports both conditions and `--apply` exits non-zero leaving the baseline byte-identical
Evidence: `baseline-merge.test.sh`

### AC-3: The gate can see the result (FR-7)

Given the AC-1 spec
When `baseline-merge --diff` runs
Then it prints a unified diff for that baseline and writes no file
Evidence: `baseline-merge.test.sh` snapshot

### AC-4: Every new spec states its baseline impact (FR-3, FR-4, FR-10)

Given one post-cut-off fixture with neither deltas nor marker, one whose ADDED REQ has no scenario, and the live
archived corpora
When the validator runs
Then the two fixtures produce one finding each and the archived corpora produce none from these checks
Evidence: `validate-specs.test.sh` + `make validate-specs` in both corpora

### AC-5: A real spec closes through the tool (FR-5, FR-9)

Given the first `tobevisit-content` CR or IMP opened after this IMP reaches `plan`
When it closes
Then its baseline changes arrive through `--apply`, and its reviewer `Review` row records the Contract check on
behaviour-only REQ text
Evidence: the pilot spec's Closure Evidence, cited here at closure

## Design

Pending — Visualize sub-step (spec-format and baseline-format schema change; new data flow spec → tool → baseline).

## Out of Scope

- OS-1: Rewriting existing REQs into behaviour-only form, or back-filling scenarios — candidate consolidation IMPs
  per baseline.
- OS-2: Parsing prose FRs into deltas automatically.
- OS-3: Baselines shared across repositories.
- OS-4: Adopting OpenSpec's four-file change folder — the one-file spec is kept (audit § 6).

## Open Questions

- Q1: Does a BUG that restores documented behaviour need a delta, or always `baseline-impact: none`?
- Q2: Pilot spec for AC-5 — the next `tobevisit-content` CR, or a chosen one?
- Q3: Should `--apply` run as the last task of Plan's table, or as a closure-gate action outside the table?

## Split Decision

**Human decision needed at the gate.** Three clusters: C1 format (FR-1 – FR-3, FR-10), C2 authoring rules (FR-4,
FR-5), C3 tool + rule (FR-6 – FR-9). C1 and C3 are not independently testable — the tool has nothing to parse
without the format, and the format without the tool is Rule 13 as it is today — so T1 does not fire between them.
T1 fires for C2, which verifies on templates and guidance alone. Recommendation: keep C2 in — its scenarios and
behaviour-only text live inside the delta blocks C1 defines, so a split leaves C2 describing a section that does
not yet exist (E2 by reference). T3 fires on `affected-repos` by the letter; the only `tobevisit-content` change is
the AC-5 pilot. Plan-stage risk: P1 (>12 tasks) is plausible; if it fires, C2 splits out.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. Changes spec templates and workflow definitions
— `boundaries.md § Ask first #3` applies at every gate.

## Docs updates required

- `framework/spec-workflows/spec-lifecycle.md` — schema (`baseline-impact:`), Rule 13, closure transition.
- Three templates — `## Baseline Deltas`.
- `docs/baseline-citations.md`, `docs/req-id-lifecycle.md` — delta semantics, amendment markers, scenarios.
- `authoring-steps.md § A`, `docs/writing-specs.md` — how to write a delta and when to use the marker.

## Rollout / migration notes

- Ships after `IMP-20260914-baseline-verification-freshness` (declares `closed:`, which FR-8 writes from).
- The rule flip (FR-9) lands only after AC-5's pilot closes through the tool; until then Rule 13 keeps its prose form
  alongside the tool.
