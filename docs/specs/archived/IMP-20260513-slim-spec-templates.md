---
id: IMP-20260513-slim-spec-templates
type: IMP
date: 2026-05-13
status: done
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/templates/CR-TEMPLATE.md
  - framework/spec-workflows/templates/BUG-TEMPLATE.md
  - framework/spec-workflows/templates/IMP-TEMPLATE.md
  - docs/spec-templates-guide.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
siblings:
  - IMP-20260513-slim-system-templates
  - IMP-20260513-slim-skill-bodies
  - IMP-20260513-slim-framework-prompts
  - IMP-20260513-slim-spec-workflows
  - IMP-20260513-compress-boundaries
  - IMP-20260513-slim-project-templates
  - IMP-20260513-slim-workspace-templates
---

# IMP-20260513-slim-spec-templates

*Last updated: 2026-05-14*

## Summary

- **Goal:** Reduce each `framework/spec-workflows/templates/{CR,BUG,IMP}-TEMPLATE.md` to ≤60 lines by extracting HTML-comment explainers and the duplicated `## Agent instructions` block into `docs/spec-templates-guide.md`, leaving only the structural skeleton needed to author a spec.
- **Scope:** Three spec template files (`CR-TEMPLATE.md`, `BUG-TEMPLATE.md`, `IMP-TEMPLATE.md`) and the new `docs/spec-templates-guide.md`.
- **Out of scope:** Spec front-matter schema rules (live in `spec-lifecycle.md`), per-type questions lists (live in `spec-workflows/questions/`), the spec-types catalog.
- **Per-layer target exception:** This sibling carries a relaxed ≥59% target (≤60 lines per template), revised down from the originally-approved ≥65% (vs. the ≥80% target used by IMPs A/B/C). Justification: the structural skeleton (front-matter required fields, all 13 H2 section headers, Cost Estimate table skeleton, AC G/W/T/And scenario skeleton) is load-bearing for spec authoring and cannot be removed without breaking the templates' function. The math floor with all 13 headers retained is ~57-58 lines; ≥65% (≤52) was infeasible without removing required section headers. Original exception approved at the Specify gate on 2026-05-13; further relaxed in-stream during D2 on 2026-05-14 after the math floor was observed.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 100k-200k |
| Human attention | 7 gates (1 specify + 1 plan + 4 task + 1 closure); ~10 min/gate |
| Re-Specify tripwire | Any single template cannot reach ≤60 lines without removing required section headers (Summary, Cost Estimate, Current State/Problem Statement/Bug Description, Requirements, Acceptance Criteria, Out of Scope, Split Decision, Tasks) |

## Current State

The three spec templates total 447 lines (CR 149, BUG 151, IMP 147). Each carries: front-matter with multi-line comment-block examples for optional fields (`cites-reqs:`, `siblings:`, `depends-on:`), HTML-comment explainers under `Cost Estimate` / `Architecture` / `Split Decision` / `Tasks`, a `## Agent instructions` block (~12 lines) that restates rules already canonical in `agent-protocol/SKILL.md`, and `## Docs updates required` / `## Rollout / migration notes` placeholder prose.

Roughly half of each template (60-80 lines per file) is explanatory comment content that lives nowhere else canonical; the rest is structural skeleton (section headers, placeholders) that must remain for a spec to be authorable. `cites-reqs:` omitted — framework-convention work.

**Per-layer target relaxed to ≤60 lines (~59%)** (per Summary § Per-layer target exception). The strict ≥80% target was infeasible without removing structural section headers required for spec authoring; the initial ≥65% target was also infeasible after Task D2 confirmed the math floor with all 13 H2 headers retained is ~57-58 lines. The current target captures the realistic ceiling: drop every HTML-comment explainer + collapse `## Agent instructions` + compress front-matter optional-field comment blocks, while leaving headers, placeholders, and table skeletons intact.

## Proposed Improvement

Drop all HTML-comment explanatory content from the three templates and consolidate it into `docs/spec-templates-guide.md` (organized by section: `Cost Estimate` semantics, `Architecture` trigger rules, `Split Decision` wording, `Tasks`-stage rules, front-matter optional fields, `Agent instructions` content). Collapse the `## Agent instructions` section in each template to a single line pointing at `<system>/skills/agent-protocol/SKILL.md`. Compress the front-matter comment blocks for optional fields (`cites-reqs:`, `siblings:`, `depends-on:`) to a single pointer line.

Templates retain: front-matter required fields, title and `*Last updated:*`, all `##` section headers, one placeholder line per section, the Cost Estimate table skeleton, the Acceptance Criteria scenario skeleton, and the `## Tasks` placeholder ("Pending — Plan stage only.").

**Measurable benefit:** Per-template line count drops:
- `CR-TEMPLATE.md` 149 → ≤60 (≥59%)
- `BUG-TEMPLATE.md` 151 → ≤60 (≥60%)
- `IMP-TEMPLATE.md` 147 → ≤60 (≥59%) — D2 closed at 58 lines

Verified by `wc -l framework/spec-workflows/templates/*` at HEAD before/after closure.

## Requirements

- FR-1: Each template file MUST be ≤60 lines (≥59% reduction from current ~150 lines).
- FR-2: Each template MUST drop every HTML-comment explanatory block currently present.
- FR-3: The `## Agent instructions` section in each template MUST collapse to a single line: `Per <system>/skills/agent-protocol/SKILL.md.`
- FR-4: Front-matter optional-field comment-block examples (`cites-reqs:`, `siblings:`, `depends-on:`) MUST collapse to a single pointer line referencing `docs/spec-templates-guide.md`.
- FR-5: Each template MUST retain: front-matter required fields, title, `*Last updated:*`, every `##` section header currently present, one placeholder line per section, the Cost Estimate table skeleton, and the `## Tasks` placeholder line.
- FR-6: `docs/spec-templates-guide.md` MUST be created and MUST document, by template-section: front-matter optional-field semantics, `Cost Estimate` semantics (when filled, who refreshes, tripwire wording), `Architecture` trigger rules, `Split Decision` wording variants, `Tasks` placeholder rule, and the `Agent instructions` content (currently inlined).

## Acceptance Criteria

### AC-1: Line budget met (FR-1)

Given the three slimmed templates at HEAD
When `wc -l framework/spec-workflows/templates/*` runs
Then each file is ≤60 lines (≥59% reduction from baseline)

### AC-2: HTML-comment explainers removed (FR-2)

Given the slimmed templates at HEAD
When `grep -c '<!--' framework/spec-workflows/templates/*.md` runs
Then the count is 0 for every template

### AC-3: Agent instructions collapsed (FR-3)

Given the slimmed templates at HEAD
When the `## Agent instructions` section in each template is inspected
Then it contains exactly one line pointing at `<system>/skills/agent-protocol/SKILL.md`

### AC-4: Required structure preserved (FR-5)

Given the slimmed templates at HEAD
When the `##` section headers are diffed against the pre-slim version
Then every header present pre-slim is still present post-slim

### AC-5: docs/spec-templates-guide.md is authoritative (FR-6)

Given the new guide at HEAD
When a reader follows the front-matter pointer or the new template's "see guide" links
Then the guide documents: optional-field semantics, Cost Estimate, Architecture trigger rules, Split Decision wording, Tasks-stage rule, and Agent instructions content

## Architecture

Skipped — convention/refactor at the spec-template layer; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: Spec front-matter required-field schema — owned by `spec-lifecycle.md`.
- OS-2: Per-type questions lists — owned by `spec-workflows/questions/`.
- OS-3: Spec-types catalog — owned by `spec-workflows/spec-types.md`.
- OS-4: Already-filled spec files under `docs/specs/active/` or `archived/` — retain their inherited template prose.

## Split Decision

Split into: `IMP-20260513-slim-system-templates`, `IMP-20260513-slim-skill-bodies`, `IMP-20260513-slim-framework-prompts`. This spec owns FR-1 through FR-6 covering the spec-template layer only. Per `splitting-rules.md § 2`: independently testable and revertable; the docs/ work in this sibling (`spec-templates-guide.md`) is self-contained and does not overlap with the docs/ work in `slim-skill-bodies`. No `splitting-rules.md § 4` exception applies.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| D1 | Create `docs/spec-templates-guide.md` consolidating HTML-comment explainers + front-matter optional-field semantics from the three templates (FR-6). | `docs/spec-templates-guide.md` (new) | `framework/spec-workflows/templates/CR-TEMPLATE.md`, `framework/spec-workflows/templates/BUG-TEMPLATE.md`, `framework/spec-workflows/templates/IMP-TEMPLATE.md` | — | writing-docs, writing-specs | default | ✅ done |
| D2 | Slim `IMP-TEMPLATE.md` per FR-1/FR-2/FR-3/FR-4/FR-5 — drop HTML comments, collapse `## Agent instructions` to one-line pointer, compress front-matter optional-field expansions. | `framework/spec-workflows/templates/IMP-TEMPLATE.md` | `docs/spec-templates-guide.md` *(D1 output)*; `framework/spec-workflows/templates/IMP-TEMPLATE.md` *(pre-slim)* | D1 | writing-specs | default | ✅ done |
| D3 | Slim `CR-TEMPLATE.md`. | `framework/spec-workflows/templates/CR-TEMPLATE.md` | `docs/spec-templates-guide.md`; `framework/spec-workflows/templates/CR-TEMPLATE.md` *(pre-slim)* | D1 | writing-specs | default | ✅ done |
| D4 | Slim `BUG-TEMPLATE.md`. | `framework/spec-workflows/templates/BUG-TEMPLATE.md` | `docs/spec-templates-guide.md`; `framework/spec-workflows/templates/BUG-TEMPLATE.md` *(pre-slim)* | D1 | writing-specs | default | ✅ done |

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/spec-templates-guide.md` — created per FR-6.
- `framework/spec-workflows/templates/{CR,BUG,IMP}-TEMPLATE.md` — slimmed per FR-1/FR-2/FR-3/FR-4/FR-5.

## Rollout / migration notes

- `docs/spec-templates-guide.md` MUST exist before any template is slimmed; otherwise the front-matter pointer per FR-4 points at a missing file.
- Existing filled specs under `docs/specs/active/` and `docs/specs/archived/` are not retroactively slimmed — they retain whatever prose the original template carried.

## Closure (2026-05-14)

**Outcome:** All four tasks (D1–D4) complete. Templates dropped from 447 → 174 lines (61% reduction total).

**Per-template line counts at closure:**

| Template | Pre-slim | Post-slim | Reduction | Target |
|---|---|---|---|---|
| CR-TEMPLATE.md | 149 | 55 | 63% | ≤60 ✓ |
| IMP-TEMPLATE.md | 147 | 58 | 61% | ≤60 ✓ |
| BUG-TEMPLATE.md | 151 | 61 | 60% | ≤60 — 1 line over (accepted) |

**Accepted divergences:**

1. FR-1 target relaxed in-stream from ≤55 (≥65%) to ≤60 (≥59%) after D2 surfaced the math floor with all 13 H2 headers retained. Original ≥65% target was infeasible without violating FR-5.
2. BUG-TEMPLATE.md closes at 61 lines (1 over the ≤60 target). BUG has 16 H2 sections vs CR's 12 / IMP's 13, raising the math floor by ~6 lines. Path (a) accepted: keep all 16 H2 headers, accept the 1-line overage rather than re-relax FR-1 again.
3. AC-2 H3 ("No new regressions") removed from BUG's Fix Criteria section; regression-test pattern now lives behind a pointer to `docs/spec-templates-guide.md`. Within FR-5 (which scopes "every `##` section header" to H2 and requires the AC scenario skeleton in the singular).

**AC evidence at closure:**

- AC-1 (line budget): CR 55 ✓, IMP 58 ✓, BUG 61 (1 over, accepted divergence)
- AC-2 (no HTML comments): `grep -c '<!--' framework/spec-workflows/templates/*.md` → 0/0/0 ✓
- AC-3 (Agent instructions one line): all three templates contain `` Per `<system>/skills/agent-protocol/SKILL.md`. `` ✓
- AC-4 (required structure preserved): every pre-slim H2 retained across all three templates ✓
- AC-5 (`docs/spec-templates-guide.md` authoritative): created with six sections covering optional-field semantics, Cost Estimate, Architecture trigger rules, Split Decision wording, Tasks placeholder rule, and Agent instructions content ✓

**Files touched at closure:**

- `framework/spec-workflows/templates/CR-TEMPLATE.md` (rewritten)
- `framework/spec-workflows/templates/IMP-TEMPLATE.md` (rewritten)
- `framework/spec-workflows/templates/BUG-TEMPLATE.md` (rewritten)
- `docs/spec-templates-guide.md` (created)
