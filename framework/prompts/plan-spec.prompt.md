---
description: "Plan stage — decompose an approved spec into vertical-slice tasks"
---
#skill:writing-specs
#skill:model-selection

Plan stage — decompose approved requirements into vertical-slice tasks. Lifecycle: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). Task and writing-style rules: [`docs/writing-specs.md § Plan stage`](../../docs/writing-specs.md#plan-stage-detail).

## Preconditions
- Spec at `status: specify`, requirements approved by the human, `## Design` populated or `Skipped — <reason>`.

## Steps
1. **Load context** — the spec file, [`model-selection/SKILL.md`](../skills/model-selection/SKILL.md), every `SKILL.md` listed in the spec's `skills` field, and project `docs/architecture/module-map.md`.
2. **Transition status** — human approved requirements at the Specify gate; flip front-matter `status: specify → plan`; update `*Last updated:*`. This is the actual `specify → plan` lifecycle transition; task decomposition below runs at `status: plan`.
3. **Decompose + safety-net split** — run inline per [`writing-specs/references/authoring-steps.md § C`](../skills/writing-specs/references/authoring-steps.md). If a safety-net signal (P1/P2/P3) fires, § C step 6 decides which of two things it is: a signal repeating a cluster the human already adjudicated at the Specify gate is recorded as an override under `## Split Decision` and the table is written at `status: plan`; a signal on a cluster the Split check never named stops the plan — do NOT write tasks; flip `status: plan → specify`; update `*Last updated:*`. Either way, surface the cited signal at the gate.
4. **Write the `## Tasks` block** per § C step 7 — the `> **Before starting Task 1, …**` line plus the 8-column table.
5. **Gate** — post summary (task count + file count, cross-bounded-context concerns, model tier distribution, execution order). Wait for explicit plan approval; Task 1 begins on approval.

## Hard rules
- Never write tasks without approved requirements above them. Never exceed 5 decisions per task row — the cap and the Files column measure different things, per [`authoring-steps.md § C`](../skills/writing-specs/references/authoring-steps.md) step 5 — and never merge unrelated work to hit ≤12 total. Never force-fit a dependency to silence a fired signal; § C step 6 decides between an override and a flip back to `specify`. No advance to `plan` while `depends-on:` siblings are unmet — see [`spec-lifecycle.md § Rules #10`](../spec-workflows/spec-lifecycle.md#depends-on-blocks-plan).
