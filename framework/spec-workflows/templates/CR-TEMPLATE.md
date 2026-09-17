---
id: CR-YYYYMMDD-<kebab-case-title>
type: CR
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
# Optional fields (domain-refs, siblings, depends-on) — see docs/spec-templates-guide.md § Front-matter optional fields.
# baseline-impact: none — <reason>   (instead of ## Baseline Deltas, when no docs/domain/ baseline changes)
---
# CR-YYYYMMDD-<title>
*Last updated: YYYY-MM-DD*
## Summary
<!-- ≤6 lines total -->
- **Goal:** <One sentence.>
- **Scope:** <One short paragraph.>
- **Out of scope:** <One sentence.>
## Problem Statement
<!-- ≤12 lines. Evidence: current behavior, pain point, metric. If `domain-refs:` omitted, justify in one line. -->
## Requirements
<!-- One line per FR. Multi-clause FR needs a one-line justification. -->
- FR-1: The system MUST ...
## Acceptance Criteria
<!-- One Given/When/Then block per FR / Fix-Criteria cluster, ≤6 lines each. -->
### AC-1: <scenario> (FR-1)
Given <precondition>
When <action>
Then <outcome>
## Design
<!-- Design Decisions sub-step first (spec-lifecycle.md § Design Decisions sub-step), then Visualize.
Both skipped? Replace this whole section body with one line: `Skipped — <reason>`. -->
### Decisions
<`Skipped — <reason>` when no Design Decisions trigger fires. Else one bullet per decision:
D1: <chosen approach> — rejected: <alternative> (<why>); <alternative> (<why>). Departure from the profile → link the proposed ADR.>
### Risks / Trade-offs
- <risk> → <mitigation>
### Open Questions
<Only questions answerable later without changing requirements, approach or tasks. `None.` when empty.>
<Visualize: Mermaid / Figma when triggered. See docs/spec-templates-guide.md § Design.>
## Baseline Deltas
<!-- How this spec changes `docs/domain/*.md`; `baseline-merge --apply` merges it at the closure gate.
No baseline changes? Delete this section and set `baseline-impact: none — <reason>` in front-matter.
One `###` per baseline file; keep only the blocks you use. REQ text states observable behaviour only.
See docs/spec-templates-guide.md § Baseline Deltas.
### docs/domain/<feature>.md
#### ADDED
- Under `### <baseline heading>`:
  - **MUST** <externally observable behaviour>. *(REQ-<PREFIX>-NNN)*
    - Scenario: Given <state> When <action> Then <observable result>
#### MODIFIED
- REQ-<PREFIX>-NNN — Why: <one line>
  - **MUST** <full replacement text>. *(REQ-<PREFIX>-NNN)*
    - Verified by: `<test path>`
#### REMOVED
- REQ-<PREFIX>-NNN — Reason: <why> — Migration: <what replaces it>
#### RENAMED
- FROM REQ-<PREFIX>-NNN TO REQ-<PREFIX>-NNN — Why: <one line>
-->
## Out of Scope
<!-- One line per item. -->
- OS-1: <item> — <reason>
## Split Decision
<Fill during Specify. See docs/spec-templates-guide.md § Split Decision.>
## Tasks
Pending — Plan stage only.
## Closure Evidence
<!-- Filled at the in-progress → done flip: one row per AC, first cell the AC ID. A `### Review` sub-section records the reviewer run or waiver. See docs/spec-templates-guide.md § Closure Evidence. -->
Pending — closure only.
## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.
## Docs updates required
- <path> — <what changes>
## Rollout / migration notes
- <Any data migration, config change, or coordination required before merge.>
