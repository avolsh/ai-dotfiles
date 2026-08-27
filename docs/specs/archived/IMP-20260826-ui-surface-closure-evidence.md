---
id: IMP-20260826-ui-surface-closure-evidence
type: IMP
date: 2026-08-26
status: done
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/spec-lifecycle.md
  - framework/skills/writing-specs/references/authoring-steps.md
  - docs/acceptance-criteria-patterns.md
  - docs/rule-canonical-map.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
---
# IMP-20260826-ui-surface-closure-evidence
*Last updated: 2026-08-27*

## Summary
- **Goal:** Stop a green test suite from standing as evidence for an acceptance criterion no test in it could have exercised.
- **Scope:** The closure gate's evidence rule — what a criterion phrased as an on-screen observation may be closed with, and how a spec declares that at Specify rather than discovering it at closure.
- **Out of scope:** Mandating any particular UI testing technology, and the review-after closure lane, which governs *who* approves rather than *what counts*.

## Current State
`spec-lifecycle.md` forbids flipping to `done` while any acceptance criterion lacks documented evidence, and says nothing about what evidence a criterion admits. In practice a passing `make build` is offered for all of them.

CR-20260825-catalog-media-studio closed its task table with 2 351 passing tests and five defects live on the surface it delivered: a tab reading a field the record never carried, so it reported zero references for every place in the corpus; a candidate grid rendering captions with no images because the provider was never asked for thumbnails; an empty grid whose one sentence stood for four different causes; ten rows each rendering the same link as though each led elsewhere. Every one is a claim about what appears on screen. Every test asserted on functions and route handlers. The suite was not weak — it was aimed elsewhere, and nothing in the spec said so.

The criteria themselves were already written as observations: *"When the operator opens the Google tab / Then the Embed iframes render, each photo shows its author and a working Maps link"*. That sentence names an observer and a screen, and no assertion in the repository could have failed for it.

## Proposed Improvement
Make the evidence rule follow the criterion's own grammar. An AC whose *When* is a person operating a surface is closed by a test that renders that surface, or by recorded manual evidence naming what was observed, by whom and when — never by a suite that cannot reach it. Declare it at Specify, where the criterion is written and the cost is a sentence, rather than at the closure gate where it is a renegotiation.

**Measurable benefit:** of CR-20260825's nine criteria, five (AC-1, AC-2, AC-4, AC-5, AC-9) are observation-shaped and none carried evidence able to fail; under this rule all five are identified at Specify and carry a declared evidence kind before Plan begins.

## Requirements
- FR-1: `spec-lifecycle.md § closure` MUST state that an acceptance criterion whose `When` describes a person operating a user-facing surface is closed only by a test that renders that surface or by recorded manual evidence, and that a suite which cannot reach the surface is not evidence for it.
- FR-2: Manual evidence MUST record what was observed, on which surface, by whom and on what date, so a later reader can weigh it rather than take it on trust.
- FR-3: `authoring-steps` MUST have the AC author mark each observation-shaped criterion at Specify with the evidence kind it will close under, so the obligation is visible before Plan decomposes anything.
- FR-4: `docs/acceptance-criteria-patterns.md` MUST show one observation-shaped criterion and the evidence that closes it, and MUST NOT restate the rule FR-1 states.

## Acceptance Criteria
### AC-1: The gate distinguishes reachable evidence from a green suite (FR-1)
Given `spec-lifecycle.md` at HEAD
When the closure row and its rules are read
Then an observation-shaped criterion is named, and a suite that cannot reach the surface is stated not to be evidence for it

### AC-2: Manual evidence is auditable (FR-2)
Given a spec closed on manual evidence
When a reader who was not present opens its Closure Evidence
Then the surface, the observation, the person and the date are all recorded

### AC-3: The obligation is visible at Specify (FR-3)
Given a spec at `status: specify` carrying an observation-shaped criterion
When the requirements gate is requested
Then that criterion already names the evidence kind it will close under

### AC-4: CR-20260825 reclassifies (FR-1, FR-3)
Given the nine criteria of CR-20260825-catalog-media-studio
When each is measured against the amended rule and the clause deciding it is cited
Then AC-1, AC-2, AC-4, AC-5 and AC-9 are identified as observation-shaped, and AC-3, AC-6, AC-7 and AC-8 stay closable by the suite

### AC-5: The pattern shows the rule without restating it (FR-4)
Given `docs/acceptance-criteria-patterns.md` at HEAD
When it is read beside `spec-lifecycle.md`
Then it carries one observation-shaped criterion with the evidence that closes it, and states the rule nowhere

## Design
Skipped — a rule-text change to four documents; no structure, data flow, schema, pipeline step or UI surface is involved.

## Out of Scope
- OS-1: Choosing a rendering-test technology. The rule states what evidence must reach, never how.
- OS-2: Retro-closing specs already archived on suite evidence.
- OS-3: The five defects CR-20260825 shipped — they are fixed in that spec's own work, and this one only governs how such a criterion is closed in future.

## Split Decision
Kept as one. FR-1 states the rule, FR-2 makes its weaker half auditable, FR-3 moves the cost to where it is cheap, and FR-4 is the worked example the framework requires beside a new rule. Split apart, FR-1 lands a gate nobody can satisfy legibly and FR-3 marks criteria against a rule that does not yet exist.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| 1 | State the evidence rule at the closure gate: a criterion whose `When` names a person operating a user-facing surface closes only on a test that renders that surface or on recorded manual evidence carrying observation, surface, person and date; a suite that cannot reach the surface is not evidence for it (FR-1, FR-2 → AC-1, AC-2). | `framework/spec-workflows/spec-lifecycle.md` | `framework/boundaries.md`; `docs/acceptance-criteria-patterns.md` | — | writing-specs, writing-docs | deep | ☑ done |
| 2 | Have the AC author mark each observation-shaped criterion with the evidence kind it will close under at § A step 8, linking Task 1's rule rather than restating it, so the obligation is visible before the requirements gate and before Plan decomposes anything (FR-3 → AC-3). | `framework/skills/writing-specs/references/authoring-steps.md` | `framework/prompts/create-spec.prompt.md`; `framework/spec-workflows/spec-lifecycle.md` | 1 | writing-specs, writing-docs | default | ☑ done |
| 3 | Add one observation-shaped criterion as a worked pattern beside the recorded manual evidence that closes it, carrying all four FR-2 fields so a reader can weigh it; link the rule, state it nowhere (FR-4 → AC-5, AC-2). | `docs/acceptance-criteria-patterns.md` | `framework/spec-workflows/spec-lifecycle.md`; `<workspace>/src/github.com/tobeverse/tobevisit-content/docs/specs/archived/CR-20260825-catalog-media-studio.md` | 1 | writing-docs | default | ☑ done |
| 4 | Register the new rule's verbatim phrases under R3 in the rule map, so `make lint-rules` fails any restatement outside `spec-lifecycle.md` — this is what makes AC-5's *states the rule nowhere* enforceable rather than advisory (FR-1, FR-4 → AC-5). | `docs/rule-canonical-map.md` | `scripts/lint-rules.py`; `framework/spec-workflows/spec-lifecycle.md` | 1, 3 | writing-docs | default | ☑ done |
| 5 | Measure CR-20260825's nine criteria against the amended rule citing the clause that decides each, confirm the 5/4 partition, record it and this spec's `## Closure Evidence` in the FR-2 shape, and run `make check` (AC-4). | `docs/specs/active/IMP-20260826-ui-surface-closure-evidence.md` | `<workspace>/src/github.com/tobeverse/tobevisit-content/docs/specs/archived/CR-20260825-catalog-media-studio.md`; `framework/spec-workflows/spec-lifecycle.md` | 1, 2, 3, 4 | writing-specs | default | ☑ done |


## Closure Evidence

| AC | Evidence |
|---|---|
| AC-1 | `framework/spec-workflows/spec-lifecycle.md` § Rules #5 at HEAD names the observation-shaped criterion and states that a suite unable to reach the surface is not evidence for it; the `in-progress → done` transition row points at it. |
| AC-2 | `docs/acceptance-criteria-patterns.md` § On-screen observation carries a worked Closure Evidence row with all four FR-2 fields, and states that a row missing the date or the observer is not evidence. |
| AC-3 | `framework/skills/writing-specs/references/authoring-steps.md` § A step 8 requires the evidence-kind mark on every observation-shaped criterion and withholds the requirements gate while one is unmarked. |
| AC-4 | Classification below; each row cites the clause that decides it. |
| AC-5 | `docs/rule-canonical-map.md` R13 tracks the three canonical sentences. Live-fire: pasting the exclusion clause into `docs/acceptance-criteria-patterns.md` produced `docs/acceptance-criteria-patterns.md:146:rule_duplicate:R13 …` and `make lint-rules` exited non-zero; reverting returned it to `OK (11 canonical rule(s); 35 phrase(s) tracked)`. |

### AC-4 — CR-20260825-catalog-media-studio, nine criteria measured

| AC | `When` clause | Deciding clause | Class |
|---|---|---|---|
| AC-1 | *the operator opens `#/catalog-places/:id/media`* | person operating a surface | observation-shaped |
| AC-2 | *the operator deletes each* | person operating a surface; `Then` asserts confirmation wording on screen | observation-shaped |
| AC-3 | *step-10 runs* | system action — pipeline step | suite |
| AC-4 | *the operator opens the Google tab* | person operating a surface | observation-shaped |
| AC-5 | *the operator opens the source panel for each* | person operating a surface | observation-shaped |
| AC-6 | *each is imported* | system action — no person named | suite |
| AC-7 | *each is uploaded* | system action — no person named | suite |
| AC-8 | *each is submitted* | system action — no person named | suite |
| AC-9 | *the operator enters the studio from each* | person operating a surface | observation-shaped |

Five observation-shaped (AC-1, AC-2, AC-4, AC-5, AC-9), four closable by the
suite (AC-3, AC-6, AC-7, AC-8). The spec's original count of four missed AC-9,
whose `When` names the operator as plainly as AC-1's; it was corrected at
Specify before Plan ran. Per OS-2 the archived spec is not reopened.

### Checks

`make check` green at closure: links-check, validate-specs (28 specs),
lint-rules (11 rules, 35 phrases), validate-anchors (73 fragment links), tests.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- Covered by `affected-docs`: the rule text is the deliverable.

## Rollout / migration notes
- Applies to specs reaching the closure gate after it lands; archived specs are not revisited.
