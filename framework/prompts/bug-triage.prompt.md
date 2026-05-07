---
description: "Specify stage for a BUG — reproduce and document the defect"
---
#skill:writing-specs
#skill:agent-protocol

You are running the **Specify stage for a BUG**. Same gates as the
Specify prompt for CRs, with a reproduction-first question list and a
mandatory "reproduce with failing test" first task.

Full process: [`<root>/.github/copilot/spec-workflows/README.md`](../spec-workflows/README.md).

## Preconditions

- User reports incorrect behavior (defect, regression, wrong output).
- For new features or enhancements, use `create-spec.prompt.md` instead.

## Step 1 — Load context

1. Target project's `.github/copilot-instructions.md` (or `AGENTS.md`).
2. `<root>/.github/copilot/spec-workflows/spec-types.md`.
3. `<root>/.github/copilot/spec-workflows/questions/bug-questions.md`.
4. Target project's `docs/architecture/module-map.md` (if it exists).
5. Target project's `docs/requirements/README.md` and any
   `docs/requirements/<feature>.md` baselines for the affected
   feature(s), if `docs/requirements/` exists. These hold existing
   functional requirements, invariants, and out-of-scope items that the
   BUG may cite, change, or supersede via `cites-reqs:`.

## Step 2 — Ask questions

Ask **≤10 questions** from `bug-questions.md` plus any bug-specific ones.
Start with reproduction (Q1). Confirm any reproduction steps already
supplied rather than re-asking. Stop and wait for answers before writing
any spec content.

**Mandatory every round:** Q2 (Multi-defect). Independent defects MUST
become separate BUG specs — the answer drives Step 3 below.

## Step 3 — Create the BUG spec(s)

After answers are received, determine spec count from the Multi-defect
answer (Q2):

- **Single defect** → create one BUG spec.
- **Multiple independent defects** → create one BUG spec per defect,
  same date prefix, cross-linked via `siblings:` front-matter. Apply
  [`splitting-rules.md § 5`](../skills/writing-specs/references/splitting-rules.md)
  for the cross-link format.

For each spec:

1. Copy [`<root>/.github/copilot/spec-workflows/templates/BUG-TEMPLATE.md`](../spec-workflows/templates/BUG-TEMPLATE.md)
   to `<project>/docs/specs/active/`.
2. File name: `BUG-YYYYMMDD-<kebab-case-title>.md` (today's date).
3. Fill front-matter: `id`, `date`, `status: specify`, `owner`, `severity`,
   `affected-repos`, `affected-code`, `skills`, `model-suggestion`,
   plus `siblings:` when split.
4. Write `## Summary` directly after the `*Last updated:*` line with
   exactly three bullets: `Goal`, `Scope`, and `Out of scope`.
5. Write `## Bug Description`, `## Steps to Reproduce`, `## Expected
   Behavior`, `## Actual Behavior`, `## Environment`, `## Root Cause`
   (or "Under investigation"), `## Fix Criteria` (AC-1 = bug fixed,
   AC-2 = no new regressions), `## Out of Scope`.
6. Fill `## Split Decision`:
   - Single: *"Single defect."*
   - Split: *"Split into: `<sibling-BUG-ids>`. This spec owns the
     `<defect-name>` defect."*
7. Leave `## Architecture` as `Skipped — isolated bug fix` unless the
   fix requires architectural changes (rare).
8. **Leave `## Tasks` empty.** Plan happens after approval.

## Step 4 — Gate (hard stop)

Post a summary:

- Spec ID and path
- Severity and blast radius
- Suspected root cause
- Similar code paths that might share the bug
- `## Summary` present and aligned with the bug scope.
- Cited REQ-IDs (front-matter `cites-reqs:` list) — or `none —
  justified in Bug Description`.

**Wait for explicit human approval.** Do not flip status. Do not write
tasks. Do not touch code.

Only after the human approves, hand off to
[`plan-spec.prompt.md`](plan-spec.prompt.md).

## Hard rules

- Task 1 of any BUG plan is always "Reproduce & write failing test".
- The fix only lands in Task 2+, after a failing test exists.
- `status` stays at `specify` until the plan is approved.
- Never skip the question round. Even obvious bugs get one.
- Never bundle multiple independent defects into one BUG spec — the
  Multi-defect question (Q2) is mandatory every round.
- Never request the requirements gate without a filled `## Split
  Decision` section in every BUG spec.
