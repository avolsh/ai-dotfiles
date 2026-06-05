---
description: "Plan stage — decompose an approved spec into vertical-slice tasks"
---
#skill:writing-specs
#skill:model-selection

Plan stage — decompose approved requirements into vertical-slice tasks. Lifecycle: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). Task and writing-style rules: [`docs/writing-specs.md § Plan stage`](../../docs/writing-specs.md#plan-stage-detail).

## Preconditions
- Spec at `status: specify`, requirements approved by the human, `## Architecture` populated or `Skipped — <reason>`.

## Steps
1. **Load context** — the spec file, [`model-selection/SKILL.md`](../skills/model-selection/SKILL.md), every `SKILL.md` listed in the spec's `skills` field, and project `docs/architecture/module-map.md`.
2. **Transition status** — human approved requirements at the Specify gate; flip front-matter `status: specify → plan`; update `*Last updated:*`. This is the actual `specify → plan` lifecycle transition; task decomposition below runs at `status: plan`.
3. **Decompose + safety-net split** — delegate to [`<system>/agents/task-planner.md`](../agents/task-planner.md). Inputs: `spec_path`, optional `module_map_path`. The agent returns `tasks_block` (ready to paste), `task_count`, `model_tier_distribution`, `dependency_chain`, and `safety_net_verdict`. If verdict = `re-Specify-recommended` (P1/P2/P3 fired): do NOT paste tasks; flip `status: plan → specify`; update `*Last updated:*`; surface the cited signal at the gate. *Fallback (no `Agent` tool): inline the agent's Steps from its file.*
4. **Paste `tasks_block`** under `## Tasks`. The agent's output already includes the `> **Before starting Task 1, ...**` line and the 8-column table.
5. **Refresh `## Cost Estimate`** so token range, gate count / minutes, and re-Specify tripwire reflect final task count + dependencies.
6. **Gate** — post summary (task count + file count, cross-bounded-context concerns, model tier distribution, execution order, `## Summary` + refreshed `## Cost Estimate` confirmation). Wait for explicit plan approval; Task 1 begins on approval.

## Hard rules
- Never write tasks without approved requirements above them. Never exceed 5 files per task row or merge unrelated work to hit ≤12 total. If § 3 signals fire, flip back to `specify` — never force-fit. No advance to `plan` while `depends-on:` siblings are unmet — see [`spec-lifecycle.md § Rules #10`](../spec-workflows/spec-lifecycle.md#depends-on-blocks-plan).
