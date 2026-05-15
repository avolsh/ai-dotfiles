---
id: BUG-YYYYMMDD-<kebab-case-title>
type: BUG
date: YYYY-MM-DD
status: specify
owner: <github-handle>
severity: low | medium | high | critical
affected-repos:
  - <repo-name>
affected-code:
  - <path>
skills:
  - writing-specs
  - <project-testing-skill>
model-suggestion: default
# Optional fields (cites-reqs, siblings) — see docs/spec-templates-guide.md § Front-matter optional fields.
---
<!--
Trivial-lane shortcut: if this BUG touches ≤2 files, single repo, no schema/boundary/prompt change,
no depends-on:, and verifies with one AC (plus the standard "Reproduce & write failing test" task) —
you may elect `severity: trivial` to collapse Specify+Plan into one combined gate. Full eligibility,
combined-gate body shape, and lane rules:
  framework/spec-workflows/spec-lifecycle.md#trivial-lane
Questions to ask (exactly 3, single round):
  framework/spec-workflows/questions/trivial-questions.md
If unsure — don't elect. Standard track is the safe default.
-->
# BUG-YYYYMMDD-<title>
*Last updated: YYYY-MM-DD*
## Summary
- **Goal:** <One sentence describing what this bug spec is trying to fix.>
- **Scope:** <One short paragraph describing the defect and verification.>
- **Out of scope:** <One sentence describing related issues excluded.>
## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | <e.g., 50k-150k> |
| Human attention | <N gates>: <gate list>; <min/gate> |
| Re-Specify tripwire | <condition(s) that force re-Specify> |
## Bug Description
<One paragraph describing the incorrect behavior. If `cites-reqs:` is omitted, justify in one line.>
## Steps to Reproduce
1. <step>
## Expected Behavior
<What should happen.>
## Actual Behavior
<What actually happens. Paste errors/stack traces verbatim in fenced code blocks.>
## Environment
- <environment | branch/commit | date first observed | config — whatever is relevant>
## Root Cause
<Filled during Specify once investigation is complete. If unknown: "Under investigation" + list suspects.>
## Architecture
Skipped — isolated bug fix.
## Fix Criteria
### AC-1: Bug is fixed (regression test required — see docs/spec-templates-guide.md § BUG scenario skeleton)
Given <precondition>
When <action>
Then <expected outcome>
## Out of Scope
- OS-1: <related issues NOT fixed by this BUG spec>
## Split Decision
<Fill during Specify. See docs/spec-templates-guide.md § Split Decision.>
## Tasks
Pending — Plan stage only. Task 1 is always "Reproduce & write failing test".
## Agent instructions
Per `<system>/skills/agent-protocol/SKILL.md`.
## Docs updates required
- <path> — <what changes, if any>
## Rollout / migration notes
- <Data-repair or re-run steps if the bug corrupted data or output.>
