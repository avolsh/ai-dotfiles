---
id: IMP-20260914-quality-gates-contract
type: IMP
date: 2026-09-14
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/templates/project/_canonical.md
  - framework/skills/bootstrapping-project/references/scaffold-manifest.md
  - framework/skills/reviewing-changes/SKILL.md
  - docs/bootstrapping-project.md
affected-code:
  - scripts/ai-project.sh
skills:
  - writing-specs
  - writing-docs
  - bootstrapping-project
model-suggestion: default
siblings:
  - IMP-20260914-mandatory-review-for-high-risk
---

# IMP-20260914-quality-gates-contract

*Last updated: 2026-09-14*

## Summary

- **Goal:** Every project declares which code-quality checks it runs — format, lint, typecheck, duplication — and
  whether each is a gate or a report, so "code quality feedback" means the same kind of thing in every project.
- **Scope:** A `Kind` and `Mode` column on the project scaffold's `## Build and Run` table, required kinds with an
  explicit `n/a — reason`, a report-only duplication kind, bootstrap questions, and the reviewer's pointer to it.
- **Out of scope:** Choosing tools for a given stack — each project's own spec (for `tobevisit-content`:
  `IMP-20260914-duplicate-report-and-format-scope`).

## Current State

`templates/project/_canonical.md § Build and Run` already requires a read-only verification sequence (Always do #21)
but its step table has no notion of *what kind* of check a step is, so nothing shows that a project has no
formatter check or no duplication signal. `reviewing-changes` tells the reviewer to ignore formatting because "those
are the linter's and formatter's job" — without anything guaranteeing such a job exists. `tobevisit-content` runs
`prettier --check` over `src/**` only and has no duplication detection; duplication is found after the fact (six
archived IMPs titled dedup / unify / simplification).

## Proposed Improvement

Extend the existing table instead of adding a section: one place still lists the sequence, and each row now says
what it guards. Measurable benefit: for each project, the set of missing quality kinds is visible in one read of
`_canonical.md`, and zero kinds are silently absent.

## Requirements

- FR-1: The `## Build and Run` step table MUST carry a `Kind` column with values `format | lint | typecheck | test |
  duplication | docs | build | other` and a `Mode` column with `gate | report`.
- FR-2: A project MUST declare at least one row for each of `format`, `lint` and `duplication`, or a single row per
  missing kind reading `n/a — <reason>`.
- FR-3: A `report` row MUST exit zero regardless of findings and MUST NOT appear in the gate sequence's stopping
  order; a `gate` row MUST.
- FR-4: A `duplication` row MUST name where its machine-readable report is written, so consolidation tooling can
  read it.
- FR-5: Project bootstrap MUST ask for the three required kinds and seed `n/a — to be decided` rather than omit them.
- FR-6: `reviewing-changes § What to ignore` MUST point cosmetic concerns at the project's `format` / `lint` rows.

## Acceptance Criteria

### AC-1: The template carries the contract (FR-1 – FR-4)

Given `templates/project/_canonical.md` after the change
When its `## Build and Run` section is read
Then the table has `Kind` and `Mode`, the three required kinds are placeholder rows, and the prose states the
report/gate exit rules and the report location for `duplication`
Evidence: template diff

### AC-2: A new project gets the rows (FR-5)

Given a scratch directory
When `ai-project` scaffolds a project there
Then the rendered `_canonical.md` contains the three required kinds, each `n/a — to be decided` unless answered
Evidence: `scripts/test` scaffold self-test

### AC-3: The reviewer knows where cosmetics go (FR-6)

Given `reviewing-changes/SKILL.md` after the change
When § What to ignore is read
Then it names the `format` / `lint` rows as the owner of cosmetic findings
Evidence: skill diff

## Design

Pending — Visualize sub-step (changes the project scaffold schema).

## Out of Scope

- OS-1: Tool choice per stack — project specs.
- OS-2: A validator check that `_canonical.md` declares the kinds — deferred until the declarative lifecycle
  (`RES-20260914-declarative-lifecycle-schema`) settles where scaffold checks live.
- OS-3: Adopting the columns in `tobevisit-web` — no active spec surface there yet.
- OS-4: Gate thresholds — project decisions.

## Open Questions

- Q1: Is `security` (dependency audit, secrets) a required kind too, given `secrets-scan.sh` already runs at commit?

## Split Decision

**Kept as one — no trigger.** All FRs share one acceptance surface (the Build and Run contract); T1 does not fire
because FR-5 and FR-6 verify only against the column shape FR-1 defines. T2 `unknown`; T3–T6 do not fire.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`. This changes a shared framework template —
`boundaries.md § Ask first #3/#4` applies at every gate.

## Docs updates required

- `framework/templates/project/_canonical.md`, `scaffold-manifest.md`, `docs/bootstrapping-project.md`.
- `framework/skills/reviewing-changes/SKILL.md` — § What to ignore.

## Rollout / migration notes

- Existing projects adopt the columns through their own spec; `tobevisit-content` does so in
  `IMP-20260914-duplicate-report-and-format-scope`, which follows this one (cross-corpus, not declarable in
  `depends-on:`).
