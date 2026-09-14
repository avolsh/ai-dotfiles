---
id: IMP-20260826-plan-file-count-realism
type: IMP
date: 2026-08-26
status: done
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/skills/writing-specs/references/authoring-steps.md
  - docs/writing-specs.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
---
# IMP-20260826-plan-file-count-realism
*Last updated: 2026-08-30*

## Summary
- **Goal:** Make the Plan-stage file cap measure something a planner can actually count, so a task row that overruns means over-bundling rather than a convention doing arithmetic behind the plan's back.
- **Scope:** `authoring-steps § C.3/C.5` — what the ≤5-files rule counts, and what a planner is told to exclude from it.
- **Out of scope:** Changing the cap's value, and the Plan-stage safety-net signals P1–P3, which measure a different thing.

## Current State
`authoring-steps § C.5` caps a task row at five files and § C.3 reads an overrun as over-bundling. Three consecutive specs have overrun for reasons that are not over-bundling, each logged at the time:

- **2026-08-25** — a predicate a contract test must execute cannot stay inside a private query builder.
- **2026-08-26 (earlier)** — a route-level refusal is not a schema claim, so its test belongs with the route harness.
- **2026-08-26 (CR-20260825-catalog-media-studio)** — `tobevisit-content` enforces one exported type per file through an export audit, so a use case returning a discriminated outcome and taking a config and a deps object costs **four** files decomposition saw as zero. T4 was planned at 5 and landed at 13; T7 at 4 and landed at 7.

Three witnesses in three specs is a property of the rule, not a series of misjudgements. The cost is not the overrun itself — it is that an honest signal has been trained to fire on noise, so the next real over-bundling will read like the last three false positives.

## Proposed Improvement
Say what the cap counts. A task's file budget covers the files the task **decides about**; it excludes files a project convention adds mechanically from a decision already counted — the one-type-per-file spillover of a type the row already owns, and the existing test file of a source file the row already owns. A row that exceeds five *after* that exclusion is the over-bundling § C.3 means, and stays a signal to split.

**Measurable benefit:** the three logged overruns reclassify — all three fall under the exclusion and none is over-bundling — so the cap's false-positive rate over the last three specs goes from 3/3 to 0/3, and the next overrun carries information again.

## Requirements
> **Tombstoned 2026-08-30 — FR-1, FR-2 and FR-4 were satisfied by `IMP-20260826-decomposition-and-staleness-procedures` (`done` 2026-08-27), whose FR-1, FR-2, FR-8 and FR-10 landed the same rule change in wider form.** They are recorded here for the audit trail, not carried. FR-3 alone survived it and is not carried either — see `## Closure Evidence`.

- ~~FR-1~~ *(superseded by `IMP-20260826-decomposition-and-staleness-procedures` FR-1)*: `authoring-steps § C.5` MUST state that the file budget counts files the task decides about, and MUST name the two mechanical exclusions: a file created only to satisfy a one-declaration-per-file convention for a declaration already counted, and the existing test file of a source file already counted.
- ~~FR-2~~ *(superseded by the same spec's FR-8)*: `authoring-steps § C.3` MUST say that an overrun is read as over-bundling only after FR-1's exclusions are applied, so the split signal keeps its meaning.
- FR-3 *(not carried — see `## Closure Evidence`)*: A task row that overruns for an excluded reason MUST record why in the row or beside the table, so a later reader can tell a deliberate exclusion from an oversight.
- ~~FR-4~~ *(superseded by the same spec's FR-10)*: `docs/writing-specs.md § Plan stage` MUST agree with § C.5 rather than restating the bare cap, per the framework's single-statement rule.

## Acceptance Criteria
### AC-1: The cap states what it counts (FR-1, FR-2)
Given `authoring-steps.md` at HEAD
When § C.3 and § C.5 are read together
Then the budget's unit is "files the task decides about", both exclusions are named, and the over-bundling reading is explicitly downstream of them

### AC-2: The three logged overruns reclassify (FR-1)
Given the three overruns named in `## Current State`
When each is measured against the amended rule
Then none of them exceeds five files, and each maps onto a named exclusion

### AC-3: An excluded overrun is legible afterwards (FR-3)
Given a task row that carries more than five files under an exclusion
When a reader who was not present opens the spec
Then the row or the text beside the table says which exclusion applies and why

### AC-4: The rule is stated once (FR-4)
Given `docs/writing-specs.md` and `authoring-steps.md`
When both are searched for the cap
Then one states it and the other points at that statement

## Design
Skipped — a rule-text change to two documents; no structure, data flow, schema, pipeline step or UI surface is involved.

## Out of Scope
- OS-1: The value of the cap. Whether five is the right number is a separate question from what it counts.
- OS-2: P1/P2/P3, which measure task count, context spread and dependency islands rather than file cost.

## Split Decision
Kept as one. FR-1 and FR-2 are two halves of one sentence's meaning, FR-3 is what makes the exclusion auditable, and FR-4 is the framework's own single-statement rule applied to the same edit. Splitting would leave the cap redefined in one file and restated unchanged in another.

## Tasks
None — the spec closed at `specify` without a Plan stage; the work it specified was already at HEAD. See `## Closure Evidence`.

## Closure Evidence
Closed 2026-08-30 without a Plan stage. `IMP-20260826-decomposition-and-staleness-procedures` was written the same day against the same improvements-log entries, reached `done` 2026-08-27, and landed this spec's rule change in wider form before this one left `specify`. Per [`spec-lifecycle.md § Rules #10`](../../../framework/spec-workflows/spec-lifecycle.md#depends-on-blocks-plan), an FR the closed work already satisfies is tombstoned in place rather than left standing.

| AC | Evidence at HEAD |
|---|---|
| AC-1 | Met, by a stronger rule than the one asked for. `authoring-steps.md § C` step 5 reads *"The ≤5 cap counts files the task decides about; the Files column lists every file the task writes."* and names **four** exclusions where FR-1 asked for two — barrel re-export, one-exported-type-per-file split, registry entry, and the test file of a file already listed. Step 3 no longer carries an independent file test: it defers to step 5's count, so the two cannot return opposite verdicts on one task. Registered as R14 in `docs/rule-canonical-map.md`, with the three superseded wordings tracked as revert tripwires. |
| AC-2 | Met in outcome, by a different mechanism than AC-2 predicted. Two of the three overruns map onto a named exclusion: the route-refusal test is *the test file of a file already listed*, and the export-audit spillover is the *one-exported-type-per-file split*. The third does not, and deliberately so — step 5 prices the private-builder case as a counted **decision** (*"A claim a contract test must execute cannot stay inside a private function"*), the opposite of an exclusion. The cap's false-positive rate still reaches 0/3, because decoupling the Files column from the cap means a row listing more than five files is not a split signal at all: *"The cap and the column measure different things."* |
| AC-3 | **Not met, and not carried.** No landed text requires a row to record which exclusion it used. The landed model largely dissolves the need — with the Files column listing every written file by design, a 13-file row is not an overrun and has nothing to justify — but the legibility FR-3 wanted is genuinely absent: a later reader sees 13 files and cannot tell decision count from convention spillover. Logged as a residual improvement (`docs/improvements-log.md`, 2026-08-30) rather than kept open as a one-FR spec. |
| AC-4 | Met. `docs/writing-specs.md § Plan stage` step 2 now reads *"max 5 **decisions** — a count that excludes files a project convention adds mechanically from a decision already in the row, see authoring-steps.md § C step 5"*, a pointer rather than a restatement. `docs/spec-workflow-guide.md § Stage 2` and both sites in `plan-spec.prompt.md` were brought into line in the same change (that spec's FR-9, FR-10), which this spec's FR-4 did not reach. |

Landed in commit `66e552e`, under `IMP-20260826-decomposition-and-staleness-procedures` T1, T3 and T6.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- Covered by `affected-docs`: the rule text is the deliverable.

## Rollout / migration notes
- No migration. Archived specs keep the file lists they were written with; the rule applies to specs planned after it lands.
