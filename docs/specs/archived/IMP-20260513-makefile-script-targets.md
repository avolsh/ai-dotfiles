---
id: IMP-20260513-makefile-script-targets
type: IMP
date: 2026-05-13
status: done
owner: alex
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/ai-agent-framework.md
affected-code:
  - Makefile
skills:
  - writing-specs
model-suggestion: default
---

# IMP-20260513-makefile-script-targets

*Last updated: 2026-05-13*

## Summary

- **Goal:** Expose every owned script in `scripts/` and `framework/scripts/` as a Make target so operators never need to remember script paths or flags.
- **Scope:** Root `Makefile` only. Add missing targets for `ai-project.sh`, `ai-workspace.sh`, `check-md-links.sh`, plus a `check` meta-target. Update `help` text.
- **Out of scope:** Template Makefiles (`framework/templates/`), `ai-switch.sh` full-mode target (source-only by design), dedicated test runner target.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 30k–60k |
| Human attention | 3 gates: Specify, Plan, Task 1 Bottom Line; ~2 min each |
| Re-Specify tripwire | Scope expands beyond the root Makefile |

## Current State

The root `Makefile` exposes 3 targets (`install`, `profile-init`, `reset`) for 5 owned scripts. Two scripts (`ai-project.sh`, `ai-workspace.sh`) and two framework scripts (`check-md-links.sh`, `check-md-links.test.sh`) have no Make targets. The `help` target lists all scripts but callers must know the exact path and flags for the unlisted ones.

No existing baseline REQ-IDs — net-new improvement to developer ergonomics.

## Proposed Improvement

Add Make targets for every script not yet exposed and introduce a `check` meta-target.

**Measurable benefit:** Make-callable scripts rise from 3/7 to 6/7 (remaining 1 — `ai-switch.sh` — is source-only by design). Every script listed in `help` has a corresponding target.

### Target mapping

| Make target | Script | Arguments |
|---|---|---|
| `install` | `scripts/ai-install.sh` | *(existing)* |
| `install-check` | `scripts/ai-install.sh --check` | **new** |
| `profile-init` | `scripts/ai-profile-init.sh` | `PROFILE=` *(existing)* |
| `reset` | `scripts/ai-switch.sh --reset` | *(existing)* |
| `project` | `scripts/ai-project.sh` | **new** |
| `workspace` | `scripts/ai-workspace.sh` | **new** |
| `links-check` | `framework/scripts/check-md-links.sh` | **new** |
| `check` | Runs `links-check` + `install-check` | **new** meta-target |

## Requirements

- FR-1: The Makefile MUST include a `project` target that runs `scripts/ai-project.sh`.
- FR-2: The Makefile MUST include a `workspace` target that runs `scripts/ai-workspace.sh`.
- FR-3: The Makefile MUST include a `links-check` target that runs `framework/scripts/check-md-links.sh`.
- FR-4: The Makefile MUST include an `install-check` target that runs `scripts/ai-install.sh --check`.
- FR-5: The Makefile MUST include a `check` meta-target that runs `links-check` and `install-check`.
- FR-6: The `help` target MUST list every target with a one-line description.
- FR-7: All existing targets (`install`, `profile-init`, `reset`) MUST remain unchanged in behavior.

## Acceptance Criteria

### AC-1: project target works (FR-1)

Given the user is in a directory without ai-project scaffolding
When `make -C $AI_DOTFILES project` is run
Then `scripts/ai-project.sh` executes.

### AC-2: workspace target works (FR-2)

Given the user is in a directory without ai-workspace scaffolding
When `make -C $AI_DOTFILES workspace` is run
Then `scripts/ai-workspace.sh` executes.

### AC-3: links-check target works (FR-3)

Given the ai-dotfiles repo has valid markdown links
When `make links-check` is run
Then `framework/scripts/check-md-links.sh` executes and exits 0.

### AC-4: install-check target works (FR-4)

Given `~/.zshrc` has the managed block
When `make install-check` is run
Then `scripts/ai-install.sh --check` exits 0.

### AC-5: check meta-target runs all checks (FR-5)

Given both sub-checks would pass
When `make check` is run
Then both `links-check` and `install-check` execute.

### AC-6: help lists all targets (FR-6)

When `make help` is run
Then every target defined in the Makefile appears in the output with a description.

### AC-7: existing targets unchanged (FR-7)

When `make install`, `make profile-init PROFILE=personal`, or `make reset` is run
Then behavior is identical to the current Makefile.

## Architecture

Skipped — single-file change, low risk, no bounded-context crossing.

## Out of Scope

- OS-1: Template Makefiles (`framework/templates/workspace/Makefile`, `framework/templates/project/Makefile`) — separate scope, different audiences.
- OS-2: `ai-switch.sh` full target — designed to be sourced; Make subshells can't export env to the caller.
- OS-3: Dedicated `test` target for `check-md-links.test.sh` — user declined.
- OS-4: CI integration — no CI pipeline exists for ai-dotfiles yet.

## Split Decision

Kept as one spec — no § 2 trigger matched. All FRs target the same file (`Makefile`), same bounded context, single repo.

## Tasks

**Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files | Deps | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| 1 | Add `project`, `workspace`, `links-check`, `install-check`, `check` targets; update `.PHONY` and `help` text | `Makefile` | `scripts/ai-project.sh`, `scripts/ai-workspace.sh`, `framework/scripts/check-md-links.sh`, `scripts/ai-install.sh` | — | writing-specs | fast | ✅ done |

## Agent instructions

**Before each task — post in chat (mandatory before any edit):**
- Task # being implemented
- Precedent files read (paths)
- Loaded skill files (full `SKILL.md` paths — system or project scope)

**After each task — before proceeding:**
- Run `make help`, `make check` to verify.
- Post **"The Bottom Line"** using the canonical format in
  `<system>/skills/agent-protocol/SKILL.md`
  § The Bottom Line — canonical format, and wait for explicit human
  approval.
- Update the task row's Status column in this spec.

## Docs updates required

- `Makefile` help text — updated as part of FR-7.

## Rollout / migration notes

- Drop-in replacement. No migration needed.
