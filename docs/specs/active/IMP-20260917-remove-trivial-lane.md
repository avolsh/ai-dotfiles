---
id: IMP-20260917-remove-trivial-lane
type: IMP
date: 2026-09-17
status: in-progress
owner: alexvolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/spec-workflows/lifecycle.yaml
  - framework/spec-workflows/spec-lifecycle.md
  - framework/spec-workflows/spec-types.md
  - framework/spec-workflows/questions/trivial-questions.md
  - framework/spec-workflows/questions/res-questions.md
  - framework/spec-workflows/templates/CR-TEMPLATE.md
  - framework/spec-workflows/templates/IMP-TEMPLATE.md
  - framework/spec-workflows/templates/BUG-TEMPLATE.md
  - framework/spec-workflows/templates/RES-TEMPLATE.md
  - framework/boundaries.md
  - framework/prompts/create-spec.prompt.md
  - framework/prompts/research-spec.prompt.md
  - framework/prompts/explore.prompt.md
  - docs/spec-workflow-guide.md
  - docs/spec-format.md
  - docs/ai-agent-framework.md
  - docs/writing-specs.md
  - docs/rule-canonical-map.md
affected-code:
  - scripts/spec-next.py
  - scripts/test/validate-specs.test.sh
  - scripts/test/lifecycle-mutations.test.sh
  - scripts/test/spec-next.test.sh
skills:
  - writing-specs
  - test-driven-development
model-suggestion: default
depends-on:
  - IMP-20260914-explore-mode-and-lane-review
baseline-impact: none — ai-dotfiles has no docs/domain/ baselines; the change removes a framework lane
---

# IMP-20260917-remove-trivial-lane

*Last updated: 2026-09-17*

> Created by `IMP-20260914-explore-mode-and-lane-review` T4 to carry the owner's `remove` decision. Specify question
> round ran 2026-09-17 (Q1 scope, Q2 partial application, FR-2 date gate, Q5 rollback); requirements approved
> 2026-09-17.

## Summary

- **Goal:** Remove the Trivial lane, which one spec in 160 used, without invalidating the specs that used it.
- **Scope:** Every lane reference in `lifecycle.yaml`, `spec-next`, templates, question lists, prompts, `boundaries.md`
  and docs; a tombstone keeps the `#trivial-lane` anchor; archived specs keep validating.
- **Out of scope:** The Direct lane, the RES lane and the standard track's gates.

## Current State

The 2026-09-17 lane review (`docs/specs/archived/artifacts/IMP-20260914-explore-mode-and-lane-review-lane-review.md`)
counted one Trivial-lane spec (`CR-20260728-dedup-dismiss-note-inline`, tobevisit-content) against a footprint of 328
lines. The Direct lane (≤2 files, ≤30 lines, owner-approved) covers the small end with 8 uses.

The Specify sweep found references beyond the review's list:

- `lifecycle.yaml` — `risk`/`severity` enums, `trivial_fix`, `trivial_forbidden_markers`, `lanes.trivial`, four
  `trivial_eligibility_*` rules, `res_trivial_lane`, the trivial exemption in `tasks_table_missing`,
  `question_lists.trivial`, `stages.specify.trivial` and the closure gate label.
- `scripts/spec-next.py:256` — hard-coded `("trivial", "research")` lane order.
- Prompts — `create-spec.prompt.md` (scaffold note), `research-spec.prompt.md` (RES ban), `explore.prompt.md`
  (candidate risk list).
- `boundaries.md § Never do #2` (Trivial lane is not a skip) and `#4` (review-after for `low`/`trivial`); the #2 text is
  tracked by `docs/rule-canonical-map.md`.
- `RES-TEMPLATE.md` and `res-questions.md` (RES ban), `spec-lifecycle.md § Direct lane` ("falls back to the Trivial
  lane") and `§ Review-after closure`, `spec-format.md`, `writing-specs.md`, `ai-agent-framework.md`.
- A precedent for the date gate exists: `closure_cutoff` with `{ge: [{date: $fm.date}, …]}`.

## Proposed Improvement

Delete the lane everywhere, keep `trivial` only as a legacy enum value behind a date-gated refusal, and leave a short
tombstone at `spec-lifecycle.md#trivial-lane`, so the framework carries two spec tracks plus Direct. Measurable
benefit: lane footprint from 328 lines to ≤20 (enum values, date-gate rule, tombstone, fixtures).

## Requirements

- FR-1: `lifecycle.yaml` and `spec-next` MUST carry no Trivial lane: no `lanes.trivial`, `trivial_eligibility_*` rules, `trivial_fix`, `trivial_forbidden_markers`, trivial exemption in `tasks_table_missing`, `question_lists.trivial` or `stages.*.trivial`; `trivial-questions.md` is deleted.
- FR-2: A spec dated before the removal date with `risk: trivial` or `severity: trivial` MUST validate without a lane finding; the enums keep `trivial` for that purpose.
- FR-3: A spec of any type dated on or after the removal date that elects `trivial` MUST get one validator finding naming the Direct lane and the standard track.
- FR-4: `spec-next` MUST never offer a trivial step; a spec electing `trivial` gets the standard track.
- FR-5: Templates, question lists, prompts, `boundaries.md` and docs MUST NOT describe the lane; `spec-lifecycle.md § Trivial lane` becomes a tombstone of ≤5 lines keeping its anchor, the Direct lane falls back to the standard track, and review-after names `low` only.
- NFR-1: FR-1–FR-5 ship in one commit; rollback is `git revert` of that commit. `tests/trivial-lane-closure-evidence.md` stays as history.

## Acceptance Criteria

### AC-1: History survives (FR-2)

Given `CR-20260728-dedup-dismiss-note-inline` and a fixture dated before the removal with `risk: trivial`
When `make validate-specs` runs on both corpora and the fixtures
Then neither gains a finding
Evidence: command output + `validate-specs.test.sh` case

### AC-2: New elections are refused and nothing offers the lane (FR-3, FR-4)

Given fixtures dated on the removal date with `risk: trivial` (CR, RES) and `severity: trivial` (BUG)
When the validator and `spec-next` run on them
Then the validator reports the removed lane naming the Direct lane and the standard track, and `spec-next` prints
`standard lane`
Evidence: `validate-specs.test.sh` + `spec-next.test.sh`

### AC-3: Footprint is gone (FR-1, FR-5)

Given the change is applied
When `grep -rniE "trivial[ _-]lane|risk: trivial|severity: trivial|trivial_|questions: trivial"` runs over `framework/`
(excluding `upstream/`), `docs/` (excluding `specs/` and `improvements-log.md`) and `scripts/`
Then only the tombstone, the enum values, the date-gate rule and test fixtures match, totalling ≤20 lines
Evidence: grep output with line count

### AC-4: Checks stay green (FR-1–FR-5, NFR-1)

Given the single commit
When `make check` and `make tests` run
Then both pass, including `lint-rules` and `validate-anchors`
Evidence: command output

## Design

Visualize skipped — no new component or data flow; the change deletes a lane and adds one rule.

- **D1 — Removal date.** New const `trivial_removed: '2026-09-17'` beside `closure_cutoff`: the lane review closed that
  day, and no spec dated 2026-09-17 elects `trivial`. The fixture for FR-2 is dated 2026-09-16.
- **D2 — One refusal rule.** `trivial_lane_removed` (no `lane:`) fires when `risk` or `severity` is `trivial` and
  either `date ≥ trivial_removed` or `type == RES`. It replaces `res_trivial_lane`, so RES keeps its date-independent
  ban with one rule instead of two. Message names the removal, `spec-lifecycle.md § Direct lane` and the standard
  track (`risk: low`, which may close review-after).
- **D3 — Enums unchanged.** `risk`/`severity` keep `trivial`; without the eligibility rules an old trivial spec is an
  ordinary standard-lane spec to the validator, which satisfies FR-2.
- **D4 — `spec-next` lane order from the schema.** `_lane` iterates `schema["lanes"]` instead of the hard-coded
  `("trivial", "research")`, so removing `lanes.trivial` leaves no dead name in code (FR-4).
- **D5 — Tombstone.** `## Trivial lane <a id="trivial-lane"></a>` keeps its heading and anchor with ≤5 lines: removed
  2026-09-17 by this IMP, where the history lives, and the refusal rule's id. `boundaries.md § Never do #2` returns to its
  pre-IMP-20260514 wording, which `rule-canonical-map.md` already tracks; the post-T3 entry is dropped.
- **D6 — Mutation test sample.** `lifecycle-mutations.test.sh` uses `trivial_eligibility_repos` as its unknown-lane
  sample; it moves to `res_hypothesis_empty` (`lane: research`).

## Out of Scope

- OS-1: The Direct lane and RES lane — kept by the same review; only their Trivial cross-references change.
- OS-2: Rewriting archived specs or `tests/trivial-lane-closure-evidence.md`.
- OS-3: The generic word "trivial" in `splitting-rules.md` E4 and `cr-questions.md` — not lane references.

## Split Decision

**keep-as-one (E3).** Clusters: {FR-1, FR-2, FR-3, FR-4} validator and `spec-next` mechanics; {FR-5} prose. T1 could
fire — the prose cluster is checkable on its own by AC-3 — but E3 applies: the owner's Q2/Q5 answers require one commit
and an atomic revert, since docs without the refusal (or the refusal without docs) leave the framework contradicting
itself. T2–T5 do not fire (one repo, one context, no external blocker); T6 does not fire (Q2 answer: ship together).

## Tasks

> **Before starting Task T1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Validator: tests first for the pre-date fixture (AC-1) and post-date CR/BUG/RES fixtures (AC-2); then add `trivial_removed` + `trivial_lane_removed`, delete `lanes.trivial`, `trivial_fix`, `trivial_forbidden_markers`, `trivial_eligibility_*`, `res_trivial_lane` and the `tasks_table_missing` exemption (FR-1, FR-2, FR-3; D1–D3, D6) | `framework/spec-workflows/lifecycle.yaml`, `scripts/test/validate-specs.test.sh`, `scripts/test/lifecycle-mutations.test.sh` | `scripts/lifecycle_engine.py`, `scripts/validate-specs.py` | — | test-driven-development | default | ☑ done |
| T2 | `spec-next`: rewrite the trivial fixture case to expect `standard lane` (AC-2); lane order from schema; delete `question_lists.trivial`, `stages.specify.trivial`, `low/trivial` in the closure label; delete `trivial-questions.md` (FR-1, FR-4; D4) | `scripts/spec-next.py`, `scripts/test/spec-next.test.sh`, `framework/spec-workflows/lifecycle.yaml`, `framework/spec-workflows/questions/trivial-questions.md` *(delete)* | — | T1 | test-driven-development | default | ☑ done |
| T3 | Canonical rules: tombstone `§ Trivial lane`, Direct lane falls back to the standard track, review-after names `low` only; `spec-types.md` section removed; `boundaries.md § Never do #2/#4` and `rule-canonical-map.md` (FR-5; D5) | `framework/spec-workflows/spec-lifecycle.md`, `framework/spec-workflows/spec-types.md`, `framework/boundaries.md`, `docs/rule-canonical-map.md` | `scripts/lint-rules.py` | T2 | writing-specs | default | ☑ done |
| T4 | Prompts and RES surfaces: drop the trivial scaffold note, RES ban and candidate-risk value; RES template comment and `res-questions.md` note (FR-5) | `framework/prompts/create-spec.prompt.md`, `framework/prompts/research-spec.prompt.md`, `framework/prompts/explore.prompt.md`, `framework/spec-workflows/templates/RES-TEMPLATE.md`, `framework/spec-workflows/questions/res-questions.md` | — | T3 | writing-specs | default | ☑ done |
| T5 | Templates and guides: trivial comments in CR/IMP/BUG templates; `spec-workflow-guide.md` Trivial section and cross-refs, `spec-format.md`, `ai-agent-framework.md`, `writing-specs.md` (FR-5) | `framework/spec-workflows/templates/CR-TEMPLATE.md`, `framework/spec-workflows/templates/IMP-TEMPLATE.md`, `framework/spec-workflows/templates/BUG-TEMPLATE.md`, `docs/spec-workflow-guide.md`, `docs/spec-format.md`, `docs/ai-agent-framework.md`, `docs/writing-specs.md` | — | T4 | writing-specs | fast | ☑ done |
| T6 | Verify and close: AC-3 grep with line count, AC-4 `make check` + `make tests`, AC-1 on both corpora; record Closure Evidence; one commit (NFR-1) | `docs/specs/active/IMP-20260917-remove-trivial-lane.md` | — | T5 | writing-specs | default | ◐ awaiting approval |

## Closure Evidence

| AC | Evidence | Result |
|---|---|---|
| AC-1 | `validate-specs.test.sh` "AC-1 a trivial spec dated before the removal (over the old 2-file cap) gains no finding"; `validate-specs.py` on `tobevisit-content/docs/specs` gives the same 4 pre-existing findings before and after the change, none on `CR-20260728-dedup-dismiss-note-inline` | pass |
| AC-2 | `validate-specs.test.sh` AC-2 cases (IMP `risk: trivial` and BUG `severity: trivial` dated 2026-09-17 report `trivial_lane_removed` naming the Direct lane and the standard track; a `low` spec stays silent; D4-2 RES at any date reported); `lifecycle-mutations.test.sh` `trivremoved`; `spec-next.test.sh` AC-2 cases (`standard lane`, no combined gate, `cr-questions.md`) — all passed, after 7 + 1 red first | pass |
| AC-3 | The AC grep matches 34 lines: 16 outside tests (`spec-lifecycle.md` 8 — tombstone, RES rule #3, enum comment; `lifecycle.yaml` 5 — const and rule; `spec-workflow-guide.md` 2 — tombstone pointer; `rule-canonical-map.md` 1 — history note) and 18 test-fixture lines. Divergence: the pointer and history note are outside the AC's allow-list, and ≤20 holds only without fixtures (328 → 16) | pass with divergence |
| AC-4 | `make check` rc=0 (links, validate-specs, lint-rules 79 phrases, validate-anchors 155 links); `make tests` rc=0; `make sync-agents-check` rc=0 | pass |

## Agent instructions

Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`; changes lane definitions, prompts and
`boundaries.md` — `§ Ask first #3/#4`.

## Docs updates required

- `spec-lifecycle.md § Trivial lane` (tombstone), `§ Direct lane`, `§ Review-after closure`; `spec-types.md`,
  `spec-workflow-guide.md`, `spec-format.md`, `writing-specs.md`, `ai-agent-framework.md`, `rule-canonical-map.md`.
- `docs/improvements-log.md` — not required; the spec is the record.

## Rollout / migration notes

- Single commit; revert restores the lane. No downstream project adoption step — projects read the framework directly.
