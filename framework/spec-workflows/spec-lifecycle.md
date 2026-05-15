# Spec Lifecycle

*Last updated: 2026-05-14*

Single canonical source for status definitions, transitions, gates, front-matter schema, anti-skip rules, and Visualize / Split sub-step triggers. Other framework files MUST link here, not restate the rules.

<!-- Anchors in this file (per `docs/rule-canonical-map.md`): R2 `never-tasks-table-at-specify` · R3 `never-flip-without-gate` · R6 `split-check-mandatory` · R7 `depends-on-blocks-plan` · R8 `visualize-not-a-status` · R10 `visualize-triggers`. -->

## Front-matter schema

Every spec file starts with YAML front-matter. All fields below are
**required** unless marked optional.

```yaml
---
id: CR-YYYYMMDD-<kebab-case-title>     # file basename without .md
type: CR                                # CR | BUG | IMP | RES
date: YYYY-MM-DD                        # creation date
status: specify                         # specify | plan | in-progress | done
owner: <github-handle>                  # accountable human
risk: low | medium | high | trivial      # CR / IMP only; BUG uses severity. `trivial` opts into the short-circuited Trivial lane (see § Trivial lane).
severity: low | medium | high | critical | trivial  # BUG only; `trivial` opts into the Trivial lane.
affected-repos:                         # repos that will change
  - <project-name>
affected-docs:                          # docs that will change (planning inventory)
  - docs/...
affected-code:                          # code paths that will change (planning inventory)
  - src/...
skills:                                 # skills to load at every stage and task
  - writing-specs
  - <project-skill>
model-suggestion: default               # fast | default | deep (from model-selection skill)
siblings:                               # optional — sibling spec IDs produced by the Split check
  - <spec-id>
depends-on:                             # optional — specs that MUST reach `done` before this one advances to `plan`
  - <spec-id>
---
```

`siblings:` and `depends-on:` are filled during the Specify-stage Split
check (see
[`splitting-rules.md § 5`](../skills/writing-specs/references/splitting-rules.md)).
Omit the fields when the spec is autonomous.

## Status transitions

```mermaid
stateDiagram-v2
    [*] --> specify: spec file created
    specify --> plan: requirements approved\n(+ architecture if triggered)
    plan --> in_progress: plan approved,\nTask 1 starts
    in_progress --> done: all tasks pass,\nclosure approved
    done --> [*]: file moved to archived/
```

| Transition | Precondition | Agent action |
|---|---|---|
| `[start]` → `specify` | Human asked for a new spec | Copy template, fill front-matter, write title — status `specify` from birth |
| `specify` → `plan` | Human approved requirements (and architecture if Visualize triggered). All `depends-on:` siblings must be `done` | Flip status, write `## Tasks` table |
| `plan` → `in-progress` | Human approved the plan, first task begins | Flip status **before** the first file edit of Task 1 |
| `in-progress` → `done` | Every AC has evidence, tests pass, docs updated | Flip status, post closure summary |
| `done` → `archived/` | Immediately after closure | Move file from `docs/specs/active/` to `docs/specs/archived/` |

**No status is skipped. No status is revisited in place** — if the plan
must change after `in-progress` begins, stop, flip status back to `plan`,
update the table, ask for re-approval. **Exception:** specs of `type: RES`
may transition `in-progress → specify` repeatedly until reaching `done` —
the iterative loop is the lane's defining feature. See [§ RES exception](#res-exception)
for the full rule set and Iteration Log mandate.

## Rules

1. Skip-protection rule lives at [`boundaries.md § Never do #2`](../boundaries.md#never-skip-specify). In lifecycle terms: even a one-line bug runs the ≤10-question round from its question list before requirements gate.
2. <a id="never-tasks-table-at-specify"></a>**Never** write a `## Tasks` table while `status` is `specify`.
3. <a id="never-flip-without-gate"></a>**Never** flip to `plan` without explicit human approval of requirements.
4. **Never** flip to `in-progress` without explicit human approval of the
   plan.
5. **Never** flip to `done` while any acceptance criterion lacks documented
   evidence.
6. Stamp-bump rule lives at [`boundaries.md § Always do #10`](../boundaries.md#last-updated-stamp); applies to every change of this lifecycle file too.
7. Task-row-update rule lives at [`boundaries.md § Always do #11`](../boundaries.md#task-row-status-in-place); applies as tasks progress through the in-progress stage.
8. <a id="visualize-not-a-status"></a>Visualize is a sub-step of Specify (not a status). When triggered,
   complete it before asking for the requirements gate.
9. <a id="split-check-mandatory"></a>The **Split check** (see
   [`splitting-rules.md § 2`](../skills/writing-specs/references/splitting-rules.md))
   is a mandatory sub-step of Specify — complete it before Visualize and
   record the outcome under `## Split Decision` in every affected spec.
10. <a id="depends-on-blocks-plan"></a>A spec with unmet `depends-on:` MUST stay at `specify` (never flip to
    `plan`) until all listed siblings reach `done`.
11. **Never** request the requirements gate without completing the Split check; record the outcome under `## Split Decision` first.
12. **Never** bundle independently-testable features into one spec — split per [`splitting-rules.md § 2`](../skills/writing-specs/references/splitting-rules.md).
13. **Baseline closure rule and Summary refresh.** Any spec that changes
    baseline behaviour in a feature with an existing
    `<project>/docs/requirements/<feature>.md` file MUST update that
    file in the same change before flipping to `done`. Baselines updated
    under this rule MUST describe the system after the spec's changes
    are applied -- not desired future behaviour -- and MUST bump the
    `Last src verified` row in the baseline's header info to the
    closure date, even when the baseline body is unchanged. The Closure
    Evidence row for the affected AC MUST cite the diff (path +
    summary). When the spec introduces baseline behaviour for a feature
    that has no baseline file yet, the closure MAY seed a new file under
    `docs/requirements/` -- recommended when the feature will likely be
    touched again. If the spec's scope changed between Plan and closure,
    refresh `## Summary` before flipping to `done` so Goal, Scope, and
    Out of scope reflect post-closure state. See the seed example at
    `tobevisit-content/docs/requirements/place-catalog-enrichment.md`.

## RES exception <a id="res-exception"></a>

The RES (Research / Spike / POC) spec type implements a fundamentally
different lifecycle from CR / BUG / IMP: the work is **iterative**, not
forward-only. A RES spec may transition `in-progress → specify` an
unlimited number of times until reaching `done`. This is the only
exception to the "No status is revisited in place" rule above.

### Status transitions (RES-only)

```
specify ⇄ in-progress → done
         ↑________|
        (loop permitted)
```

Each `in-progress → specify` backflip MUST record an entry in the spec's
`## Iteration Log` section (date + cause + decision). Without that
entry, the backflip is invalid — the validator (see
[IMP-20260514-research-lane FR-7](../../docs/specs/archived/IMP-20260514-research-lane.md)
once archived) will flag it as drift.

### Front-matter additions (RES-only)

RES specs add four front-matter fields beyond the standard schema. They
are RES-only — CR/BUG/IMP MUST NOT carry them and the validator MUST NOT
require them on those types:

- `hypothesis:` — one-sentence statement of what is being tested
- `kill-criteria:` — when to stop iterating. Required shape: time-box
  OR token-budget OR iteration-count
- `code-location:` — sandbox path for throwaway code. Default
  `research/<spec-id>/`. MUST NOT be inside `src/` of any repo
- `outcome:` — filled at `done`. One of:
  `confirmed | refuted | inconclusive | promoted-to-<spec-id>`

When `outcome: promoted-to-<spec-id>` is set, the referenced spec MUST
exist (validator-enforced). Code in `research/<spec-id>/` MUST NOT be
merged into `src/` without that explicit promotion + the sibling CR/IMP
being `done`.

### Rules for the lane

1. RES is the only spec type that may transition `in-progress → specify`.
   CR/BUG/IMP remain forward-only (see "No status is revisited in place"
   above).
2. Each backflip MUST land a row in `## Iteration Log` with date + cause
   + decision. The validator flags backflips without a corresponding log
   entry.
3. RES specs MUST NOT elect `risk: trivial` or `severity: trivial`. The
   Trivial lane is one-shot and incompatible with the RES loop
   (documented in [`spec-types.md § Trivial lane`](spec-types.md)).
4. `code-location:` MUST be outside every repo's `src/`. The default
   `research/<spec-id>/` lives in the workspace `research/` directory.
5. At `done`, `outcome:` MUST be filled with a valid value. Promotion
   targets (`promoted-to-<id>`) MUST resolve to an existing spec in
   `docs/specs/active/` or `docs/specs/archived/`.

## Trivial lane <a id="trivial-lane"></a>

The Trivial lane is a parallel short-circuit of the standard lifecycle for changes too small to warrant the full Specify → Plan → in-progress gate sequence. It elects in via `risk: trivial` (CR/IMP) or `severity: trivial` (BUG). The Closure gate is **unchanged** — every AC still needs evidence, and the human still flips `in-progress → done` explicitly.

### Status sequence

```
specify+plan → in-progress → done
```

Two gates instead of three. The `specify+plan` gate is a single combined approval: requirements and the (one-row) Tasks table land together. `## Tasks` may carry exactly one row at this combined gate — this is the only exception to [`Rule #2`](#never-tasks-table-at-specify).

### Eligibility (validator-enforced)

A spec MUST satisfy all of these to elect `trivial`:

- `affected-code` + `affected-docs` total ≤ 2 files
- Exactly one entry in `affected-repos` (no cross-repo)
- No `depends-on:` (autonomous by construction)
- No schema change (front-matter, baseline, type system, API contract)
- No new bounded context
- No change to AI prompts under `framework/prompts/` or `<project>/.github/copilot/prompts/`
- No change to `framework/boundaries.md` or any `<project>/.github/copilot-instructions.md` § Boundaries section

A spec that fails any check MUST drop `trivial` and re-run Specify on the standard track. `validate-specs.py` enforces these mechanically; the human elects the lane, the framework verifies.

### Combined gate format

A trivial spec body has the same H2 sections as a standard spec but with reduced content:

| Section | Trivial-lane content |
|---|---|
| `## Summary` | One-line Goal. No Scope / Out of scope paragraphs. |
| `## Cost Estimate` | Omitted. |
| `## Problem Statement` | One paragraph; no separate Current State / Proposed Improvement split. |
| `## Requirements` | ≤3 FRs (typically 1). |
| `## Acceptance Criteria` | Exactly 1 AC. |
| `## Out of Scope` | One line, OR `—` if Goal is self-bounding. |
| `## Architecture` | Always `Skipped — trivial lane`. |
| `## Split Decision` | Always `Kept as one — trivial lane (E4 by elective)`. |
| `## Tasks` | Exactly one row at the combined gate. |

The Specify question round shrinks to ≤3 questions from a dedicated `questions/trivial-questions.md` list (introduced in IMP-20260514-trivial-lane Task T2).

### Rules for the lane

1. `risk: trivial` / `severity: trivial` is elected by the spec author; the validator verifies eligibility. It is never auto-assigned.
2. The combined `specify+plan` gate requires explicit human approval before status flips to `in-progress` — same approval discipline as the standard track, just merged.
3. A trivial spec MUST NOT be elevated mid-flight. If complexity grows past the eligibility criteria, the spec is closed as `done` with `outcome: scope-grew` (one-line note) and the work re-opens as a standard-track spec.
4. **No retroactive reclassification.** Archived specs (`docs/specs/archived/`) MUST NOT have `risk:` or `severity:` flipped to `trivial`. The lane applies only to specs created after this rule lands.

## Visualize sub-step (Specify) <a id="visualize-triggers"></a>

Run inside Specify before the requirements gate when **any** apply:

- Risk is `medium` or `high` (CR / IMP).
- Adds, removes, or reshapes a bounded context.
- Changes data flow between contexts or services.
- Changes a schema (database, type/interface, API contract).
- Adds or reorders a pipeline step.

Skip only when all are false. Record in `## Architecture` as a single line: `Skipped — <reason>`.

## Split sub-step (Specify)

Run on **every** CR / IMP / BUG after FRs + ACs, before the requirements gate. Never skipped; outcome may be *"kept as one spec"* per [`splitting-rules.md § 4`](../skills/writing-specs/references/splitting-rules.md). Record under `## Split Decision`. Triggers: [`§ 2`](../skills/writing-specs/references/splitting-rules.md) (Specify), [`§ 3`](../skills/writing-specs/references/splitting-rules.md) (Plan-stage safety net).

## File naming

Pattern: `<TYPE>-YYYYMMDD-<kebab-case-title>.md`

Examples:
- `CR-20260420-footer-copyright-message.md`
- `BUG-20260418-viewport-overlap.md`
- `IMP-20260409-place-catalog-ai-content.md`

## File location

```
docs/specs/
├── active/      ← specs in specify / plan / in-progress
└── archived/    ← completed specs (status: done); never deleted
```

## Deprecated: `draft` status

Earlier versions of this framework used `draft → specify → visualize →
plan → …`. Those four stages collapsed into one in practice (specs were
born fully-formed at `plan`), so the lifecycle is now:

```
specify → plan → in-progress → done
```

**Existing archived specs** keep their original status values; do not
rewrite history. **New specs** use the 4-status lifecycle.
