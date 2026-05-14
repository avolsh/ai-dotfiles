---
description: "Specify stage — create a CR or IMP spec with requirements"
---
#skill:writing-specs
#skill:agent-protocol

Specify stage for CR / IMP. Hard gate at the end — do not write `## Tasks`. Lifecycle + gate semantics: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). For bugs, use [`bug-triage.prompt.md`](bug-triage.prompt.md).

## Preconditions

- Target project identified; user wants a CR (change) or IMP (improvement).

## Steps

1. **Load context** — project `.github/copilot-instructions.md`, [`spec-types.md`](../spec-workflows/spec-types.md), the matching question list ([`cr-questions.md`](../spec-workflows/questions/cr-questions.md) or [`imp-questions.md`](../spec-workflows/questions/imp-questions.md)), project `docs/architecture/module-map.md`, and any `docs/requirements/<feature>.md` baselines per [`docs/baseline-citations.md`](../../docs/baseline-citations.md).
2. **Ask ≤10 questions** per [`docs/spec-asking-questions.md`](../../docs/spec-asking-questions.md). Mandatory every round: CR Q1 (Scope) + Q2 (Separability); IMP Q1 (Retrofit scope) + Q2 (Partial-application risk). Wait for answers.
3. **Create the spec** — copy the [CR](../spec-workflows/templates/CR-TEMPLATE.md) or [IMP](../spec-workflows/templates/IMP-TEMPLATE.md) template to `<project>/docs/specs/active/` (file name `<TYPE>-YYYYMMDD-<kebab>.md`). Fill front-matter (`status: specify`), `## Summary` (Goal/Scope/Out of scope), `## Cost Estimate`, `## Problem Statement`, `## Requirements`, `## Acceptance Criteria`, `## Out of Scope` per [`docs/spec-format.md`](../../docs/spec-format.md) + [`docs/acceptance-criteria-patterns.md`](../../docs/acceptance-criteria-patterns.md). Leave `## Tasks` empty.
4. **Split check** — apply [`splitting-rules.md § 2`](../skills/writing-specs/references/splitting-rules.md) against FR clusters + the Separability answer; procedure in [`docs/splitting-specs.md`](../../docs/splitting-specs.md). Record the outcome in `## Split Decision` of every affected spec.
5. **Visualize sub-step** — if any trigger in [`spec-workflows/README.md § Visualize`](../spec-workflows/README.md#visualize-sub-step-when-mandatory) applies, hand off to [`visualize-spec.prompt.md`](visualize-spec.prompt.md); else write `Skipped — <reason>` under `## Architecture`.
6. **Gate** — post per-spec summary (ID + path, FR/AC count, Split Decision, `siblings:` / `depends-on:`, Visualize status, `cites-reqs:` or net-new justification, open questions). Wait for explicit approval. Then hand off to [`plan-spec.prompt.md`](plan-spec.prompt.md); Plan advances the first spec with no unmet `depends-on:` first.

## Hard rules

- Never write `## Tasks` here — that belongs to Plan.
- Never skip the question round — even trivial CRs get one.
- Never request the gate without `## Split Decision` filled in every spec (this + siblings).
