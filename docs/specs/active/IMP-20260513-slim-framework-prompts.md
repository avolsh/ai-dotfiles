---
id: IMP-20260513-slim-framework-prompts
type: IMP
date: 2026-05-13
status: plan
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/prompts/bug-triage.prompt.md
  - framework/prompts/create-spec.prompt.md
  - framework/prompts/plan-spec.prompt.md
  - framework/prompts/visualize-spec.prompt.md
affected-code: []
skills:
  - writing-specs
model-suggestion: default
siblings:
  - IMP-20260513-slim-system-templates
  - IMP-20260513-slim-skill-bodies
  - IMP-20260513-slim-spec-templates
  - IMP-20260513-slim-spec-workflows
  - IMP-20260513-compress-boundaries
  - IMP-20260513-slim-project-templates
  - IMP-20260513-slim-workspace-templates
depends-on:
  - IMP-20260513-slim-skill-bodies
---

# IMP-20260513-slim-framework-prompts

*Last updated: 2026-05-13*

## Summary

- **Goal:** Reduce each `framework/prompts/*.prompt.md` file by ≥80% by dropping inline lifecycle/process prose that duplicates the skill SKILL.md and `docs/` content, while keeping the concrete imperative steps that direct the agent through the prompt's workflow.
- **Scope:** Four prompt files (`bug-triage`, `create-spec`, `plan-spec`, `visualize-spec`).
- **Out of scope:** Project-scope prompts under `<project>/.github/copilot/prompts/`, the `#skill:` resolution mechanism, prompt frontmatter `description`.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 50k-100k |
| Human attention | 8 gates (1 specify + 1 plan + 5 task + 1 closure); ~5 min/gate |
| Re-Specify tripwire | Any single prompt cannot reach ≥80% reduction without removing a numbered imperative action step required for that workflow stage |

## Current State

Four framework prompts total 436 lines: `create-spec.prompt.md` 132, `plan-spec.prompt.md` 110, `bug-triage.prompt.md` 100, `visualize-spec.prompt.md` 94. Each prompt re-explains the lifecycle stage it runs, restates rules already in `writing-specs/SKILL.md` and `spec-workflows/spec-lifecycle.md`, inlines RFC 2119 / writing-style rules, and carries paragraphs of stage-detail prose that duplicate skill bodies.

Concretely: `create-spec.prompt.md` Step 4 (Split check) is ~22 lines of prose that paraphrases `splitting-rules.md § 2`; Steps 1-3 inline a file-list and section enumeration that the skill already owns; `## Hard rules` repeats lifecycle rules already in `spec-lifecycle.md`.

This sibling depends on `IMP-20260513-slim-skill-bodies` because the slimmed prompts will point at the slimmed SKILL.md + `docs/` files those tasks produce. `cites-reqs:` omitted — framework-convention work.

## Proposed Improvement

Reduce each prompt to: frontmatter + `#skill:` triggers + ≤3 lines of preconditions + ≤6 numbered action steps (one imperative line each, with markdown links to the canonical rule source instead of inlined text) + `## Hard rules` containing only rules unique to this prompt invocation.

Cross-references point at: skill SKILL.md (canonical for rules), `docs/<topic>.md` (canonical for prose, examples, walkthroughs), `framework/spec-workflows/spec-lifecycle.md` (canonical for gate semantics), `framework/spec-workflows/templates/*` (canonical for spec templates).

**Measurable benefit:** Per-prompt line count drops:
- `create-spec.prompt.md` 132 → ≤26 (≥80%)
- `plan-spec.prompt.md` 110 → ≤22 (≥80%)
- `bug-triage.prompt.md` 100 → ≤20 (≥80%)
- `visualize-spec.prompt.md` 94 → ≤19 (≥80%)

Verified by `wc -l framework/prompts/*.prompt.md` at HEAD before/after closure.

## Requirements

- FR-1: Each `framework/prompts/*.prompt.md` MUST be ≤30 lines.
- FR-2: Each prompt body MUST consist of: frontmatter, `#skill:` directives, brief preconditions block (≤3 lines), numbered action steps (≤6, one imperative line each), and a `## Hard rules` section (only prompt-unique rules — rules already in the cited skill SKILL.md MUST NOT be repeated).
- FR-3: Each prompt MUST NOT inline: lifecycle/stage explanations, split-rule reasoning, RFC 2119 keyword definitions, writing-style rules, or any content that the cited skill SKILL.md (post-IMP-B) or a `docs/<topic>.md` page covers.
- FR-4: Every markdown link in every slimmed prompt MUST resolve to an existing file at HEAD.
- FR-5: The frontmatter `description` field on each prompt MUST be preserved unchanged.

## Acceptance Criteria

### AC-1: Line budget met (FR-1)

Given the four slimmed prompts at HEAD
When `wc -l framework/prompts/*.prompt.md` runs
Then each file is ≤30 lines
And every file individually meets its ≥80% reduction target

### AC-2: No inlined skill/lifecycle prose (FR-3)

Given the slimmed prompts at HEAD
When the agent searches each file for content also present in `writing-specs/SKILL.md`, `spec-lifecycle.md`, or `splitting-rules.md`
Then no paragraph longer than one line is duplicated; references appear as markdown links only

### AC-3: No dangling links (FR-4)

Given the slimmed prompts at HEAD
When every markdown link in every prompt is resolved
Then every target file exists at HEAD

### AC-4: Frontmatter description preserved (FR-5)

Given each slimmed prompt at HEAD
When its frontmatter is diffed against the pre-slim version
Then the `description` field is byte-identical

## Architecture

Skipped — convention/refactor at the prompt layer; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: Project-scope prompts under `<project>/.github/copilot/prompts/` — out of `ai-dotfiles` scope.
- OS-2: The `#skill:` resolution mechanism (project-scope vs system-scope lookup) — unchanged.
- OS-3: Prompt frontmatter `description` content — preserved per FR-5.

## Split Decision

Split into: `IMP-20260513-slim-system-templates`, `IMP-20260513-slim-skill-bodies`, `IMP-20260513-slim-spec-templates`. This spec owns FR-1 through FR-5 covering the prompt layer only. Per `splitting-rules.md § 2`: independently testable and revertable. `depends-on: IMP-20260513-slim-skill-bodies` because prompt slim references SKILL.md + `docs/` content that sibling produces. No `splitting-rules.md § 4` exception applies.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**
> **Cannot start until `IMP-20260513-slim-skill-bodies` is `done`** (depends-on contract).

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| C1 | Slim `create-spec.prompt.md` — remove inlined lifecycle/split/RFC prose; cross-references point at slimmed SKILL.md + `docs/`. | `framework/prompts/create-spec.prompt.md` | `framework/skills/writing-specs/SKILL.md` *(slimmed by B)*; `framework/spec-workflows/spec-lifecycle.md`; `docs/spec-asking-questions.md` | — | writing-specs | default | ⬜ todo |
| C2 | Slim `bug-triage.prompt.md`. | `framework/prompts/bug-triage.prompt.md` | `framework/skills/writing-specs/SKILL.md` *(slimmed)*; `framework/spec-workflows/spec-lifecycle.md` | C1 | writing-specs | default | ⬜ todo |
| C3 | Slim `plan-spec.prompt.md`. | `framework/prompts/plan-spec.prompt.md` | `framework/skills/writing-specs/SKILL.md`, `framework/skills/model-selection/SKILL.md` *(both slimmed)*; `framework/spec-workflows/spec-lifecycle.md` | C1 | writing-specs | default | ⬜ todo |
| C4 | Slim `visualize-spec.prompt.md`. | `framework/prompts/visualize-spec.prompt.md` | `framework/skills/writing-specs/SKILL.md` *(slimmed)*; `framework/spec-workflows/spec-lifecycle.md` | C1 | writing-specs | default | ⬜ todo |
| C5 | Verify all cross-references resolve; grep evidence for no inlined skill/lifecycle prose remaining (FR-3, FR-4). | `framework/prompts/` *(all 4 prompts; verification only)* | `framework/skills/`, `framework/spec-workflows/`, `docs/` | C1, C2, C3, C4 | writing-specs | default | ⬜ todo |

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `framework/prompts/*.prompt.md` — slim per FR-1/FR-2/FR-3.
- No new `docs/` files in this sibling — consumes what `slim-skill-bodies` produces.

## Rollout / migration notes

- Closure of `IMP-20260513-slim-skill-bodies` MUST land before this spec's Plan stage starts; otherwise the cross-references this slim relies on do not yet exist.
- No downstream-project coordination needed.
