---
id: IMP-20260830-active-spec-overlap-detection
type: IMP
date: 2026-08-30
status: specify
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/spec-lifecycle.md
  - framework/prompts/plan-spec.prompt.md
affected-code:
  - scripts/validate-specs.py
  - scripts/test/validate-specs.test.sh
skills:
  - writing-specs
  - writing-docs
  - test-driven-development
model-suggestion: default
---
# IMP-20260830-active-spec-overlap-detection
*Last updated: 2026-08-30*

## Summary
- **Goal:** Detect two active specs aimed at the same file before both are written, and re-verify a spec whose ground another spec has already closed over.
- **Scope:** A new `validate-specs.py` check on active-spec inventory overlap, plus a second re-verification key in `spec-lifecycle.md § Rules #10` and the Plan precondition that makes it reachable.
- **Out of scope:** Any change to what the ≤5 cap counts, and any mechanical enforcement that the re-read happened.

## Current State
On 2026-08-26 four IMP specs were created in one batch. Two of them — `IMP-20260826-plan-file-count-realism` and `IMP-20260826-decomposition-and-staleness-procedures` — were written from the same improvements-log entries against the same target: what the ≤5 cap in `authoring-steps.md § C` counts. They shared two `affected-docs` entries and named neither the other in `siblings:` nor `depends-on:`. The wider one reached `done` on 2026-08-27 and landed the rule; the narrower sat at `specify` for four days describing a `## Current State` that had stopped being true, with three of its four FRs already satisfied at HEAD — one by text the closed spec had made stronger.

Nothing fired. `validate-specs.py` parses `affected-docs` for every spec (`check_inventory_paths`) but never compares two specs' inventories. The staleness rule the closed spec itself introduced is keyed to `depends-on:`, which the Split check fills — so it protects only specs split *from* each other, and misses two written independently against one rule, which is where `## Current State` rots fastest. The overlap surfaced on 2026-08-30, and only because a human asked what the open spec was for.

A gap that produces no signal accumulates no witnesses, so the usual multi-witness bar cannot be reached here by waiting.

## Proposed Improvement
Two halves of one guard. Mechanically: a check that reads two active specs sharing an inventory path as a collision unless they declare a relationship. The discriminator is exact — on 2026-08-26 the legitimate pair (`ui-surface-closure-evidence` × `decomposition-and-staleness-procedures`, four shared `affected-docs`) carried both `siblings:` and `depends-on:`; the missed pair carried neither. Procedurally: `§ Rules #10` gains a second key, so a spec is re-verified not only when its `depends-on:` closes but when any spec touching its inventory reaches `done` after its `date:`.

The finding is an error, not an advisory: `validate-specs.py` has no warning level, and the remedy is unambiguous — declare the relationship or merge the specs.

**Measurable benefit:** replayed against the two overlapping active-spec pairs that existed on 2026-08-26, detection goes from 0/1 unlinked pair (found four days later by a human question) to 1/1 at the requirements gate, with 0 findings on the 1 linked pair.

## Requirements
- FR-1: `validate-specs.py` MUST report a finding when two specs under `docs/specs/active/` name the same path in `affected-docs` or `affected-code`.
- FR-2: FR-1 MUST NOT fire when either spec names the other in `siblings:` or in `depends-on:`, in either direction — a declared relationship is the Split check's own output.
- FR-3: The FR-1 finding MUST name the other spec's `id` and every shared path, so the reader can act without opening both files.
- FR-4: `spec-lifecycle.md § Rules #10` MUST state a second re-verification key: when a spec naming any of this spec's `affected-docs` or `affected-code` reaches `done` after this spec's `date:`, `## Current State` MUST be re-verified and superseded FRs tombstoned before this spec advances to `plan`.
- FR-5: `plan-spec.prompt.md` MUST carry FR-4's key in its preconditions, because unlike `depends-on:` the trigger appears nowhere in the spec's own front-matter and is otherwise unreachable at the stage where it fires.

## Acceptance Criteria
### AC-1: An undeclared collision is reported (FR-1, FR-3)
Given two active specs sharing an `affected-docs` entry and naming neither the other in `siblings:` nor `depends-on:` — the 2026-08-26 pair reconstructed as fixtures
When `validate-specs.py` runs
Then it exits non-zero and the finding names both spec ids and the shared path

### AC-2: A declared relationship is silent (FR-2)
Given `IMP-20260826-ui-surface-closure-evidence` and `IMP-20260826-decomposition-and-staleness-procedures` as fixtures at `status: specify`, sharing four `affected-docs` entries and linked by `siblings:` and `depends-on:`
When `validate-specs.py` runs
Then it reports no overlap finding for that pair

### AC-3: The second key is stated once and reachable at Plan (FR-4, FR-5)
Given `spec-lifecycle.md` and `plan-spec.prompt.md` at HEAD
When both are read
Then `§ Rules #10` states the inventory key beside the `depends-on:` key, `plan-spec.prompt.md` names it as a precondition, and `make lint-rules` and `make validate-anchors` pass

## Design
Skipped — one check added to an existing registry and two rule sentences; no structure, data flow, schema, pipeline step or UI surface is involved.

## Out of Scope
- OS-1: A `warning` severity in `validate-specs.py` — every finding stays an error; introducing a second level would touch `Finding` and all 13 existing checks.
- OS-2: Mechanically enforcing that the FR-4 re-read happened — no machine-readable mark exists for it, and inventing one is a larger change than the rule.
- OS-3: The residual FR-3 of `IMP-20260826-plan-file-count-realism` (recording why a Files column runs long) — unrelated to overlap, and unwitnessed.
- OS-4: Overlap between an active spec and an archived one at validation time; FR-4 covers that case procedurally.

## Split Decision
**T1 fires and no E1–E5 exception covers it — kept as one by human election at the Specify gate, recorded here as an override.** The FRs form two clusters: C1 (FR-1…FR-3, the check) and C2 (FR-4, FR-5, the rule), and each cluster's ACs verify without the other's FRs implemented, which is the § 1 definition. T2 is `unknown` — ai-dotfiles has no `docs/architecture/module-map.md`. T3–T6 do not fire; the Q2 answer states the clusters must ship together, which is the opposite of T6. E5 is the closest exception and is excluded by its own text, since this spec ships behavioural code. The ground for the election is that the two clusters answer one question — when is a spec stale — and shipping either alone leaves the corpus answering it two ways, with the validator keyed to overlap and the rule keyed to `depends-on:`. Surfaced at the gate for confirmation rather than resolved silently.

## Tasks
Pending — Plan stage only.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- `framework/spec-workflows/spec-lifecycle.md` — `§ Rules #10` second key, per FR-4.
- `framework/prompts/plan-spec.prompt.md` — precondition, per FR-5.
- `docs/rule-canonical-map.md` — only if FR-4's sentence ends up stated in more than one file; FR-5 is written as a link site, so the expectation is no new entry. Verify with `make lint-rules` at closure.

## Rollout / migration notes
- No migration. The check reads only `docs/specs/active/`; archived specs are inert.
- `make check` must be green on the corpus as it stands before the check is considered done — the one active spec today has no peer to collide with, so AC-1 and AC-2 close on fixtures, not on the live corpus.
