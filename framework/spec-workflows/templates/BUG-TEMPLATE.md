---
id: BUG-YYYYMMDD-<kebab-case-title>
type: BUG
date: YYYY-MM-DD
status: specify
owner: <github-handle>
severity: low | medium | high | critical
affected-repos:
  - <repo-name>
affected-docs:
  - <path>
affected-code:
  - <path>
skills:
  - writing-specs
  - <project-testing-skill>
model-suggestion: default
# Optional fields (domain-refs, siblings) — see docs/spec-templates-guide.md § Front-matter optional fields.
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
<!-- ≤6 lines total -->
- **Goal:** <One sentence describing what this bug spec is trying to fix.>
- **Scope:** <One short paragraph describing the defect and verification.>
- **Out of scope:** <One sentence describing related issues excluded.>
## Bug Description
<!-- ≤12 lines. -->
<One paragraph describing the incorrect behavior. If `domain-refs:` is omitted, justify in one line.>
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
## Design
Skipped — isolated bug fix.
## Fix Criteria
<!-- One Given/When/Then block per Fix-Criteria cluster, ≤6 lines each. -->
### AC-1: Bug is fixed (regression test required — see docs/spec-templates-guide.md § BUG scenario skeleton)
Given <precondition>
When <action>
Then <expected outcome>
## Out of Scope
<!-- One line per item. -->
- OS-1: <related issues NOT fixed by this BUG spec>
## Split Decision
<Fill during Specify. See docs/spec-templates-guide.md § Split Decision.>
## Tasks
Pending — Plan stage only. Task 1 is always "Reproduce & write failing test".
## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.
## Docs updates required
- <path> — <what changes, if any>
## Rollout / migration notes
- <Data-repair or re-run steps if the bug corrupted data or output.>
