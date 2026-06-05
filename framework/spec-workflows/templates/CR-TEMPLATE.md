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
---
<!--
Trivial-lane shortcut: if this CR touches ≤2 files, single repo, no schema/boundary/prompt change,
no depends-on:, and verifies with one AC — you may elect `risk: trivial` to collapse Specify+Plan
into one combined gate. Full eligibility, combined-gate body shape, and lane rules:
  framework/spec-workflows/spec-lifecycle.md#trivial-lane
Questions to ask (exactly 3, single round):
  framework/spec-workflows/questions/trivial-questions.md
If unsure — don't elect. Standard track is the safe default.
-->
# CR-YYYYMMDD-<title>
*Last updated: YYYY-MM-DD*
## Summary
- **Goal:** <One sentence.>
- **Scope:** <One short paragraph.>
- **Out of scope:** <One sentence.>
## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | <e.g., 200k-400k> |
| Human attention | <N gates>: <gate list>; <min/gate> |
| Re-Specify tripwire | <condition(s) that force re-Specify> |
## Problem Statement
<What problem does this solve? Evidence: current behavior, pain point, user report, or metric. If `domain-refs:` is omitted, justify in one line.>
## Requirements
- FR-1: The system MUST ...
## Acceptance Criteria
### AC-1: <scenario> (FR-1)
Given <precondition>
When <action>
Then <outcome>
## Architecture
<Fill during Visualize when triggered, else `Skipped — <reason>`. See docs/spec-templates-guide.md § Architecture.>
## Out of Scope
- OS-1: <item> — <reason>
## Split Decision
<Fill during Specify. See docs/spec-templates-guide.md § Split Decision.>
## Tasks
Pending — Plan stage only.
## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.
## Docs updates required
- <path> — <what changes>
## Rollout / migration notes
- <Any data migration, config change, or coordination required before merge.>
