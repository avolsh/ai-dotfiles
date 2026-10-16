---
id: IMP-20261016-consolidation-unknown-never-due
type: IMP
date: 2026-10-16
status: done
closed: 2026-10-16
owner: alexvolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/spec-lifecycle.md
affected-code:
  - scripts/consolidation-due.py
  - scripts/test/consolidation-due.test.sh
skills:
  - writing-specs
  - test-driven-development
model-suggestion: default
baseline-impact: none — the framework carries no docs/domain baselines
---
# IMP-20261016-consolidation-unknown-never-due
*Last updated: 2026-10-16*

## Summary
- **Goal:** `consolidation-due` stops marking `unknown` due, because no decision about it can be recorded.
- **Scope:** `scripts/consolidation-due.py` reports `unknown` with its count and triggers but `due: false`; its self-test proves it; `spec-lifecycle.md` § Consolidation sub-step says so and says what to do instead.
- **Out of scope:** how projects map tooling paths (Makefile, configs, `_infra/`) — a project's `module-map.md` decides that.

## Current State
- IMP-20260914-consolidation-checkpoint counts paths no context owns under `unknown` (its OS-3) and applies the same due rule to it as to a context (`count ≥ threshold` or a large closure).
- `docs/consolidation-log-format.md` § Field rules: a heading names a context "exactly as `module-map.md`'s `Context` column spells it … A name the map does not carry resets nothing." So `unknown` can never be reset, and no IMP can own it.
- Observed in tobevisit-content on 2026-10-16: `make consolidation-due` reported `unknown 10/5 due` after the closure of IMP-20261015-admin-taxonomy-and-process-design, and `--recommend unknown` exits 2 (no such context). Every later closure would report it due again, asking for a decision nobody can record. The `unknown` closures were 6 admin-UI specs (`src/app/`, since mapped there as "Admin App") and tooling/infra paths (Makefile, `package.json`, configs, Docker, `_infra/`, `src/scripts`).
- **Made ahead of this spec:** the change below was edited into the working tree on 2026-10-16 during that consolidation pass, before any spec — a Direct-lane breach, since Direct lane excludes `spec-lifecycle.md`. It is uncommitted; this spec is the record it should have had, and its Plan decides whether the edit is kept as is (docs/improvements-log.md, 2026-10-16).

## Proposed Improvement
Report `unknown` but never mark it due; tell the reader that a path which keeps landing there wants a `module-map.md` row, not a decision. Benefit: a closure's consolidation pass no longer always ends on an undecidable "due" — `unknown` due 10/5 → not due, with its count still shown.

## Requirements
- FR-1: `consolidation-due` MUST report `unknown` with its count and triggers, and MUST set its `due` to `false` whatever they are.
- FR-2: Every named context MUST keep today's due rule unchanged.
- FR-3: `spec-lifecycle.md` § Consolidation sub-step MUST state that `unknown` is listed but never due, and that a path landing there repeatedly wants a row in the project's `module-map.md`.

## Acceptance Criteria
### AC-1: Unknown never due (FR-1, FR-2)
Given a fixture project with a `risk: high` closure whose only path no context owns, and a context made due by its own large closure
When `consolidation-due --json` runs
Then `unknown` carries `large <id> (risk: high)` in its triggers with `due: false`, the context is still `due: true`, and the self-test case fails when the `name != UNKNOWN` guard is removed

### AC-2: Documented (FR-3)
Given `spec-lifecycle.md`
When § Consolidation sub-step is read
Then it says `unknown` is listed, never due, and points to `module-map.md`

## Design
### Decisions
- D1: Keep `unknown` in the report with `due: false` — rejected: dropping it from the report (its count is the signal that the map is missing a row); letting a log entry named `unknown` reset it (it would make a non-context a context in the log format, and no IMP could ever be its `accepted` outcome).
### Risks / Trade-offs
- A project could ignore `unknown` growing forever → the report still prints its count and triggers, and the lifecycle text names the fix (a `module-map.md` row).
### Open Questions
None.
### Visualize
Skipped — one flag in one report.

## Out of Scope
- OS-1: Mapping a project's root-level files (Makefile, `package.json`) to a context — a project decision in its `module-map.md`.

## Split Decision
Rule verdict: `keep` — one flag, its test and one paragraph.

## Tasks
> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Review the edit already in the working tree against FR-1 and FR-2 and adopt or correct it: `due` is `bool(triggers) and name != UNKNOWN`, the module docstring says `unknown` is reported but never due, and the self-test adds a `risk: high` closure on an unmapped path (`Makefile`) asserting `unknown` keeps that trigger with `due: false` while Beta stays due; prove the case fails with the guard removed. FR-1, FR-2 · AC-1 | `scripts/consolidation-due.py`; `scripts/test/consolidation-due.test.sh` | `docs/consolidation-log-format.md`; `docs/specs/archived/IMP-20260914-consolidation-checkpoint.md` | — | test-driven-development | default | ☑ done |
| T2 | Review the § Consolidation sub-step paragraph against FR-3 and bump the file's stamp; run `make tests` and `make validate-specs`; re-run `consolidation-due` against tobevisit-content to show `unknown` listed with its count and not due. FR-3 · AC-2 | `framework/spec-workflows/spec-lifecycle.md` | tobevisit-content `docs/consolidation-log.md`, `docs/architecture/module-map.md` | T1 | writing-specs | fast | ☑ done |

## Closure Evidence
Verified 2026-10-16 in the ai-dotfiles working tree, by the agent; the owner approved T1 and T2 in the session.

| AC | Evidence |
|---|---|
| AC-1 | `scripts/test/consolidation-due.test.sh` — case "OS-3 unknown keeps its trigger but is never due" (a `risk: high` closure on `Makefile`, unmapped) and "OS-3 a named context in the same report keeps its due rule" (Beta, same report). With the `name != UNKNOWN` guard removed the first fails; with the guard inverted the Beta case and seven earlier due cases fail; restored, the self-test passes. `make tests` exit 0. |
| AC-2 | `framework/spec-workflows/spec-lifecycle.md` § Consolidation sub-step, step 1: `unknown` is listed with its count, never due, and a path landing there repeatedly wants a row in the project's `docs/architecture/module-map.md`. Observed on tobevisit-content: `unknown 6/5`, triggers listed, `due: false`, `0 context(s) due`. |

- **Made ahead of the spec:** the code, test and lifecycle edits were made on 2026-10-16 before this spec existed (a Direct-lane breach, `docs/improvements-log.md` 2026-10-16); T1 and T2 reviewed them against FR-1–FR-3, adopted the code as it was, added the FR-2 assertion and sharpened the lifecycle path.
- **Checks:** `make validate-specs` OK (54 specs), `make links-check` OK.
- **Review:** `risk: low` — the reviewer sub-step is recommended, not required, and was not run.
- **Processes:** none started.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. The edit already in the working tree is input to Plan, not a done task: review it against FR-1–FR-3 before adopting it.

## Docs updates required
- framework/spec-workflows/spec-lifecycle.md — § Consolidation sub-step, step 1

## Rollout / migration notes
- None: a report flag; existing `consolidation-log.md` files are unaffected.
