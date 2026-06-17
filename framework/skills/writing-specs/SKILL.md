---
name: writing-specs
source: <system>/upstream/claude-skills/engineering/spec-driven-workflow (merged)
description: >
  Guides the agent through the full spec lifecycle from creating a spec
  through planning, task execution, and closure. Use when creating,
  editing, or implementing a CR, BUG, IMP, or RES spec.
---

# Writing Specs

*Last updated: 2026-06-16*

Spec authoring, the Split check, and task decomposition run **inline in
the main context** — they are not delegated to subagents. The
step-by-step procedures live in
[`references/authoring-steps.md`](references/authoring-steps.md).

## When to use

- Starting a new feature, bug fix, improvement, or research spec.
- Editing an existing spec during `specify`, `plan`, or `in-progress`.
- Running Specify (questions, requirements, acceptance criteria) or its Visualize sub-step.
- Running Plan (vertical-slice tasks).
- Implementing tasks from an approved spec.
- Closing a spec (evidence, status flip, move to `archived/`).

## References

- [`references/authoring-steps.md`](references/authoring-steps.md) — inline procedures for spec authoring (CR/IMP/RES), the Split check, and task decomposition.
- [`docs/writing-specs.md`](../../../docs/writing-specs.md) — lifecycle pointer, stage walk-throughs (Specify, Plan), writing-style rules, length budget, gated compression pass, RFC 2119, anti-patterns, self-review additions, template usage, and topic index.
- [`docs/spec-asking-questions.md`](../../../docs/spec-asking-questions.md), [`docs/spec-format.md`](../../../docs/spec-format.md), [`docs/acceptance-criteria-patterns.md`](../../../docs/acceptance-criteria-patterns.md) — Specify-stage authoring.
- [`docs/splitting-specs.md`](../../../docs/splitting-specs.md) + [`references/splitting-rules.md`](references/splitting-rules.md) — split procedure (prose) + trigger / exception ID tables.
- [`docs/bounded-autonomy.md`](../../../docs/bounded-autonomy.md) + [`references/bounded-autonomy-rules.md`](references/bounded-autonomy-rules.md) — stop-vs-continue rationale + decision matrix.
- [`docs/baseline-citations.md`](../../../docs/baseline-citations.md), [`docs/req-id-lifecycle.md`](../../../docs/req-id-lifecycle.md) — per-feature requirements baselines and REQ-ID rules.
- [`framework/spec-workflows/`](../../spec-workflows/) — lifecycle, types, templates, questions.
