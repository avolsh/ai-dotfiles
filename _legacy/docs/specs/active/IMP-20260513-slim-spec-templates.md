---
id: IMP-20260513-slim-spec-templates
type: IMP
date: 2026-05-13
status: specify
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
---

# IMP-20260513-slim-spec-templates

*Last updated: 2026-05-13*

## Summary

- **Goal:** Reduce each `framework/spec-workflows/templates/{CR,BUG,IMP}-TEMPLATE.md` by ≥80% by extracting HTML-comment explainers and the duplicated `## Agent instructions` block into `docs/spec-templates-guide.md`, leaving only the structural skeleton needed to author a spec.
- **Scope:** Three spec template files (`CR-TEMPLATE.md`, `BUG-TEMPLATE.md`, `IMP-TEMPLATE.md`) and the new `docs/spec-templates-guide.md`.
- **Out of scope:** Spec front-matter schema rules (live in `spec-lifecycle.md`), per-type questions lists (live in `spec-workflows/questions/`), the spec-types catalog.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 100k-200k |
| Human attention | 3 gates: requirements, plan, closure; ~10 min/gate |
| Re-Specify tripwire | Any single template cannot reach ≥80% reduction without removing required section headers (Summary, Cost Estimate, Current State/Problem Statement/Bug Description, Requirements, Acceptance Criteria, Out of Scope, Split Decision, Tasks) |

## Current State

The three spec templates total 447 lines (CR 149, BUG 151, IMP 147). Each carries: front-matter with multi-line comment-block examples for optional fields (`cites-reqs:`, `siblings:`, `depends-on:`), HTML-comment explainers under `Cost Estimate` / `Architecture` / `Split Decision` / `Tasks`, a `## Agent instructions` block (~12 lines) that restates rules already canonical in `agent-protocol/SKILL.md`, and `## Docs updates required` / `## Rollout / migration notes` placeholder prose.

Roughly half of each template (60-80 lines per file) is explanatory comment content that lives nowhere else canonical; the rest is structural skeleton (section headers, placeholders) that must remain for a spec to be authorable. `cites-reqs:` omitted — framework-convention work.

**Risk flag for the human gate:** the chosen sibling target (`≥80% per layer`) may not be reachable for this layer without removing structural section headers, which would break the templates' core function. The Plan stage will measure the actual achievable reduction (likely 55-70%); if it falls short of 80%, the Re-Specify tripwire fires and the human decides whether to (a) accept a relaxed target for this layer or (b) trim more aggressively.

## Proposed Improvement

Drop all HTML-comment explanatory content from the three templates and consolidate it into `docs/spec-templates-guide.md` (organized by section: `Cost Estimate` semantics, `Architecture` trigger rules, `Split Decision` wording, `Tasks`-stage rules, front-matter optional fields, `Agent instructions` content). Collapse the `## Agent instructions` section in each template to a single line pointing at `<system>/skills/agent-protocol/SKILL.md`. Compress the front-matter comment blocks for optional fields (`cites-reqs:`, `siblings:`, `depends-on:`) to a single pointer line.

Templates retain: front-matter required fields, title and `*Last updated:*`, all `##` section headers, one placeholder line per section, the Cost Estimate table skeleton, the Acceptance Criteria scenario skeleton, and the `## Tasks` placeholder ("Pending — Plan stage only.").

**Measurable benefit:** Per-template line count drops:
- `CR-TEMPLATE.md` 149 → ≤30 (≥80% target; achievable contingent on Plan-stage validation)
- `BUG-TEMPLATE.md` 151 → ≤30 (≥80% target; achievable contingent on Plan-stage validation)
- `IMP-TEMPLATE.md` 147 → ≤30 (≥80% target; achievable contingent on Plan-stage validation)

Verified by `wc -l framework/spec-workflows/templates/*` at HEAD before/after closure.

## Requirements

- FR-1: Each template file MUST be ≤55 lines as a soft floor. Each template SHOULD be ≤30 lines if achievable without removing required section headers; if not, the Plan stage MUST document why the 80% target is unreachable and the Re-Specify tripwire fires.
- FR-2: Each template MUST drop every HTML-comment explanatory block currently present.
- FR-3: The `## Agent instructions` section in each template MUST collapse to a single line: `Per <system>/skills/agent-protocol/SKILL.md.`
- FR-4: Front-matter optional-field comment-block examples (`cites-reqs:`, `siblings:`, `depends-on:`) MUST collapse to a single pointer line referencing `docs/spec-templates-guide.md`.
- FR-5: Each template MUST retain: front-matter required fields, title, `*Last updated:*`, every `##` section header currently present, one placeholder line per section, the Cost Estimate table skeleton, and the `## Tasks` placeholder line.
- FR-6: `docs/spec-templates-guide.md` MUST be created and MUST document, by template-section: front-matter optional-field semantics, `Cost Estimate` semantics (when filled, who refreshes, tripwire wording), `Architecture` trigger rules, `Split Decision` wording variants, `Tasks` placeholder rule, and the `Agent instructions` content (currently inlined).

## Acceptance Criteria

### AC-1: Line budget met (FR-1)

Given the three slimmed templates at HEAD
When `wc -l framework/spec-workflows/templates/*` runs
Then each file is ≤55 lines
And the Plan-stage record states whether the ≥80% target (≤30 lines) was achievable; if not, the Re-Specify decision is recorded

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

Pending — Plan stage only.

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/spec-templates-guide.md` — created per FR-6.
- `framework/spec-workflows/templates/{CR,BUG,IMP}-TEMPLATE.md` — slimmed per FR-1/FR-2/FR-3/FR-4/FR-5.

## Rollout / migration notes

- `docs/spec-templates-guide.md` MUST exist before any template is slimmed; otherwise the front-matter pointer per FR-4 points at a missing file.
- Existing filled specs under `docs/specs/active/` and `docs/specs/archived/` are not retroactively slimmed — they retain whatever prose the original template carried.
