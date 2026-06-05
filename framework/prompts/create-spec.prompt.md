---
description: "Specify stage — create a CR or IMP spec with requirements"
---
#skill:writing-specs

Specify stage for CR / IMP. Hard gate at the end — do not write `## Tasks`. Lifecycle + gate semantics: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). For bugs, use [`bug-triage.prompt.md`](bug-triage.prompt.md).

## Preconditions

- Target project identified; user wants a CR (change) or IMP (improvement).

## Steps

1. **Load context** — your agent's instructions file (`CLAUDE.md`, `AGENTS.md`, or `.github/copilot-instructions.md` — pick the one for your agent), [`spec-types.md`](../spec-workflows/spec-types.md), the matching question list ([`cr-questions.md`](../spec-workflows/questions/cr-questions.md) or [`imp-questions.md`](../spec-workflows/questions/imp-questions.md)), project `docs/architecture/module-map.md`, and any `docs/domain/<feature>.md` baselines per [`docs/baseline-citations.md`](../../docs/baseline-citations.md).
2. **Ask ≤10 questions** per [`docs/spec-asking-questions.md`](../../docs/spec-asking-questions.md). Mandatory every round: CR Q1 (Scope) + Q2 (Separability); IMP Q1 (Retrofit scope) + Q2 (Partial-application risk). Wait for answers.
3. **Create the spec** — run inline per [`writing-specs/references/authoring-steps.md § A`](../skills/writing-specs/references/authoring-steps.md) (CR/IMP) or § D (RES), using the Step 2 answers. Fill through `## Out of Scope`; set `## Architecture` from Step 5 or `Skipped — <reason>`.
4. **Split check** — run inline per [`authoring-steps.md § B`](../skills/writing-specs/references/authoring-steps.md) using the CR Q2 / IMP Q2 separability answer; record the verdict + cited ID under `## Split Decision`.
5. **Visualize sub-step** — if any trigger in [`spec-lifecycle.md § Visualize sub-step`](../spec-workflows/spec-lifecycle.md#visualize-triggers) applies, hand off to [`visualize-spec.prompt.md`](visualize-spec.prompt.md); else write `Skipped — <reason>` under `## Architecture`.
6. **Gate** — post per-spec summary (ID + path, FR/AC count, Split Decision, `siblings:` / `depends-on:`, Visualize status, `domain-refs:` or net-new justification, open questions). Wait for explicit approval. Then hand off to [`plan-spec.prompt.md`](plan-spec.prompt.md); Plan advances the first spec with no unmet `depends-on:` first.

## Hard rules

- No `## Tasks` table here — see [`spec-lifecycle.md § Rules #2`](../spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify).
- No skipping the question round, even for trivial CRs — see [`boundaries.md § Never do #2`](../boundaries.md#never-skip-specify).
- No requirements gate without `## Split Decision` filled in this spec + all siblings — see [`spec-lifecycle.md § Rules #9`](../spec-workflows/spec-lifecycle.md#split-check-mandatory).
