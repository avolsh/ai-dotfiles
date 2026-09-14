---
id: IMP-20260513-compress-boundaries
type: IMP
date: 2026-05-13
status: done
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/boundaries.md
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
  - IMP-20260513-slim-spec-workflows
  - IMP-20260513-slim-project-templates
  - IMP-20260513-slim-workspace-templates
---

# IMP-20260513-compress-boundaries

*Last updated: 2026-05-14*

## Summary

- **Goal:** Reduce `framework/boundaries.md` by ≥35% via prose compression while preserving every rule semantically intact.
- **Scope:** `framework/boundaries.md` only (90 lines).
- **Out of scope:** Adding, removing, weakening, or merging any rule. Moving rules to `docs/`. Changing the three-tier structure (Always do / Ask first / Never do). Changing the Escalation protocol section.
- **Per-file target (exception to global ≥80% rule):** 90 → ≤55 lines (≥38% reduction). The strict ≥80% target is **impossible** at this layer without removing rules. Every line in boundaries.md encodes a non-negotiable behavioral guarantee auto-loaded into every agent session. The realistic compression ceiling is phrasing-only.
- **"Ask first" boundary touch:** Changing `framework/boundaries.md` itself falls under `boundaries.md § Ask first #3` ("Changing spec templates, workflow definitions, or boundaries — these govern all future work"). The human instruction authoring this IMP is the granted permission, recorded here for closure traceability.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 30k-60k |
| Human attention | 5 gates (1 specify + 1 plan + 2 task + 1 closure); ~10 min/gate; boundary changes warrant close review |
| Re-Specify tripwire | 35% compression unreachable without changing any rule's semantic intent, OR any rule's semantic equivalence cannot be verified at the closure gate |

## Current State

`framework/boundaries.md` is 90 lines, auto-loaded into every agent session via `@boundaries.md` resolved from each system template (per sibling IMP-A). It carries three tiers of non-negotiable behavioral rules — **14 rules under "Always do"**, **5 rules under "Ask first"**, **9 rules under "Never do"** — plus an Escalation protocol section and a pointer to `bounded-autonomy-rules.md`.

Of today's first-prompt context for a Claude session (~242 lines including project files), `boundaries.md` is the second-largest contributor at 90 lines (37%). The contents are dense already — no obvious lifecycle/catalog duplication of the type that bloats system templates — but each rule carries explanatory prose, line-wrapping overhead, and occasional repetition (e.g., "spec-lifecycle.md" referenced inline in three rules with full path).

`cites-reqs:` omitted — framework-convention work, no project requirements baselines touched.

## Proposed Improvement

Apply prose compression strictly: tighten each rule statement to the shortest unambiguous phrasing; collapse the introductory blockquote ("Three tiers, severity increasing from top to bottom.") into a one-line note; trim parenthetical elaborations that don't change rule semantics; consolidate file-path references that repeat across rules. The three-tier structure stays. Every rule under each tier stays. The Escalation protocol section stays. The trailing pointer to `bounded-autonomy-rules.md` stays.

Target: 90 → ≤55 lines (≥38% reduction). A semantic-equivalence check (rule-by-rule diff at the closure gate) verifies no rule is dropped or weakened.

**Measurable benefit:** Line count drops 90 → ≤55 (≥38%). Verified by `wc -l framework/boundaries.md` at HEAD before/after closure, plus a rule-count check (14 + 5 + 9 = 28 rules total) that holds before and after.

## Requirements

- FR-1: `framework/boundaries.md` MUST be ≤55 lines after the slim.
- FR-2: The total rule count MUST equal 28 after the slim: 14 under "Always do", 5 under "Ask first", 9 under "Never do". Numbering MUST remain 1-indexed within each tier.
- FR-3: Every rule MUST retain its current semantic intent. The closure gate MUST present a rule-by-rule before/after diff demonstrating equivalence (compression of phrasing only — no weakening, no merging, no elision).
- FR-4: The three-tier structure (Always do / Ask first / Never do) MUST remain. The Escalation protocol section MUST remain.
- FR-5: Cross-references inside the slimmed file MUST resolve to existing files at HEAD (currently: `spec-workflows/spec-lifecycle.md`, `skills/agent-protocol/SKILL.md`, `skills/writing-specs/references/bounded-autonomy-rules.md`).

## Acceptance Criteria

### AC-1: Line budget met (FR-1)

Given the slimmed `boundaries.md` at HEAD
When `wc -l framework/boundaries.md` runs
Then the file is ≤55 lines
And the measurable benefit is verified: ≥38% reduction from 90 lines

### AC-2: Rule count preserved (FR-2)

Given the slimmed file at HEAD
When the rules under each tier are counted (numbered list items only)
Then "Always do" has exactly 14 items
And "Ask first" has exactly 5 items
And "Never do" has exactly 9 items

### AC-3: Semantic equivalence verified (FR-3)

Given the closure gate
When the human reviews the rule-by-rule before/after diff included in Closure Evidence
Then every rule's semantic intent is judged equivalent
(no rule deleted, no rule weakened, no rule merged with another, no rule's threshold or condition changed)

### AC-4: Structure intact (FR-4)

Given the slimmed file at HEAD
When the H2 headers are inspected
Then `## Always do`, `## Ask first`, `## Never do`, and `## Escalation protocol` are all present, in that order

### AC-5: Cross-references resolve (FR-5)

Given the slimmed file at HEAD
When every markdown link inside `framework/boundaries.md` is resolved
Then every target file exists at HEAD

## Design

Skipped — prose compression of a single file; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: Adding, removing, weakening, merging, or re-ordering any rule.
- OS-2: Moving rules to `docs/` — boundary rules MUST stay inlined (load into every session).
- OS-3: Changing the three-tier structure or the Escalation protocol section's wording.
- OS-4: Changing referenced file paths (`spec-lifecycle.md`, `agent-protocol/SKILL.md`, `bounded-autonomy-rules.md`).

## Split Decision

Kept as one sibling spec — single-file compression with a single, well-defined success metric. Per `splitting-rules.md § 2`: no trigger applies.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| F1 | Compress `framework/boundaries.md` prose; preserve all 28 rules semantically; produce a rule-by-rule before/after diff for closure evidence (FR-1, FR-2, FR-3). | `framework/boundaries.md` | `framework/boundaries.md` *(pre-slim)* | — | writing-docs | deep | ☑ done |
| F2 | Verify cross-references resolve; verify rule counts (14/5/9); verify three-tier + Escalation structure intact (FR-4, FR-5). | `framework/boundaries.md` *(verification only)* | `framework/spec-workflows/spec-lifecycle.md`; `framework/skills/agent-protocol/SKILL.md`; `framework/skills/writing-specs/references/bounded-autonomy-rules.md` | F1 | writing-docs | default | ☑ done |

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `framework/boundaries.md` — slimmed per FR-1/FR-2/FR-3/FR-4.

## Rollout / migration notes

- Boundaries.md is auto-loaded into every session via `@boundaries.md`; closure landing is immediate and global. Verify post-closure by starting a fresh Claude session and confirming the rules render correctly.
- Closure Evidence MUST include the rule-by-rule before/after diff (FR-3 / AC-3). This is the highest-attention verification step in this IMP and the reason its `risk` field is `medium` rather than `low`.
