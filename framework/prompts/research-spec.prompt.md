---
description: "Specify stage — create a RES spec for research / spike / POC / vibe-coding work"
---
#skill:writing-specs

Specify stage for RES — iterative research/spike/POC/vibe-coding lane. Hard gate at the end — do not write `## Tasks`. Lifecycle + gate semantics: [`spec-lifecycle.md § RES exception`](../spec-workflows/spec-lifecycle.md#res-exception). For CR/IMP, use [`create-spec.prompt.md`](create-spec.prompt.md); for BUG, use [`bug-triage.prompt.md`](bug-triage.prompt.md).

## Preconditions

- Target project identified; user wants a RES spec (a hypothesis to test, a spike to run, a vibe-coding session with a defined kill criterion).
- The user CAN state the hypothesis in one sentence. If not, stop and refine — research without a hypothesis is a survey, not a spike.

## Steps

1. **Load context** — your agent's instructions file (`CLAUDE.md`, `AGENTS.md`, or `.github/copilot-instructions.md` — pick the one for your agent), [`spec-types.md`](../spec-workflows/spec-types.md), [`res-questions.md`](../spec-workflows/questions/res-questions.md), [`RES-TEMPLATE.md`](../spec-workflows/templates/RES-TEMPLATE.md), and project `docs/architecture/module-map.md` if it exists.
2. **Ask exactly 5 questions** per [`res-questions.md`](../spec-workflows/questions/res-questions.md). All 5 are mandatory in the first round: hypothesis (Q1), smallest experiment (Q2), kill criteria (Q3), sandbox path (Q4), deliverable shape (Q5). Wait for answers.
3. **Create the spec** — delegate to [`<system>/agents/spec-author.md`](../agents/spec-author.md) in research mode. Inputs: `spec_type: RES`, `title`, `project_root`, `date`, `owner`, `question_answers` (the 5 Q&As from Step 2). The agent returns `spec_path` and structured output per its Research-mode contract. *Fallback (no `Agent` tool): inline the agent's § Research mode Steps from its file.*
4. **Split check** — **SKIPPED for RES.** The iterative loop absorbs scope changes that would normally trigger a split; splitting a RES mid-loop is almost always wrong (see [`RES-TEMPLATE.md § Split Decision`](../spec-workflows/templates/RES-TEMPLATE.md)). The spec body's `## Split Decision` is auto-filled with *"Kept as one — RES iterative loop"* by the agent.
5. **Visualize** — typically SKIPPED for RES. The agent writes `Skipped — exploratory; architecture decisions deferred to promoted CR/IMP if applicable` in `## Architecture`. Override only if the spike specifically tests an architecture proposal.
6. **Gate** — post per-spec summary (ID + path, hypothesis verbatim, kill-criteria shape, sandbox path, deliverable shape, `domain-refs:` or net-new justification). Wait for explicit approval. Then hand off to [`plan-spec.prompt.md`](plan-spec.prompt.md) — RES tasks are typically light ("set up sandbox", "run experiment N", "record findings").

## Hard rules

- No `## Tasks` table here — see [`spec-lifecycle.md § Rules #2`](../spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify).
- No skipping any of the 5 questions — see [`res-questions.md § How to use`](../spec-workflows/questions/res-questions.md).
- `code-location:` MUST NOT be inside `src/` of any repo. The validator enforces this.
- No `risk: trivial` on RES specs — the lanes are incompatible (Trivial is one-shot, RES is iterative). See [`spec-types.md`](../spec-workflows/spec-types.md).
- Every `in-progress → specify` backflip MUST add a row to `## Iteration Log` — see [`spec-lifecycle.md § RES exception`](../spec-workflows/spec-lifecycle.md#res-exception).
