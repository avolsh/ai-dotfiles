---
id: IMP-20260916-quality-gates-check
type: IMP
date: 2026-09-16
status: specify
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
  - tobevisit-content
  - tobevisit-web
affected-docs:
  - docs/bootstrapping-project.md
  - framework/skills/bootstrapping-project/references/scaffold-manifest.md
affected-code:
  - scripts/validate-quality-gates.py (new)
  - scripts/test/validate-quality-gates.test.sh (new)
  - Makefile
skills:
  - writing-specs
  - test-driven-development
  - bootstrapping-project
model-suggestion: default
siblings:
  - IMP-20260914-consolidation-checkpoint
  - IMP-20260914-baseline-deltas-and-merge
  - IMP-20260914-machine-readable-spec-reports
  - IMP-20260914-spec-next-instructions
  - CR-20260914-design-decisions-and-architecture-profile
---

# IMP-20260916-quality-gates-check

*Last updated: 2026-09-16*

## Summary

- **Goal:** Make the `Kind` / `Mode` quality-gates contract something a build checks, not something a bootstrap
  step asks for once.
- **Scope:** A stdlib-only validator in ai-dotfiles that reads a project's `_canonical.md § Build and Run` and
  fails on a missing required kind, an unexamined seed, or a `duplication` row without a report path; wired into
  the verification sequence of `tobevisit-content` and `tobevisit-web` in this spec.
- **Out of scope:** Running the declared commands, or judging whether a declared tool is a good one.

## Current State

`IMP-20260914-quality-gates-contract` (archived) put `Kind` / `Mode` columns and four required kinds — `format`,
`lint`, `duplication`, `security` — into `framework/templates/project/_canonical.md`, and made
`docs/bootstrapping-project.md` step 4 ask the human about each. It deferred a validator (its OS-2) to
`RES-20260914-declarative-lifecycle-schema`, still at `specify`. Nothing reads the table today, so:

- `tobevisit-content` declares all four since `IMP-20260914-duplicate-report-and-format-scope` — by hand.
- `tobevisit-web` has no table: its Build and Run is five bullets with no `Kind` column, and no check fails.
- A scaffolded project keeps `n/a — to be decided` rows indefinitely; nothing distinguishes them from a decision.

## Proposed Improvement

A validator every project's build runs, decided in chat on 2026-09-16 over waiting for the RES: the check is small,
and it moves wherever the RES later places scaffold checks. Measurable benefit: projects whose build fails on a
missing required kind go from 0 of 2 to 2 of 2.

## Requirements

- FR-1: `scripts/validate-quality-gates.py <project-root>` MUST parse the `## Build and Run` table of
  `_canonical.md` and exit non-zero when the section, the table, or its `Kind` / `Mode` columns are absent.
- FR-2: It MUST fail when any of `format`, `lint`, `duplication`, `security` has no row, or has only a row whose
  step reads `n/a — to be decided`; an `n/a — <reason>` row with any other reason MUST pass.
- FR-3: It MUST fail on a `Kind` outside `format | lint | typecheck | test | duplication | security | docs | build |
  other`, a `Mode` outside `gate | report`, a `gate` row numbered `—`, or a `report` row carrying a number.
- FR-4: It MUST fail on a `duplication` row that names no report file path in `What fails it`.
- FR-5: Each finding MUST print as `path:line:check:message`, matching `validate-specs.py`, and the script MUST use
  the Python standard library only.
- FR-6: `tobevisit-content` and `tobevisit-web` MUST run it inside their verification sequence
  (`docs-check` / `make build`), resolving the framework through `AI_DOTFILES` as `validate-specs` does.
- FR-7: `docs/bootstrapping-project.md` step 4 MUST name the validator as what fails a seed left unexamined.

## Acceptance Criteria

### AC-1: Each defect shape fails, a complete table passes (FR-1 – FR-5)

Given fixture `_canonical.md` files — complete; no section; no `Kind` column; `security` missing; `lint` still
`n/a — to be decided`; `Mode` = `sometimes`; `report` row numbered `3`; `duplication` without a path
When the validator runs on each
Then only the complete fixture exits 0, and each other one prints exactly one finding naming its check and line
Evidence: `scripts/test/validate-quality-gates.test.sh`, run by `make tests`

### AC-2: Both projects run it (FR-6)

Given each project's Makefile after the change
When a required-kind row is deleted from its `_canonical.md` in a scratch copy
Then that project's `make build` fails at the step running the validator, naming the missing kind; restored, it
passes
Evidence: recorded runs in both repositories

### AC-3: The bootstrap names the check (FR-7)

Given `docs/bootstrapping-project.md` after the change
When step 4 is read
Then it states that `validate-quality-gates` fails the build while a seed row reads `n/a — to be decided`
Evidence: doc diff

## Design

Skipped — a validator over an existing, already-specified table shape; no new contract.

## Out of Scope

- OS-1: Executing declared commands or checking that a `report` step really exits 0 — each project's own tests.
- OS-2: `ai-dotfiles` itself — a framework repository without a scaffolded `_canonical.md`.
- OS-3: Moving the check under the declarative lifecycle schema — `RES-20260914-declarative-lifecycle-schema`.
- OS-4: Adopting the contract in `tobevisit-web` — `tobevisit-web` `IMP-20260916-quality-gates-adoption`.

## Open Questions

None.

## Split Decision

**Kept as one — E4.** T3 fires: three repositories in `affected-repos`. The per-project wiring (FR-6) is a
one-target Makefile change in each — a trivial extension of the validator cluster with no acceptance surface of its
own. T1: FR-7 is a doc line naming FR-1's output. T2 `unknown` (ai-dotfiles has no module map); T4–T6 do not fire.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `docs/bootstrapping-project.md` — step 4 names the validator.
- `framework/skills/bootstrapping-project/references/scaffold-manifest.md` — the validator in the scaffold's checks.
- `tobevisit-content/_canonical.md` — the `docs-check` bullet lists the new check.

## Rollout / migration notes

- Order, stated here because `depends-on:` cannot resolve across repositories: wire `tobevisit-content` first (it
  passes today); wire `tobevisit-web` only after `IMP-20260916-quality-gates-adoption` closes, or its build is red
  in between — chosen deliberately on 2026-09-16 ("all projects at once"), with the ordering keeping `develop` green.
- Revert: drop the Makefile prerequisite per project; the script is additive.
- Inventory outside this repository, not leasable from here: `tobevisit-content/Makefile`,
  `tobevisit-content/_canonical.md`, `tobevisit-web/Makefile`.
- `siblings:` other than `consolidation-checkpoint` share `Makefile` or `scaffold-manifest.md` only; no shared
  acceptance surface.
