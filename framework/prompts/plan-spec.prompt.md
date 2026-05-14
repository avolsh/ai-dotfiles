---
description: "Plan stage — decompose an approved spec into vertical-slice tasks"
---
#skill:writing-specs
#skill:model-selection
#skill:agent-protocol

Plan stage — decompose approved requirements into vertical-slice tasks. Lifecycle: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). Task and writing-style rules: [`docs/writing-specs.md § Plan stage`](../../docs/writing-specs.md#plan-stage-detail).

## Preconditions
- Spec at `status: specify`, requirements approved by the human, `## Architecture` populated or `Skipped — <reason>`.

## Steps
1. **Load context** — the spec file, [`model-selection/SKILL.md`](../skills/model-selection/SKILL.md), every `SKILL.md` listed in the spec's `skills` field, and project `docs/architecture/module-map.md`.
2. **Decompose** into 1–12 vertical-slice tasks. Per task: description, exact paths (≤5 in Files, mark `(new)`; optional uncapped read-only Source-files column for precedent loads), dependencies (earlier task #s), task-specific skills (subset of spec-level), model tier per [`docs/model-selection.md`](../../docs/model-selection.md), `Status: ⬜ todo`.
3. **Safety-net split check** — apply [`splitting-rules.md § 3`](../skills/writing-specs/references/splitting-rules.md). If any signal fires, do not write the table: flip `status` back to `specify`, update `*Last updated:*`, return to [`create-spec.prompt.md § Step 4`](create-spec.prompt.md). Plan resumes only after a fresh Specify gate.
4. **Write `## Tasks`** — add `> **Before starting Task 1, set status: in-progress in the front-matter above.**`. If `## Agent instructions` cites "The Bottom Line", cross-reference [`docs/agent-protocol.md § The Bottom Line`](../../docs/agent-protocol.md#the-bottom-line--canonical-format) instead of duplicating fields.
5. **Refresh `## Cost Estimate`** so token range, gate count / minutes, and re-Specify tripwire reflect final task count + dependencies. Flip front-matter `status: plan`; update `*Last updated:*`.
6. **Gate** — post summary (task count + file count, cross-bounded-context concerns, model tier distribution, execution order, `## Summary` + refreshed `## Cost Estimate` confirmation). Wait for explicit plan approval; Task 1 begins on approval.

## Hard rules
- Never write tasks without approved requirements above them. Never exceed 5 files per task row or merge unrelated work to hit ≤12 total. If § 3 signals fire, flip back to `specify` — never force-fit. Never advance to `plan` while `depends-on:` siblings are unmet.
