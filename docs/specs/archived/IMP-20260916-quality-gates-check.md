---
id: IMP-20260916-quality-gates-check
type: IMP
date: 2026-09-16
status: done
closed: 2026-09-16
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
- Every `n/a` row — the template's four seeds and `tobevisit-content`'s `security` row — carries `—` in both `#` and
  `Mode`. Re-verified at Plan (2026-09-16) after `IMP-20260914-quality-gates-contract` closed the same day.

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
  other`, a `Mode` outside `gate | report`, a `gate` row numbered `—`, or a `report` row carrying a number. An
  `n/a — <reason>` row MUST carry `—` in `#` and `Mode` and is exempt from the `gate | report` check.
- FR-4: It MUST fail on a `duplication` row in `report` or `gate` mode that names no report file path in
  `What fails it`.
- FR-5: Each finding MUST print as `path:line:check:message`, matching `validate-specs.py`, and the script MUST use
  the Python standard library only.
- FR-6: `tobevisit-content` and `tobevisit-web` MUST run it inside their verification sequence
  (`docs-check` / `make build`), resolving the framework through `AI_DOTFILES` as `validate-specs` does.
- FR-7: `docs/bootstrapping-project.md` step 4 MUST name the validator as what fails a seed left unexamined.

## Acceptance Criteria

### AC-1: Each defect shape fails, a complete table passes (FR-1 – FR-5)

Given fixture `_canonical.md` files — complete (including one `n/a — <reason>` row with `—` Mode); no section; no `Kind` column; `security` missing; `lint` still
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

**Plan-stage safety net (2026-09-16):** P1 no (4 tasks); P2 `unknown` (no module map) — the three repositories are
the T3 cluster already adjudicated above as E4; P3 no (T2–T4 each depend on T1).

## Tasks

> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Validator, test-first: fixtures for every AC-1 shape (built inline in the test, as `validate-specs.test.sh` does) and a test script asserting exit code plus one `path:line:check:message` finding each, then the stdlib parser that makes it pass; hooked into `make tests` (FR-1 – FR-5; AC-1) | `scripts/validate-quality-gates.py` *(new)*, `scripts/test/validate-quality-gates.test.sh` *(new)*, `Makefile` | `scripts/validate-specs.py`, `scripts/test/validate-specs.test.sh`, `framework/templates/project/_canonical.md` | — | test-driven-development | default | ☑ done |
| T2 | Bootstrap docs name the check: step 4 says `validate-quality-gates` fails the build while a seed reads `n/a — to be decided`; the scaffold manifest lists it among the scaffold's checks (FR-7; AC-3) | `docs/bootstrapping-project.md`, `framework/skills/bootstrapping-project/references/scaffold-manifest.md` | `scripts/validate-quality-gates.py` | T1 | bootstrapping-project, writing-specs | fast | ☑ done |
| T3 | Wire `tobevisit-content`: a `quality-gates-check` target resolving `$(AI_DOTFILES)` like `validate-specs`, added as the first `docs-check` prerequisite (ahead of `sync-agents-check`, which would otherwise report the same edit as drift); the `docs-check` bullet lists it; `make sync-agents`; record AC-2 red/green runs (FR-6; AC-2) | `tobevisit-content/Makefile`, `tobevisit-content/_canonical.md`, `tobevisit-content/CLAUDE.md`, `tobevisit-content/AGENTS.md`, `tobevisit-content/.github/copilot-instructions.md` | `scripts/validate-quality-gates.py` | T1 | bootstrapping-project | fast | ☑ done |
| T4 | Wire `tobevisit-web` **after `tobevisit-web` `IMP-20260916-quality-gates-adoption` is `done`**: a `quality-gates-check` target (the `AI_DOTFILES ?=` default already landed with the adoption) run as step 1 of `build`, declared as row 1 of the Build and Run table with the gates renumbered; `make sync-agents`; record AC-2 red/green runs (FR-6; AC-2) | `tobevisit-web/Makefile`, `tobevisit-web/_canonical.md`, `tobevisit-web/CLAUDE.md`, `tobevisit-web/AGENTS.md`, `tobevisit-web/.github/copilot-instructions.md` | `tobevisit-content/Makefile`, `tobevisit-web/_canonical.md` | T1 | bootstrapping-project | fast | ☑ done |

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required

- `docs/bootstrapping-project.md` — step 4 names the validator.
- `framework/skills/bootstrapping-project/references/scaffold-manifest.md` — the validator in the scaffold's checks.
- `tobevisit-content/_canonical.md` — the `docs-check` bullet lists the new check.
- `tobevisit-web/_canonical.md` — step 1 of the Build and Run table is the new check.

## Rollout / migration notes

- Order, stated here because `depends-on:` cannot resolve across repositories: wire `tobevisit-content` first (it
  passes today); wire `tobevisit-web` only after `IMP-20260916-quality-gates-adoption` closes, or its build is red
  in between — chosen deliberately on 2026-09-16 ("all projects at once"), with the ordering keeping `develop` green.
- Revert: drop the Makefile prerequisite per project; the script is additive.
- Inventory outside this repository, not leasable from here: `tobevisit-content/Makefile`,
  `tobevisit-content/_canonical.md`, `tobevisit-web/Makefile`.
- `siblings:` other than `consolidation-checkpoint` share `Makefile` or `scaffold-manifest.md` only; no shared
  acceptance surface.

## Closure Evidence

| AC | Evidence |
|---|---|
| AC-1 | `scripts/test/validate-quality-gates.test.sh` (new, in `make tests`): red before the script existed — 11 failures; green after — `scripts/validate-quality-gates.py self-tests passed ✓` (complete table incl. an `n/a — <reason>` row, 3 × FR-1, 2 × FR-2, 4 × FR-3, 1 × FR-4). `make check` exits 0 |
| AC-2 | `tobevisit-content` (branch `TBV-101-ai-refactoring`): `security` row deleted → `make build` exit 2 at step 1, `_canonical.md:105:kind_missing:required Kind 'security' has no row …`, `make[1]: *** [quality-gates-check] Error 1`; restored → `make build` exit 0 (`docs-check: all 11 checks passed`, through `next build`). `tobevisit-web` (same branch, after `IMP-20260916-quality-gates-adoption` closed): same deletion → exit 2 at step 1, `_canonical.md:104:kind_missing:…`; restored → exit 0 through `next build` (12/12 static pages) with the local CMS up via `docker compose … -p tobevisit-web-local up -d`, stopped afterwards. A first attempt without the CMS failed at `next build` on `ECONNREFUSED 0.0.0.0:8055` after steps 1–4 passed |
| AC-3 | `docs/bootstrapping-project.md` § Workflow step 4 — `validate-quality-gates` fails the build while a seed row reads `n/a — to be decided`; § Verification step lists the validator; `scaffold-manifest.md` row 1 names the check |

### Review

Not run — `risk: medium` is below the high tier that requires one; closure approved by the owner in chat on 2026-09-16.
