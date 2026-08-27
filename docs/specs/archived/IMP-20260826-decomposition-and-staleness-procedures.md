---
id: IMP-20260826-decomposition-and-staleness-procedures
type: IMP
date: 2026-08-26
status: done
owner: alex
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/skills/writing-specs/references/authoring-steps.md
  - framework/prompts/visualize-spec.prompt.md
  - framework/prompts/plan-spec.prompt.md
  - framework/spec-workflows/spec-lifecycle.md
  - docs/writing-specs.md
  - docs/spec-workflow-guide.md
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

**Re-verified 2026-08-27**, on `IMP-20260826-ui-surface-closure-evidence` reaching `done` — the procedure FR-6 proposes, applied to this spec. All four gaps stand unchanged in their target files; the dependency's edits landed in `authoring-steps.md § A` step 8 and `spec-lifecycle.md § Rules #5`, disjoint from `§ C` and Rule #10 as `## Split Decision` predicted, so no FR is superseded and none is tombstoned. The re-read did surface three restatements the original FR set does not reach: `authoring-steps.md § C` step 3 states the cap a second time as a slice test (*"A slice spanning >5 files is over-bundled"*), and `plan-spec.prompt.md` restates both the cap (`## Hard rules`) and the safety-net flip-back (step 3) — the latter being the file the 2026-08-27 log entry names by name. Changing § C steps 5 and 6 alone would leave three sites asserting the rule this spec replaces. FR-8…FR-10 close that.


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
- FR-8: `authoring-steps.md § C` step 3 MUST express the over-bundling slice test in the same decision terms as step 5, so the slice test and the row cap cannot return opposite verdicts on one task.
- FR-9: `plan-spec.prompt.md` MUST match FR-1 and FR-4 at both sites the agent reads at Plan — its `## Hard rules` file cap restated in decision terms, and its step 3 safety-net instruction carrying the adjudicated-override carve-out rather than an unconditional flip back to `specify`.
- FR-10: The two secondary restatements of the cap — `docs/writing-specs.md § Plan stage` step 2 and `docs/spec-workflow-guide.md § Stage 2` step 1 — MUST be brought into line with FR-1 in the same change, so no file left in the corpus states the superseded form.

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

### AC-7: No file states the superseded cap or the unconditional flip-back (FR-8, FR-9, FR-10)
Given the edits from FR-1…FR-4 are applied
When the corpus is grepped for the cap and for the safety-net flip-back outside `framework/upstream/`
Then every remaining statement is in decision terms and every flip-back statement names the adjudicated-override exception, and `authoring-steps.md § C` steps 3 and 5 agree on one task

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

**P3 fired at Plan (2026-08-27) — recorded as an override, not a re-run.** The table below carries two chains that depend on nothing outside themselves: the Visualize re-check (T4) and the `depends-on:` re-verification rule (T5). They share no FR and no AC with the cap chain (T1–T3, T6), which is the signal P3 names. The cluster is the same one the human adjudicated at the Specify gate under E5 above, with all four clusters named — so per this spec's own FR-4 it is carried forward here rather than re-asked, and `status` stays `plan`. This is the second recorded instance of the shape the 2026-08-27 log entry describes; the first (`IMP-20260826-spec-guard-and-validator-gaps`) resolved identically by stopping at the gate. The Plan gate below re-surfaces it for confirmation.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| 1 | Make the cap count decisions rather than files at `§ C` steps 3 and 5: the cap excludes spillover a project convention adds mechanically from a decision already in the row (barrel re-export, one-type-per-file split, registry entry, test file of a listed file); the Files column still lists every file the task writes; the two measure different things, so >5 listed files is not itself a split signal; and a claim a contract test must execute cannot stay private, so adding it to a private builder is priced as extracting a module. Step 3's slice test restated in the same terms so the two cannot disagree on one task (FR-1, FR-2, FR-3, FR-8 → AC-1, AC-7). | `framework/skills/writing-specs/references/authoring-steps.md` | `framework/skills/writing-specs/references/splitting-rules.md`; `docs/writing-specs.md`; `docs/improvements-log.md` | — | writing-specs, writing-docs | deep | ☑ done |
| 2 | At `§ C` step 6, split the safety net by what the signal is evidence of: a P-signal whose cluster matches a trigger already adjudicated at the Specify gate is recorded as an override under `## Split Decision` and the table is written with `status` staying `plan`; the flip back to `specify` is reserved for clusters the Split check never named (FR-4 → AC-2, AC-3). | `framework/skills/writing-specs/references/authoring-steps.md` | `framework/skills/writing-specs/references/splitting-rules.md`; `docs/improvements-log.md` | 1 | writing-specs, writing-docs | deep | ☑ done |
| 3 | Bring `plan-spec.prompt.md` into line at both sites the agent actually reads at Plan — the `## Hard rules` file cap in decision terms, and step 3's safety-net instruction carrying the adjudicated-override carve-out instead of an unconditional flip back — linking Tasks 1 and 2 rather than restating them (FR-9 → AC-7). | `framework/prompts/plan-spec.prompt.md` | `framework/skills/writing-specs/references/authoring-steps.md` | 1, 2 | writing-specs, writing-docs | default | ☑ done |
| 4 | Re-run the Split check at the end of the Visualize sub-step, before the hand-back to the requirements gate, and record any changed verdict under `## Split Decision` — Visualize has already loaded the affected code, so the incremental cost is a file count (FR-5 → AC-4). | `framework/prompts/visualize-spec.prompt.md` | `framework/spec-workflows/spec-lifecycle.md`; `framework/skills/writing-specs/references/splitting-rules.md`; `framework/prompts/create-spec.prompt.md` | — | writing-specs, writing-docs | default | ☑ done |
| 5 | Require a spec carrying `depends-on:` to re-verify `## Current State` against the code when its last dependency reaches `done`, before it advances to `plan` — stated beside the existing Rule #10, with a superseded FR tombstoned rather than left standing, and each canonical sentence on one source line so its phrases can be tracked (FR-6 → AC-5). | `framework/spec-workflows/spec-lifecycle.md` | `framework/skills/writing-specs/references/authoring-steps.md`; `docs/rule-canonical-map.md`; `docs/improvements-log.md` | — | writing-specs, writing-docs | deep | ☑ done |
| 6 | Correct the two secondary restatements of the superseded cap so no file in the corpus still states it — `docs/writing-specs.md § Plan stage` step 2 and `docs/spec-workflow-guide.md § Stage 2` step 1 (FR-10 → AC-7). | `docs/writing-specs.md`; `docs/spec-workflow-guide.md` | `framework/skills/writing-specs/references/authoring-steps.md` | 1 | writing-docs | fast | ☑ done |
| 7 | Register the cap rule and the flip-back rule in the rule map with their canonical locations, verifying each tracked phrase sits on a single physical line of its canonical file before closure and live-firing `make lint-rules` against a pasted restatement — the 2026-08-27 lesson that a wrapped phrase is silently inert (FR-7 → AC-6). | `docs/rule-canonical-map.md` | `scripts/lint-rules.py`; `framework/skills/writing-specs/references/authoring-steps.md`; `framework/spec-workflows/spec-lifecycle.md`; `framework/prompts/plan-spec.prompt.md` | 1, 2, 3, 5, 6 | writing-docs | default | ☑ done |
| 8 | Close: grep the corpus outside `framework/upstream/` for the superseded cap and the unconditional flip-back and confirm every survivor is in decision terms, run `make check`, and record `## Closure Evidence` per AC — citing the grep output and the lint-rules live-fire rather than asserting them (AC-6, AC-7). | `docs/specs/active/IMP-20260826-decomposition-and-staleness-procedures.md` | `framework/skills/writing-specs/references/authoring-steps.md`; `framework/prompts/plan-spec.prompt.md`; `framework/prompts/visualize-spec.prompt.md`; `framework/spec-workflows/spec-lifecycle.md` | 1, 2, 3, 4, 5, 6, 7 | writing-specs, writing-docs | default | ☑ done |

## Closure Evidence

| AC | Evidence |
|---|---|
| AC-1 | `authoring-steps.md § C` step 5 at HEAD states that the ≤5 cap counts files the task decides about while the Files column lists every file the task writes, names the four convention-driven exclusions (barrel re-export, one-type-per-file split, registry entry, test file of a listed file), and states that a row listing more than 5 files is not by itself a split signal. The private-builder clause is present in the same step. Step 3 no longer carries an independent file test — it defers to step 5's count — so the two cannot return opposite verdicts on one task. |
| AC-2 | `authoring-steps.md § C` step 6 requires a fired signal to be read against `## Split Decision` first, and records a match with an already-adjudicated Specify trigger as an override with `status` staying `plan`. Exercised live on this spec: P3 fired at Plan on the T4/T5 chains, was recorded as an override under `## Split Decision` citing the E5 election, the table was written, and `status` stayed `plan`. |
| AC-3 | Same step, third sentence: the flip back to `specify` is reserved for clusters the Split check never named, and there the table is not written. `plan-spec.prompt.md` step 3 carries both branches. |
| AC-4 | `visualize-spec.prompt.md` step 5 re-runs the Split check against the now-loaded code and records the dated verdict under `## Split Decision` whether or not it changed; step 6's hand-back summary reports that verdict at the requirements gate. Not exercised on this spec — its `## Design` is `Skipped`, so Visualize never ran. |
| AC-5 | `spec-lifecycle.md § Rules #10` now requires `## Current State` re-verified against the code when the last `depends-on:` entry reaches `done`, and requires a superseded finding tombstoned in place rather than left standing. Exercised live on this spec before Plan: the re-read confirmed all four gaps unchanged, confirmed the dependency's edits landed in `§ A` step 8 and Rule #5 (disjoint, nothing tombstoned), and surfaced three restatements the original FR set did not reach — which became FR-8…FR-10. |
| AC-6 | `make check` green at closure: `links-check` (140 files), `validate-specs` (28 specs, 13 checks), `lint-rules` (13 rules, 45 phrases), `validate-anchors` (73 fragment links across 139 files), and all eight test suites. |
| AC-7 | Corpus grep outside `framework/upstream/` and `docs/specs/`: the only surviving `5 files` string is `authoring-steps.md:73`, the sentence stating that >5 listed files is *not* a split signal — no file states the superseded form. Both `plan → specify` statements (`plan-spec.prompt.md:15`, `authoring-steps.md:79`) name the adjudicated-override branch. |

### Rule-map live-fire (FR-7)

Pasting R14's and R15's canonical sentences into `docs/writing-specs.md` produced `docs/writing-specs.md:208:rule_duplicate:R14 …` and `docs/writing-specs.md:207:rule_duplicate:R15 …`, and `make lint-rules` exited non-zero; reverting returned `OK (13 canonical rule(s) + 1 agent(s); 45 phrase(s) tracked)`.

Per the 2026-08-27 lesson that `lint-rules.py` never checks a tracked phrase still exists where it is declared canonical, every phrase registered here was verified present on a single physical line with `grep -F` before closure, and every revert tripwire verified absent. That check surfaced an incidental find: R7's own first phrase — *"A spec with unmet `depends-on:` … until all listed siblings reach `done`."* — had been line-wrapped in `spec-lifecycle.md` and so matched nothing, exactly the R3 defect. Task 5's reflow of Rule #10 restored it; it is now present and guarded.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- `framework/skills/writing-specs/references/authoring-steps.md` — § C steps 5 and 6; re-stamp `*Last updated:*`, currently 2026-08-13.
- `framework/prompts/visualize-spec.prompt.md` — Split re-check step.
- `framework/spec-workflows/spec-lifecycle.md` — `depends-on:` re-verification rule beside the existing Rule #10.
- `framework/prompts/plan-spec.prompt.md` — `## Hard rules` cap wording and step 3 override carve-out, per FR-9.
- `docs/writing-specs.md` — `§ Plan stage` step 2, per FR-10.
- `docs/spec-workflow-guide.md` — `§ Stage 2` step 1, per FR-10.
- `docs/rule-canonical-map.md` — entries per FR-7; the cap and the flip-back now each appear in ≥2 files and so need tracking.

## Rollout / migration notes
- Procedure-only: no spec currently at `specify` or `plan` needs reworking, and no archived spec is re-opened.
- FR-6 first applies to whichever active spec next has a dependency close; none is pending in either project today.
