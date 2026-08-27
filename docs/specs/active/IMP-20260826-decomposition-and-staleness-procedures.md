---
id: IMP-20260826-decomposition-and-staleness-procedures
type: IMP
date: 2026-08-26
status: specify
owner: alex
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/skills/writing-specs/references/authoring-steps.md
  - framework/prompts/visualize-spec.prompt.md
  - framework/spec-workflows/spec-lifecycle.md
  - docs/rule-canonical-map.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
siblings:
  - IMP-20260826-spec-guard-and-validator-gaps
  - IMP-20260826-failure-diagnosability
  - IMP-20260826-ui-surface-closure-evidence
depends-on:
  - IMP-20260826-ui-surface-closure-evidence
---
# IMP-20260826-decomposition-and-staleness-procedures
*Last updated: 2026-08-27*

## Summary
- **Goal:** Close four procedure gaps that `improvements-log.md` has now recorded nine times between them, four of those for one gap in seven days.
- **Scope:** What the ≤5-file cap counts and what the Files column lists in `authoring-steps.md § C`; an adjudicated P-signal as an override rather than a re-run; a Split re-check at the end of the Visualize sub-step; a re-verification of `## Current State` when a spec's last `depends-on:` closes. Docs and prompts only.
- **Out of scope:** Any mechanized check over these rules; they stay procedural.

## Current State
Four gaps, each logged with the same shape — the procedure asks a question at a point where the answer is not yet knowable, or does not ask it at all.

**§ C.5 file counts.** Logged four times — 2026-08-20, 08-25 and twice on 08-26 — with four different causes: a barrel re-export beside each new exported type, a gateway registry plus its count assertion, a predicate a contract test must execute and therefore cannot leave inside a private builder, and a one-exported-type-per-file audit that charges a use case four extra files for one discriminated outcome. Measured overruns: T4 planned at 5 files landed at 13, T7 at 4 landed at 7. Four instances in four specs is not four misjudgements — the cap measures something these conventions make unmeasurable at plan time.

**§ C.6 safety net.** Logged 2026-08-26. P3 fired on a cluster the human had already ruled on at the Specify gate; § C.6 says to write no table and flip back to `specify`, which re-opens a question answered with the evidence in front of them. The net is written for signals Specify *missed* and cannot tell those from a signal Specify caught and the human overrode.

**Split check timing.** Logged 2026-08-15. The Split check runs before Visualize, so it runs before the file surface is knowable; Visualize has already loaded the affected code, making the incremental cost a file count.

**Stale `## Current State`.** Logged 2026-08-21. A spec written against a dependency goes stale the moment that dependency closes; that spec's Current State was corrected before the gate by luck, not by a step.


## Proposed Improvement
Each gap takes one to three sentences at a named location. The § C.5 fix changes what the cap *counts* rather than adding a checklist of project conventions the framework cannot know: the cap counts files a task decides about, while the Files column keeps listing every file the task writes. Measurable benefit: the four recorded overruns (5→13, 4→7, and two earlier) all consist of spillover from a decision the row already owns; target is zero further log entries attributing an overrun to a convention-driven file the task did not decide about.

## Requirements
- FR-1: `authoring-steps.md § C` step 5 MUST count against the ≤5-file cap only files the task decides about, excluding spillover a project convention adds mechanically from a decision already in the row — a barrel re-export, a one-type-per-file split of a type the task owns, a registry entry for a resource the task registers, and the test file of a file already listed.
- FR-2: `authoring-steps.md § C` step 5 MUST require the Files column to list every file the task writes, and MUST state that the cap and the column measure different things, so a row that exceeds 5 listed files is not by itself a split signal.
- FR-3: `authoring-steps.md § C` step 5 MUST state that a claim a contract test must execute cannot stay inside a private function, so "add a predicate to an existing private builder" is priced as extracting a module — a decision, and therefore counted.
- FR-4: `authoring-steps.md § C` step 6 MUST state that a P-signal whose cluster matches a trigger already adjudicated at the Specify gate is recorded as an override under `## Split Decision`, not re-run — the flip back to `specify` is for clusters the Split check never named.
- FR-5: `visualize-spec.prompt.md` MUST re-run the Split check at the end of the Visualize sub-step, before handing back to the requirements gate, and record any changed verdict under `## Split Decision`.
- FR-6: `spec-lifecycle.md` MUST require a spec carrying `depends-on:` to re-verify `## Current State` against the code when its last dependency reaches `done`, before it advances to `plan`.
- FR-7: Any rule statement FR-4 or FR-6 introduces that is referenced from a second file MUST carry an entry in `docs/rule-canonical-map.md`, so `make lint-rules` catches its duplication.

## Acceptance Criteria
### AC-1: The cap counts decisions, the column lists files (FR-1, FR-2, FR-3)
Given a Plan-stage task that introduces one use case returning a discriminated outcome, under a one-exported-type-per-file audit
When the agent applies § C.5
Then the Files column lists all seven files and the cap counts one decision, and no split is proposed on the file count alone

### AC-2: An adjudicated cluster is not re-litigated (FR-4)
Given the Specify gate recorded a `keep-as-one` override for cluster X, and P3 fires at Plan on cluster X
When the agent applies § C.6
Then it writes the task table and records the P3 firing as an override under `## Split Decision`, and `status` stays `plan`

### AC-3: A P-signal on a new cluster still stops the plan (FR-4)
Given P3 fires at Plan on a cluster no Specify trigger named
When the agent applies § C.6
Then no table is written and `status` flips to `specify`

### AC-4: Visualize re-checks the split it now has the evidence for (FR-5)
Given a spec whose Visualize sub-step loaded the affected code
When Visualize completes
Then `## Split Decision` carries a re-run verdict dated after the Visualize output, and the requirements gate summary reports it

### AC-5: A closing dependency forces re-verification (FR-6)
Given spec A carries `depends-on: [B]` and B flips to `done`
When A is advanced toward `plan`
Then `## Current State` is re-read against the code and re-dated before the flip, and a superseded FR is tombstoned rather than left standing

### AC-6: The framework's own checks stay green (FR-7)
Given the edits from FR-1…FR-6
When `make check` runs in `ai-dotfiles`
Then `links-check`, `validate-specs`, `lint-rules`, `validate-anchors` and `tests` all pass

## Design
Skipped — docs and prompts only; `risk: low`, no context, data flow, schema, pipeline step or UI surface changes.

## Out of Scope
- OS-1: Mechanizing the § C.5 file costs as a validator check — the counts are project conventions, and the validator is project-agnostic.
- OS-2: A per-project conventions file the framework could read for FR-1 — FR-1 removes the need by counting decisions instead of conventions.
- OS-3: The Plan-gate guard-inventory pre-check — belongs with the guard, in the sibling IMP-20260826-spec-guard-and-validator-gaps.
- OS-4: The `configuring-applications` diagnose-from-the-resolved-value note — owned by IMP-20260826-failure-diagnosability FR-3, which carries the same incident and the boundary half beside it.

## Split Decision
`depends-on: IMP-20260826-ui-surface-closure-evidence` — not a requirements dependency but a file lease. That spec edits `authoring-steps.md § A` (AC authoring) and `spec-lifecycle.md § closure`; this one edits `§ C` of the first and the `depends-on:` rule of the second. The sections are disjoint, the files are not, and the log records seven guard collisions in two days from exactly this shape left undeclared. Ordering it at creation costs one field; discovering it at the first edit costs a commented-out inventory and a restoration debt.

`keep-as-one` by **E5** (documentation corpus). All four FR clusters ship documentation files under one index, share a single closure metric (`make check` green plus the § C review pass), and the spec ships zero behavioural code change — `affected-code: []`. T1 would otherwise fire, since the four gaps are independently readable; splitting a four-sentence docs change four ways forces coordination of artifacts that share no live state.

## Tasks
Pending — Plan stage only.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- `framework/skills/writing-specs/references/authoring-steps.md` — § C steps 5 and 6; re-stamp `*Last updated:*`, currently 2026-08-13.
- `framework/prompts/visualize-spec.prompt.md` — Split re-check step.
- `framework/spec-workflows/spec-lifecycle.md` — `depends-on:` re-verification rule beside the existing Rule #10.
- `docs/rule-canonical-map.md` — entries per FR-7.

## Rollout / migration notes
- Procedure-only: no spec currently at `specify` or `plan` needs reworking, and no archived spec is re-opened.
- FR-6 first applies to whichever active spec next has a dependency close; none is pending in either project today.
