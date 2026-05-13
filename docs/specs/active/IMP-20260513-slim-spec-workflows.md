---
id: IMP-20260513-slim-spec-workflows
type: IMP
date: 2026-05-13
status: plan
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/README.md
  - framework/spec-workflows/spec-lifecycle.md
  - framework/spec-workflows/spec-types.md
  - framework/spec-workflows/adr-conventions.md
  - docs/adr-conventions.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
siblings:
  - IMP-20260513-slim-system-templates
  - IMP-20260513-slim-skill-bodies
  - IMP-20260513-slim-framework-prompts
  - IMP-20260513-slim-spec-templates
  - IMP-20260513-compress-boundaries
  - IMP-20260513-slim-project-templates
  - IMP-20260513-slim-workspace-templates
---

# IMP-20260513-slim-spec-workflows

*Last updated: 2026-05-13*

## Summary

- **Goal:** Consolidate `framework/spec-workflows/` so `spec-lifecycle.md` becomes the single canonical source for lifecycle rules; `README.md` becomes a thin TOC; `adr-conventions.md` migrates entirely to `docs/`.
- **Scope:** `framework/spec-workflows/README.md`, `spec-lifecycle.md`, `spec-types.md` (verification only), `adr-conventions.md`. Creates `docs/adr-conventions.md`.
- **Out of scope:** `framework/spec-workflows/templates/*` (owned by IMP-D), `framework/spec-workflows/questions/*` (already machine-readable lists), the schema or semantics of any front-matter field.
- **Per-file targets (exception to global ≥80% rule):** README.md ≥80% (becomes TOC); spec-lifecycle.md may grow up to ~20% by design (absorbs lifecycle content currently duplicated across README, skill bodies, prompts, system templates); spec-types.md unchanged (already machine-lookup); adr-conventions.md → 0 lines in framework (moves to docs/). **Net layer reduction ~50%** measured across the four files.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 100k-200k |
| Human attention | 8 gates (1 specify + 1 plan + 5 task + 1 closure); ~10 min/gate |
| Re-Specify tripwire | spec-lifecycle.md cannot serve as single source without growing past 180 lines, OR README.md cannot reach ≤25 lines without losing required navigation entries |

## Current State

The `framework/spec-workflows/` directory carries five workflow-definition files:
- `README.md` (116 lines) — workflow diagram, stage summary, Visualize sub-step rules, Split sub-step rules, anti-skip rules, "when the user types 'create spec'" routing table.
- `spec-lifecycle.md` (129 lines) — status transitions, front-matter schema, gate rules.
- `spec-types.md` (61 lines) — type catalog, per-stage context-load matrix.
- `adr-conventions.md` (42 lines) — ADR naming, status values, template guidance.
- `questions/` — out of scope.

Lifecycle rules currently appear in **eight** places (per the earlier triage): `spec-lifecycle.md`, `spec-workflows/README.md`, the three system templates, `writing-specs/SKILL.md`, the four framework prompts, and the spec templates' inline explainers. After siblings IMP-A/B/C/D close, those external duplications are removed; this sibling consolidates the remaining authoritative copy into `spec-lifecycle.md`.

`adr-conventions.md` is pure prose (42 lines: naming convention, statuses, mini template) and never auto-loaded; it is consulted only when someone authors an ADR. It belongs in `docs/`, not `framework/`. `cites-reqs:` omitted — framework-convention work.

## Proposed Improvement

`spec-lifecycle.md` becomes the **single canonical source** for: lifecycle status definitions, transitions, gate rules, front-matter schema, anti-skip rules, Visualize sub-step trigger rules, and Split sub-step trigger pointers. May grow ~10-20% (129 → ≤150 lines) as it absorbs anti-skip rules + Visualize/Split sub-step rules currently in `README.md`. Growth is an investment: external duplication shrinks by far more.

`README.md` collapses to ≤25 lines: title, *Last updated:*, and a TOC table linking to `spec-lifecycle.md` (rules), `spec-types.md` (catalog), `templates/` (copy-ready), `questions/` (per-type), `docs/adr-conventions.md` (ADR guide). All prose moves to `spec-lifecycle.md` or to `docs/`.

`spec-types.md` is verified to remain machine-lookup tabular content. If any prose paragraph snuck in, it moves to `spec-lifecycle.md`. No line-count change expected.

`adr-conventions.md` migrates verbatim to `docs/adr-conventions.md` (organized as a topic-page under the docs/ layer per the broader framework→docs/ separation rule). The framework file is removed entirely; readers reach the guide via the README.md TOC entry.

**Measurable benefit:**
- `README.md` 116 → ≤25 lines (≥78%; effectively ≥80% after final compression)
- `spec-lifecycle.md` 129 → ≤150 lines (growth permitted; max +16%)
- `spec-types.md` 61 → ≤61 (unchanged or fewer)
- `adr-conventions.md` 42 → 0 in framework; identical content at `docs/adr-conventions.md`
- **Net framework layer reduction:** 348 → ~210 lines (~40% layer-wide)
- **Lifecycle-rule load surface** (the agent's actual cost when it consults lifecycle): drops from ~370 lines scattered across README.md + skill bodies + prompt files + system templates → 150 lines in spec-lifecycle.md only (~60% reduction in agent-load cost — captures the true win).

## Requirements

- FR-1: `spec-lifecycle.md` MUST be the single canonical source for lifecycle status definitions, status transitions, gate rules, front-matter schema, anti-skip rules, Visualize sub-step trigger rules, and Split sub-step trigger pointers. No other file in `framework/` or in any cross-sibling slim MAY re-state these rules; cross-references are markdown links only.
- FR-2: `spec-workflows/README.md` MUST be ≤25 lines and consist of: H1 title, *Last updated:*, and a TOC table linking each related file with a one-line purpose statement. No prose paragraphs.
- FR-3: `spec-types.md` MUST contain only the type catalog table and the per-stage context-load matrix. If any prose paragraph exists at HEAD before the slim, it MUST move to `spec-lifecycle.md` or to `docs/`.
- FR-4: `framework/spec-workflows/adr-conventions.md` MUST be removed; its content MUST appear at `docs/adr-conventions.md` with `*Last updated: 2026-05-13*` and a one-line purpose statement.
- FR-5: Every cross-reference in the slimmed files MUST resolve to an existing file at HEAD (no dangling links). Cross-references previously pointing at `framework/spec-workflows/adr-conventions.md` MUST be updated to `docs/adr-conventions.md`.

## Acceptance Criteria

### AC-1: spec-lifecycle.md is single source (FR-1)

Given the slim complete at HEAD
When `grep -rE 'specify → plan → in-progress → done|anti-skip|Visualize sub-step|Split sub-step' framework/ -l` runs
Then the only match is `framework/spec-workflows/spec-lifecycle.md` (no duplicate copies in `README.md`, skill bodies, prompts, or system templates)

### AC-2: README.md is a TOC (FR-2)

Given the slimmed `spec-workflows/README.md` at HEAD
When `wc -l framework/spec-workflows/README.md` runs
Then the file is ≤25 lines
And the body contains a TOC table with rows linking to spec-lifecycle.md, spec-types.md, templates/, questions/, and docs/adr-conventions.md

### AC-3: spec-types.md is machine-lookup (FR-3)

Given the verified `spec-types.md` at HEAD
When the file is inspected for prose paragraphs (heuristic: any non-table line longer than 80 chars that is not a header)
Then no such lines exist

### AC-4: adr-conventions.md migrated (FR-4)

Given the slim complete at HEAD
When `ls framework/spec-workflows/adr-conventions.md docs/adr-conventions.md` runs
Then the first path does not exist; the second path exists with the migrated content and a 2026-05-13 Last-updated line

### AC-5: No dangling cross-references (FR-5)

Given the slim complete at HEAD
When every markdown link inside `framework/spec-workflows/*.md` is resolved
Then every target file exists at HEAD

## Architecture

Skipped — convention/refactor at the workflow-definitions layer; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: `framework/spec-workflows/templates/*` — owned by `IMP-20260513-slim-spec-templates`.
- OS-2: `framework/spec-workflows/questions/*` — already terse machine-readable lists; left alone.
- OS-3: Front-matter schema rules — preserved verbatim in `spec-lifecycle.md`.
- OS-4: Anti-skip-rule **semantics** — only their *location* changes (centralized in spec-lifecycle.md).

## Split Decision

Kept as one sibling spec — per `splitting-rules.md § 2` this layer is a coherent refactor of one bounded artifact (workflow definitions). Siblings cover the other layers. No further sub-split needed.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| E1 | Migrate `framework/spec-workflows/adr-conventions.md` to `docs/adr-conventions.md`; delete the framework copy (FR-4). | `framework/spec-workflows/adr-conventions.md` (deleted), `docs/adr-conventions.md` (new) | — | — | writing-docs | default | ⬜ todo |
| E2 | Consolidate anti-skip rules + Visualize sub-step trigger rules + Split sub-step pointers into `spec-lifecycle.md` as single canonical source (FR-1). | `framework/spec-workflows/spec-lifecycle.md`, `framework/spec-workflows/README.md` | `framework/spec-workflows/README.md` *(pre-slim source)*; `framework/skills/writing-specs/SKILL.md`; `framework/templates/system/claude/CLAUDE.md` | — | writing-specs, writing-docs | deep | ⬜ todo |
| E3 | Verify `spec-types.md` is machine-lookup only; relocate any prose paragraphs found (FR-3). | `framework/spec-workflows/spec-types.md` | — | — | writing-docs | default | ⬜ todo |
| E4 | Slim `README.md` to ≤25-line TOC pointing at lifecycle, types, templates/, questions/, docs/adr-conventions.md (FR-2). | `framework/spec-workflows/README.md` | `framework/spec-workflows/spec-lifecycle.md` *(E2)*; `framework/spec-workflows/spec-types.md` *(E3)* | E1, E2, E3 | writing-docs | default | ⬜ todo |
| E5 | Update workspace-wide cross-references that pointed at `spec-workflows/adr-conventions.md` to point at `docs/adr-conventions.md` (FR-5). | `framework/` *(grep + update; all files containing the old path)* | — | E1 | writing-docs | default | ⬜ todo |

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/adr-conventions.md` — created from migrated `framework/spec-workflows/adr-conventions.md` content.
- `framework/spec-workflows/spec-lifecycle.md` — absorbs anti-skip rules + Visualize/Split sub-step trigger rules from `spec-workflows/README.md`.
- `framework/spec-workflows/README.md` — slimmed to TOC.
- `framework/spec-workflows/adr-conventions.md` — removed.

## Rollout / migration notes

- Closure order with siblings: this spec consolidates lifecycle content INTO `spec-lifecycle.md`; siblings B (skill bodies) and C (prompts) REMOVE lifecycle content from their files and point at `spec-lifecycle.md`. There is no hard ordering constraint — either side can land first — but reviewing in this order makes the diff clearest: E first (absorption), then B/C (removal).
- ADR authors will follow a new path (`docs/adr-conventions.md`) — communicate the move in the closure notes.
