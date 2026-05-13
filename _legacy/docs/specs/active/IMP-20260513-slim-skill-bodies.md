---
id: IMP-20260513-slim-skill-bodies
type: IMP
date: 2026-05-13
status: specify
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/skills/agent-protocol/SKILL.md
  - framework/skills/bootstrapping-project/SKILL.md
  - framework/skills/model-selection/SKILL.md
  - framework/skills/writing-docs/SKILL.md
  - framework/skills/writing-specs/SKILL.md
  - framework/skills/writing-specs/references/acceptance-criteria-patterns.md
  - framework/skills/writing-specs/references/baseline-citations.md
  - framework/skills/writing-specs/references/bounded-autonomy-rules.md
  - framework/skills/writing-specs/references/questions-technique.md
  - framework/skills/writing-specs/references/req-id-lifecycle.md
  - framework/skills/writing-specs/references/spec-format-guide.md
  - framework/skills/writing-specs/references/splitting-rules.md
  - framework/skills/agent-protocol/references/protocol-reference.md
  - framework/skills/bootstrapping-project/references/scaffold-manifest.md
  - framework/skills/writing-docs/references/glossary-template.md
  - docs/
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
siblings:
  - IMP-20260513-slim-system-templates
  - IMP-20260513-slim-framework-prompts
  - IMP-20260513-slim-spec-templates
---

# IMP-20260513-slim-skill-bodies

*Last updated: 2026-05-13*

## Summary

- **Goal:** Reduce each `framework/skills/*/SKILL.md` body by ≥80%, moving prose-shaped content to topic-organized files under `ai-dotfiles/docs/`, while preserving the YAML frontmatter that drives harness skill triggering.
- **Scope:** Five SKILL.md files (`agent-protocol`, `bootstrapping-project`, `model-selection`, `writing-docs`, `writing-specs`) and their prose-shaped `references/*.md` files.
- **Out of scope:** `framework/skills/.system/` (upstream-mirrored), SKILL.md YAML frontmatter, machine-lookup reference files (rule tables with IDs, decision matrices).

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 200k-400k |
| Human attention | 3 gates: requirements, plan, closure; ~10 min/gate |
| Re-Specify tripwire | Any single SKILL.md cannot reach ≥80% reduction without removing its `## When to use` block or breaking its frontmatter trigger description |

## Current State

The five user-loadable skills total 942 lines of SKILL.md (`agent-protocol` 292, `writing-specs` 175, `bootstrapping-project` 181, `writing-docs` 119, `model-selection` ~175). Each body mixes three audiences: short trigger guidance (load-bearing for the harness), rule statements (referenced by prompts and templates), and explanatory prose (lifecycle restatement, RFC 2119 keyword tables, writing-style rules, walk-throughs, examples, anti-patterns).

The same lifecycle/rule content also lives in `framework/spec-workflows/README.md`, `framework/spec-workflows/spec-lifecycle.md`, the three system templates (per `IMP-20260513-slim-system-templates`), and the four framework prompts — eight locations total.

Prose-shaped reference files compound the problem: `framework/skills/writing-specs/references/` carries 7 files (~700 lines) mixing rationale prose with machine-checkable rule tables; `agent-protocol/references/protocol-reference.md` (~280 lines) is pure prose; `writing-docs/references/glossary-template.md` and `bootstrapping-project/references/scaffold-manifest.md` are mixed.

`cites-reqs:` omitted — framework-convention work, no project requirements baselines touched.

## Proposed Improvement

Each `framework/skills/<name>/SKILL.md` becomes: YAML frontmatter + `## When to use` (≤8 bullets) + `## References` (markdown link list pointing at `docs/<topic>.md` for prose and to retained `references/*.md` files for machine-lookup tables). Prose currently in SKILL.md bodies and in prose-shaped `references/*.md` files moves to topic-organized files under `ai-dotfiles/docs/`. Machine-lookup files (rule-ID tables, decision matrices) remain under `framework/skills/<name>/references/`.

Topic-organized `docs/` files created (subject to Plan-stage refinement):
- `docs/spec-asking-questions.md` (from `questions-technique.md`)
- `docs/spec-format.md` (from `spec-format-guide.md`)
- `docs/baseline-citations.md` (from `baseline-citations.md` prose)
- `docs/req-id-lifecycle.md` (from `req-id-lifecycle.md`)
- `docs/acceptance-criteria-patterns.md` (from `acceptance-criteria-patterns.md`)
- `docs/bounded-autonomy.md` (rationale half of `bounded-autonomy-rules.md`; matrix half stays)
- `docs/splitting-specs.md` (rationale half of `splitting-rules.md`; § 2/3 trigger tables stay)
- `docs/agent-protocol.md` (prose half of `agent-protocol/SKILL.md` + `protocol-reference.md`; canonical rules stay in SKILL.md)
- `docs/writing-glossary.md` (from `writing-docs/glossary-template.md`)
- `docs/writing-specs.md` (consolidated overview pointing into the topic pages)

**Measurable benefit:** Per-file SKILL.md line count drops:
- `agent-protocol/SKILL.md` 292 → ≤30 (≥89%)
- `writing-specs/SKILL.md` 175 → ≤30 (≥82%)
- `bootstrapping-project/SKILL.md` 181 → ≤30 (≥83%)
- `writing-docs/SKILL.md` 119 → ≤24 (≥79% — target 25 to clear bar)
- `model-selection/SKILL.md` ≤30 lines

Verified by `wc -l framework/skills/*/SKILL.md` at HEAD before/after closure.

## Requirements

- FR-1: Each `framework/skills/<name>/SKILL.md` MUST be ≤35 lines.
- FR-2: SKILL.md body MUST consist of: YAML frontmatter, `## When to use` (≤8 bullets), `## References` (markdown link list). No other section headers permitted.
- FR-3: SKILL.md YAML frontmatter fields `name`, `description`, and (where present) `source` MUST be preserved verbatim — they drive harness skill triggering.
- FR-4: Prose-shaped content currently in SKILL.md bodies (lifecycle restatement, stage details, writing-style rules, RFC 2119 keyword tables, walk-throughs, examples, anti-patterns, self-review checklists) MUST move to topic-organized files under `ai-dotfiles/docs/`.
- FR-5: Prose-shaped reference files currently in `framework/skills/<name>/references/*.md` MUST move to topic-organized files under `ai-dotfiles/docs/`.
- FR-6: Machine-lookup files (`splitting-rules.md` § 2/3 trigger tables, `bounded-autonomy-rules.md` decision matrix, `scaffold-manifest.md` manifest data) MUST remain under `framework/skills/<name>/references/` in machine-readable form (tables only, no surrounding prose).
- FR-7: Each new `docs/*.md` file MUST carry a `*Last updated: 2026-05-13*` line and a one-line purpose statement immediately under the H1 title.
- FR-8: Cross-references from SKILL.md to docs/ and to retained references/ MUST resolve to actual files at HEAD (no dangling links).
- FR-9: Content is organized by topic, not by skill ownership — a single topic file MAY be cited from multiple SKILL.md files.

## Acceptance Criteria

### AC-1: SKILL.md line budget met (FR-1, FR-2)

Given the five slimmed SKILL.md files at HEAD
When `wc -l framework/skills/*/SKILL.md` runs (excluding `.system/`)
Then each file is ≤35 lines
And every file individually meets its ≥80% reduction target listed under Measurable benefit

### AC-2: Frontmatter preserved (FR-3)

Given each slimmed SKILL.md at HEAD
When the YAML frontmatter is diffed against the pre-slim version
Then `name`, `description`, and (where present) `source` are byte-identical

### AC-3: Prose moved to docs/ (FR-4, FR-5, FR-7)

Given the prose-move complete at HEAD
When the agent searches `framework/skills/` for paragraphs of prose (heuristic: any `*.md` file >40 lines that is not a machine-lookup table file)
Then no matches remain
And every named topic file under `ai-dotfiles/docs/` exists with a Last-updated line and a purpose statement

### AC-4: Machine-lookup retained (FR-6)

Given the slim complete at HEAD
When `splitting-rules.md`, `bounded-autonomy-rules.md`, and `scaffold-manifest.md` are inspected
Then each file contains only structured tables / decision matrices / manifest data — no rationale prose paragraphs

### AC-5: No dangling cross-references (FR-8)

Given the slimmed SKILL.md and prompt files at HEAD
When every markdown link in `framework/skills/*/SKILL.md` is resolved
Then every target file exists at HEAD

## Architecture

Skipped — convention/refactor at the skill-documentation layer; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: `framework/skills/.system/` (upstream-mirrored skill catalog: `skill-creator`, `plugin-creator`, `skill-installer`, `openai-docs`, `imagegen`) — left alone.
- OS-2: SKILL.md YAML frontmatter content — preserved verbatim per FR-3.
- OS-3: Machine-lookup reference files (rule tables, decision matrices, manifests) — retained per FR-6.
- OS-4: `docs/requirements/` at any scope — unrelated mechanism.
- OS-5: Project-scope skills under any `<project>/.github/copilot/skills/` — out of `ai-dotfiles` scope.

## Split Decision

Split into: `IMP-20260513-slim-system-templates`, `IMP-20260513-slim-framework-prompts`, `IMP-20260513-slim-spec-templates`. This spec owns FR-1 through FR-9 covering the skill-documentation layer only. Per `splitting-rules.md § 2`: each sibling layer is independently testable and revertable. This sibling carries the docs/ consolidation foundation; `slim-framework-prompts` depends on this sibling because prompts point at the slimmed SKILL.md + docs/ files. No `splitting-rules.md § 4` exception applies.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `ai-dotfiles/docs/` — create the topic-organized files listed under Proposed Improvement (Plan-stage tasks will refine names and partition).
- `framework/skills/<name>/SKILL.md` — slim per FR-1 / FR-2.
- `framework/skills/<name>/references/*.md` — prose files removed; machine-lookup files retained per FR-6.

## Rollout / migration notes

- Plan-stage task ordering MUST sequence: (1) create `docs/` topic files, (2) slim SKILL.md bodies to point at them, (3) delete the migrated `references/*.md` prose files. Skipping step 1 leaves dangling references during the slim.
- `IMP-20260513-slim-framework-prompts` depends on this spec — keep that closure ordering.
