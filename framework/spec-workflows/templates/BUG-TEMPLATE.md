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
# cites-reqs:             # uncomment when the broken behavior is described by an existing baseline REQ-ID
#   - REQ-PCE-007                                            # numeric ID from a baseline file
#   - requirements/place-catalog-enrichment.md#invariants    # path-anchor reference
# siblings:               # uncomment when multiple independent defects are split across BUG specs
#   - <spec-id>
---

# BUG-YYYYMMDD-<title>

*Last updated: YYYY-MM-DD*

## Summary

- **Goal:** <One sentence describing what this bug spec is trying to fix.>
- **Scope:** <One short paragraph or bullet sentence describing the defect, affected behavior, and verification covered by this spec.>
- **Out of scope:** <One sentence describing the most important related issues excluded from this fix.>

## Cost Estimate

<!--
Filled at Specify (create-spec.prompt.md Step 3) and refreshed at Plan
(plan-spec.prompt.md Step 5) against the approved task count. Sets
expectations consistently across specs. Re-Specify tripwire describes
the condition that forces returning the spec to Specify rather than
absorbing scope creep silently (e.g., the defect turns out to span
multiple bounded contexts, or root cause requires a baseline change).
-->

| Estimate | Value |
|---|---|
| Token range | <e.g., 50k-150k> |
| Human attention | <N gates>: <gate list>; <minutes per gate> |
| Re-Specify tripwire | <condition(s) that force re-Specify> |

## Bug Description

<Clear one-paragraph description of the incorrect behavior. If
`cites-reqs:` is omitted in the front-matter, justify here in one line
(typically: "behavior is not yet captured in a baseline file" — and add
the baseline at closure if appropriate).>

## Steps to Reproduce

1. <step>
2. <step>
3. <step>

## Expected Behavior

<What should happen.>

## Actual Behavior

<What actually happens. Include error messages, stack traces, or
sample data. Paste verbatim inside fenced code blocks.>

## Environment

- Environment: local | CI | production
- Branch / commit: <ref>
- Date first observed: YYYY-MM-DD
- Config: <provider, batch size, feature flags — whatever is relevant>

## Root Cause

<Filled during the Specify stage once investigation is complete.
If root cause is unknown, write "Under investigation" and list the
suspects.>

## Architecture

<!--
Usually skipped for bugs. Fill only if the fix requires architectural
changes (e.g., the bug reveals a boundary violation). Otherwise:
  Skipped — isolated bug fix
-->

Skipped — isolated bug fix

## Fix Criteria

### AC-1: Bug is fixed

Given <precondition>
When <action>
Then <expected outcome>
And a regression test exists that fails before the fix and passes after

### AC-2: No new regressions

Given the existing test suite
When the fix is applied
Then all previously-passing tests still pass

## Out of Scope

- OS-1: <related issues that are NOT fixed by this BUG spec>

## Split Decision

<!--
Filled during the Specify-stage Multi-defect check. One of:
- Single defect.
- Split into: <sibling-BUG-ids>. This spec owns the <defect-name> defect.
-->

<fill during Specify>

## Tasks

<!-- Filled during the Plan stage. While status is `specify`, keep this section as a single placeholder line. When the spec moves to `plan`, replace it with the task table; Task 1 for a BUG is always "Reproduce & write failing test". -->

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

- <path> — <what changes, if any>

## Rollout / migration notes

- <Data-repair or re-run steps if the bug corrupted data or output.>
