# Spec Types

*Last updated: 2026-05-14*

## Type catalog

| Type | Prefix | Template | Questions | Use when |
|---|---|---|---|---|
| **Change Request** | `CR-` | [`templates/CR-TEMPLATE.md`](templates/CR-TEMPLATE.md) | [`questions/cr-questions.md`](questions/cr-questions.md) | New feature, pipeline step, schema change |
| **Bug** | `BUG-` | [`templates/BUG-TEMPLATE.md`](templates/BUG-TEMPLATE.md) | [`questions/bug-questions.md`](questions/bug-questions.md) | Defect fix, incorrect behavior |
| **Improvement** | `IMP-` | [`templates/IMP-TEMPLATE.md`](templates/IMP-TEMPLATE.md) | [`questions/imp-questions.md`](questions/imp-questions.md) | Non-functional enhancement, refactor, performance |
| **Research** | `RES-` | *(future)* | *(future)* | Spike, investigation, proof of concept |

## Per-type differences

| Aspect | CR | BUG | IMP |
|---|---|---|---|
| Visualize sub-step | Required if risk ≥ medium or architecture change | Optional | Required if refactor crosses bounded contexts |
| Standard questions | Requirements-focused | Reproduction-focused | Improvement-focused + measurable benefit |
| Required first task | — | Reproduce & verify the bug | — |
| Acceptance criteria | Feature behavior | Bug no longer occurs + regression test | Measurable improvement (latency, clarity, coverage) |
| Model suggestion default | `default` (impl), `deep` (architecture) | `fast` (isolated), `default` (cross-module) | `default` |

## Context to load per stage

### CR — Change Request

| Stage | Load |
|---|---|
| Specify | Project `.github/copilot-instructions.md`, this file, [`questions/imp-questions.md`](questions/imp-questions.md), project `docs/architecture/module-map.md` |
| Visualize (sub-step) | The spec, project architecture overview, relevant reference schemas |
| Plan | The spec, `<system>/skills/model-selection/SKILL.md`, skill `SKILL.md` files for every skill in front-matter |
| Task | The spec, `<system>/boundaries.md`, project boundaries (if any), required skill `SKILL.md` files, target code from task's "Files" column + nearest precedent |

### BUG — Bug Report

| Stage | Load |
|---|---|
| Specify | Project `.github/copilot-instructions.md`, this file, [`questions/bug-questions.md`](questions/bug-questions.md), project `docs/architecture/module-map.md` |
| Plan | The spec, `<system>/skills/model-selection/SKILL.md` |
| Task | The spec, `<system>/boundaries.md`, project boundaries (if any), target code, failing test scaffold |

### IMP — Improvement

| Stage | Load |
|---|---|
| Specify | Project `.github/copilot-instructions.md`, this file, [`questions/cr-questions.md`](questions/cr-questions.md), project `docs/architecture/module-map.md` |
| Visualize (if triggered) | Same as CR |
| Plan | Same as CR |
| Task | Same as CR |

## Always loaded

These files are loaded at **every** stage, regardless of type:

- `<system>/boundaries.md` — non-negotiable rules governing all work.
- `<system>/skills/agent-protocol/SKILL.md` — if the task is non-trivial.
- `<system>/skills/writing-specs/SKILL.md` — when editing any spec file.
- Project-scope skills in the spec's `skills` field — project-first lookup.
