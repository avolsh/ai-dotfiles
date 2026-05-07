---
id: IMP-YYYYMMDD-<kebab-case-title>
type: IMP
date: YYYY-MM-DD
status: specify
owner: <github-handle>
risk: low | medium | high
affected-repos:
  - <repo-name>
affected-docs:
  - <path>
affected-code:
  - <path>
skills:
  - writing-specs
  - <project-skill>
model-suggestion: default
# cites-reqs:             # uncomment when this spec touches existing baseline REQ-IDs
#   - REQ-PCE-005                                            # numeric ID from a baseline file
#   - requirements/place-catalog-enrichment.md#invariants    # path-anchor reference
# siblings:               # uncomment when split; list sibling spec IDs
#   - <spec-id>
# depends-on:             # uncomment when blocked on prerequisite specs
#   - <spec-id>
---

# IMP-YYYYMMDD-<title>

*Last updated: YYYY-MM-DD*

## Summary

- **Goal:** <One sentence describing what this spec is trying to achieve.>
- **Scope:** <One short paragraph or bullet sentence describing the requirements and artifacts covered by this spec.>
- **Out of scope:** <One sentence describing the most important explicit exclusions.>

## Cost Estimate

<!--
Filled at Specify (create-spec.prompt.md Step 3) and refreshed at Plan
(plan-spec.prompt.md Step 5) against the approved task count. Sets
expectations consistently across specs. Re-Specify tripwire describes
the condition that forces returning the spec to Specify rather than
absorbing scope creep silently.
-->

| Estimate | Value |
|---|---|
| Token range | <e.g., 200k-400k> |
| Human attention | <N gates>: <gate list>; <minutes per gate> |
| Re-Specify tripwire | <condition(s) that force re-Specify> |

## Current State

<What exists today. Why it needs improvement. Cite concrete evidence:
latency metrics, duplicate code counts, broken invariants, readability
complaints with file references. If `cites-reqs:` is omitted in the
front-matter, justify here in one line (typically: "net-new feature,
no existing baseline REQ-IDs").>

## Proposed Improvement

<What changes and why. Include a **measurable benefit** — this is the
distinguishing feature of an IMP. Without a measurable benefit, the
spec is either a CR (new feature) or a BUG (defect).>

**Measurable benefit:** <metric + baseline + target>

Examples:
- Step 04 batch processing time drops from ~18min to ≤ 10min for 10k items.
- Domain module type-coverage rises from 92% to 100% (no `any`).
- Number of cross-context deep imports drops from 14 to 0.

## Requirements

- FR-1: The system MUST ...
- FR-2: The system SHOULD ...

## Acceptance Criteria

### AC-1: <scenario> (FR-1)

Given <precondition>
When <action>
Then <outcome>
And the measurable benefit is verified: <how>

## Architecture

<!--
Fill this section during the Visualize sub-step if any of these apply:
- risk is medium or high
- the refactor crosses bounded contexts
- the refactor changes public module boundaries (barrel exports, ports)

Otherwise:
  Skipped — <reason>
-->

```mermaid
flowchart LR
    A[Replace with<br/>before/after view] --> B[...]
```

## Out of Scope

- OS-1: <item> — <reason>

## Split Decision

<!--
Filled during the Specify-stage Split check. One of:
- Kept as one spec — <E1|E2|E3|E4> <reason, referencing splitting-rules.md § 4>.
- Kept as one spec — no § 2 trigger matched.
- Split into: <sibling-id-1>, <sibling-id-2>. This spec owns FRs <N, M>.
-->

<fill during Specify>

## Tasks

<!-- Filled during the Plan stage. While status is `specify`, keep this section as a single placeholder line. Replace it with the approved task table only after the spec moves to `plan`. -->

Pending — Plan stage only.

## Agent instructions

**Before each task — post in chat (mandatory before any edit):**
- Task # being implemented
- Precedent files read (paths)
- Loaded skill files (full `SKILL.md` paths — system or project scope)

**After each task — before proceeding:**
- Run build/test per project `AGENTS.md` § Build and Run.
- Post **"The Bottom Line"** using the canonical format in
  `<root>/.github/copilot/skills/agent-protocol/SKILL.md`
  § The Bottom Line — canonical format, and wait for explicit human
  approval.
- Update the task row's Status column in this spec.

## Docs updates required

- <path> — <what changes>

## Rollout / migration notes

- <Any coordination, deploy order, or data reshaping.>
