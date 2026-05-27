---
description: "Specify stage — create a CR or IMP spec with requirements"
---
#skill:writing-specs

Specify stage for CR / IMP. Hard gate at the end — do not write `## Tasks`. Lifecycle + gate semantics: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). For bugs, use [`bug-triage.prompt.md`](bug-triage.prompt.md).

## Preconditions

- Target project identified; user wants a CR (change) or IMP (improvement).

## Steps

1. **Load context** — project `.github/copilot-instructions.md`, [`spec-types.md`](../spec-workflows/spec-types.md), the matching question list ([`cr-questions.md`](../spec-workflows/questions/cr-questions.md) or [`imp-questions.md`](../spec-workflows/questions/imp-questions.md)), project `docs/architecture/module-map.md`, and any `docs/domain/<feature>.md` baselines per [`docs/baseline-citations.md`](../../docs/baseline-citations.md).
2. **Ask ≤10 questions** per [`docs/spec-asking-questions.md`](../../docs/spec-asking-questions.md). Mandatory every round: CR Q1 (Scope) + Q2 (Separability); IMP Q1 (Retrofit scope) + Q2 (Partial-application risk). Wait for answers.
3. **Create the spec** — delegate to [`<system>/agents/spec-author.md`](../agents/spec-author.md). Inputs: `spec_type` (CR/IMP), `title`, `project_root`, `date`, `owner`, `question_answers` (from Step 2), `architecture_status` (filled at Step 5 or `Skipped — <reason>`), optional `baselines`. The agent returns `spec_path`, FR/AC counts, and a `visualize_required` flag. *Fallback (no `Agent` tool): inline the agent's Steps from its file — body is self-contained.*
4. **Split check** — delegate to [`<system>/agents/splitter.md`](../agents/splitter.md). Inputs: `spec_path` (from Step 3), `separability_answer` (CR Q2 or IMP Q2 verbatim from Step 2), optional `module_map_path`. The agent returns a `verdict` + `cited_id` + `decision_block` (ready to paste under `## Split Decision`). *Fallback: inline the agent's Steps.*
5. **Visualize sub-step** — if any trigger in [`spec-lifecycle.md § Visualize sub-step`](../spec-workflows/spec-lifecycle.md#visualize-triggers) applies, hand off to [`visualize-spec.prompt.md`](visualize-spec.prompt.md); else write `Skipped — <reason>` under `## Architecture`.
6. **Gate** — post per-spec summary (ID + path, FR/AC count, Split Decision, `siblings:` / `depends-on:`, Visualize status, `domain-refs:` or net-new justification, open questions). Wait for explicit approval. Then hand off to [`plan-spec.prompt.md`](plan-spec.prompt.md); Plan advances the first spec with no unmet `depends-on:` first.

## Hard rules

- No `## Tasks` table here — see [`spec-lifecycle.md § Rules #2`](../spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify).
- No skipping the question round, even for trivial CRs — see [`boundaries.md § Never do #2`](../boundaries.md#never-skip-specify).
- No requirements gate without `## Split Decision` filled in this spec + all siblings — see [`spec-lifecycle.md § Rules #9`](../spec-workflows/spec-lifecycle.md#split-check-mandatory).
