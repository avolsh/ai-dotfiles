# Spec Types

*Last updated: 2026-05-27*

## Type catalog

| Type | Prefix | Template | Questions | Use when |
|---|---|---|---|---|
| **Change Request** | `CR-` | [`templates/CR-TEMPLATE.md`](templates/CR-TEMPLATE.md) | [`questions/cr-questions.md`](questions/cr-questions.md) | New feature, pipeline step, schema change |
| **Bug** | `BUG-` | [`templates/BUG-TEMPLATE.md`](templates/BUG-TEMPLATE.md) | [`questions/bug-questions.md`](questions/bug-questions.md) | Defect fix, incorrect behavior |
| **Improvement** | `IMP-` | [`templates/IMP-TEMPLATE.md`](templates/IMP-TEMPLATE.md) | [`questions/imp-questions.md`](questions/imp-questions.md) | Non-functional enhancement, refactor, performance |
| **Research** | `RES-` | [`templates/RES-TEMPLATE.md`](templates/RES-TEMPLATE.md) | [`questions/res-questions.md`](questions/res-questions.md) | Spike, investigation, proof of concept, vibe-coding; iterative `specify ⇄ in-progress` loop — see [`spec-lifecycle.md § RES exception`](spec-lifecycle.md#res-exception) |

## Per-type differences

| Aspect | CR | BUG | IMP |
|---|---|---|---|
| Visualize sub-step | Required if risk ≥ medium or architecture change | Optional | Required if refactor crosses bounded contexts |
| Standard questions | Requirements-focused | Reproduction-focused | Improvement-focused + measurable benefit |
| Required first task | — | Reproduce & verify the bug | — |
| Acceptance criteria | Feature behavior | Bug no longer occurs + regression test | Measurable improvement (latency, clarity, coverage) |
| Model suggestion default | `default` (impl), `deep` (architecture) | `fast` (isolated), `default` (cross-module) | `default` |

## Context to load per stage

Each stage may delegate work to sub-agents — see [`<system>/agents/README.md`](../agents/README.md). Specify delegates
to [`spec-author`](../agents/spec-author.md) (draft) + [`splitter`](../agents/splitter.md) (Split check); Plan delegates
to [`task-planner`](../agents/task-planner.md); Task delegates to [`precedent-finder`](../agents/precedent-finder.md)
when locating precedent files. Fallback (harnesses without sub-agent support): inline the agent's body and follow its
Steps in the main context.

Workspace docs are loaded when the spec touches them — beyond `module-map.md`, this includes
`<project>/docs/architecture/` (ADRs, design notes), `<project>/docs/domain/<feature>.md` baselines per
[Rule 13 baseline discovery](spec-lifecycle.md#rules), and the workspace `CLAUDE.md` project map when work spans
projects.

### CR — Change Request

| Stage | Load |
|---|---|
| Specify | Project `.github/copilot-instructions.md`, this file, [`questions/cr-questions.md`](questions/cr-questions.md), project `docs/architecture/module-map.md`, matching `docs/domain/<feature>.md` baselines (if any) |
| Visualize (sub-step) | The spec, project architecture overview, relevant reference schemas |
| Plan | The spec, `<system>/skills/model-selection/SKILL.md`, skill `SKILL.md` files for every skill in front-matter |
| Task | The spec, `<system>/boundaries.md`, project boundaries (if any), required skill `SKILL.md` files, target code from task's "Files" column + nearest precedent |

### BUG — Bug Report

| Stage | Load |
|---|---|
| Specify | Project `.github/copilot-instructions.md`, this file, [`questions/bug-questions.md`](questions/bug-questions.md), project `docs/architecture/module-map.md`, matching `docs/domain/<feature>.md` baseline (if any) |
| Plan | The spec, `<system>/skills/model-selection/SKILL.md` |
| Task | The spec, `<system>/boundaries.md`, project boundaries (if any), target code, failing test scaffold |

### IMP — Improvement

| Stage | Load |
|---|---|
| Specify | Project `.github/copilot-instructions.md`, this file, [`questions/imp-questions.md`](questions/imp-questions.md), project `docs/architecture/module-map.md`, matching `docs/domain/<feature>.md` baselines (if any) |
| Visualize (if triggered) | Same as CR |
| Plan | Same as CR |
| Task | Same as CR |

## Always loaded

These files are loaded at **every** stage, regardless of type:

- `<system>/boundaries.md` — non-negotiable rules governing all work. Includes the "When to consult
  `docs/agent-protocol.md`" trigger list, so loading boundaries gives you the protocol entry points without
  preloading the full reference doc.

## Conditionally loaded

- `<system>/skills/writing-specs/SKILL.md` — when editing any spec file.
- `<system>/skills/model-selection/SKILL.md` — at Plan stage to pick model tier per task.
- `<system>/docs/agent-protocol.md` — when any trigger in boundaries § "When to consult" fires.
- Project-scope skills in the spec's `skills` field — project-first lookup (see two-scope model in
  [`docs/agent-protocol.md`](../../docs/agent-protocol.md)).

## Trivial lane (applicable to CR / BUG / IMP)

CR/BUG/IMP may elect the Trivial lane (`risk: trivial` or `severity: trivial`). RES does not support the Trivial
lane. Full rules: [`spec-lifecycle.md § Trivial lane`](spec-lifecycle.md#trivial-lane).
