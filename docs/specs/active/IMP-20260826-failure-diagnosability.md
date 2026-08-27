---
id: IMP-20260826-failure-diagnosability
type: IMP
date: 2026-08-26
status: specify
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/skills/handling-external-failures/SKILL.md
  - framework/skills/configuring-applications/SKILL.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
---
# IMP-20260826-failure-diagnosability
*Last updated: 2026-08-27*

## Summary
- **Goal:** Keep the one piece of information that identifies a cause — the upstream message at a boundary, the resolved value in a configuration — instead of only the class it belongs to.
- **Scope:** Two paragraphs: one in `handling-external-failures` on carrying a provider's own message through a permanent failure, one in `configuring-applications` on observing a setting where the process reads it.
- **Out of scope:** Logging, telemetry and error-reporting conventions; the classification rules themselves, which were correct in the incident below.

## Current State
`handling-external-failures` requires a boundary result to be classified before it is stored, and warns against collapsing outcomes. It says nothing about the provider's own account of a failure, and the omission reads as permission to discard it.

During CR-20260825-catalog-media-studio a Mapillary adapter raised `Mapillary answered 400` and dropped the response body. The classification was **right** — a 400 is permanent, and the code said so. What was missing was orthogonal to class: Mapillary had written `Invalid OAuth access token - Cannot parse access token`, which names the cause outright. Two rounds of debugging went into probing the API by hand to recover a sentence the process had already been handed and thrown away.

The same incident exposed the configuration half. The suspect value was inspected first by reading `.env.local`, then through a shell pipeline; both misled, in opposite directions — the file read stripped quotes `dotenv` preserves, and the shell probe failed to strip quotes the loader removes. The decisive check was three lines that imported the settings module and printed the resolved value's length and prefix. `configuring-applications` covers where a value may come from and says nothing about how to see what a running process actually holds, so the obvious move — read the file — is the one that answers a different question.

## Proposed Improvement
Two additions, each one paragraph, each in the skill that already owns its half.

`handling-external-failures`: a permanent failure carries the provider's own message alongside its class, bounded in length. Class and cause are different information, and only class is reconstructible from the outcome — a caller told "permanent" can retry correctly and still not know what to fix.

`configuring-applications`: a configuration value is diagnosed from what the process resolved, never from the file it came from. Every layer between them — loader quoting rules, schema defaults, store merge, parse function — can change the value, so the source file answers a question nobody asked.

**Measurable benefit:** on the incident above, the first change puts the causal sentence in front of the operator at the first failure instead of the third probe; the second replaces two misleading diagnostics with the one that decided it.

## Requirements
- FR-1: `handling-external-failures` MUST state that a permanent failure carries the provider's own message beside its classification, and MUST say the message is bounded in length so a large error document cannot become the error.
- FR-2: That paragraph MUST say plainly that classification and cause are different information, so the addition is not read as a restatement of the three-outcome rule it sits beside.
- FR-3: `configuring-applications` MUST state that a configuration value is diagnosed from the value the process resolved rather than from its source file, and MUST name what sits between the two: loader quoting, declared defaults, store merge and any parse function.
- FR-4: Both additions MUST carry the incident's shape as their worked example, so a reader meets the rule as something that happened rather than as advice.

## Acceptance Criteria
### AC-1: A permanent failure keeps its cause (FR-1, FR-2)
Given `handling-external-failures/SKILL.md` at HEAD
When the failure-classification section is read
Then it requires the provider's message beside the class, bounds its length, and states that the two are different information

### AC-2: Configuration is diagnosed where it is read (FR-3)
Given `configuring-applications/SKILL.md` at HEAD
When the diagnosis guidance is read
Then it directs the reader to the resolved value and names the four layers that can differ from the source file

### AC-3: Both rules are grounded (FR-4)
Given both skills at HEAD
When each new paragraph is read
Then each carries a concrete failure it would have shortened, not a generic caution

### AC-4: Neither skill repeats the other's rule
Given both skills at HEAD
When each is searched for the other's statement
Then each rule appears in exactly one skill, per the framework's single-statement rule

## Design
Skipped — two paragraphs of rule text in existing skills; no structure, data flow, schema, pipeline step or UI surface is involved.

## Out of Scope
- OS-1: What a caller *does* with the message — display, log, or both — which is a product decision.
- OS-2: `boundaries.md`. The always-on rule there ("a caught failure must not be recorded as a settled outcome") is unaffected: this sharpens what a correctly classified failure carries.

## Split Decision
Kept as one. Both halves answer one question — what information identifies a cause, and what is lost by keeping only its class — and both were found in a single incident whose two dead ends were the same mistake at two layers. Split, each is a one-paragraph spec whose motivation lives in the other.

## Tasks
Pending — Plan stage only.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- Covered by `affected-docs`: the skill text is the deliverable.

## Rollout / migration notes
- No migration. Existing adapters are not audited by this spec; it states the rule new and revisited boundaries are written against.
