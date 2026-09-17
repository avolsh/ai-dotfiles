---
description: "Specify stage — create a CR or IMP spec with requirements"
---
#skill:writing-specs

Specify stage for CR / IMP. Hard gate at the end — do not write `## Tasks`. Lifecycle + gate semantics: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md). For bugs, use [`bug-triage.prompt.md`](bug-triage.prompt.md).

## Preconditions

- Target project identified; user wants a CR (change) or IMP (improvement).
- An [`explore.prompt.md`](explore.prompt.md) hand-off block, when the idea was explored first — its answers are inputs, not suggestions.

## Steps

0. **Scaffold, then ask `spec-next`** — create `docs/specs/active/<TYPE>-<YYYYMMDD>-<title>.md` from the template with front-matter and H1 only (status `specify` from birth; `risk: trivial` only if the human already elected it; a hand-off's candidate type and risk fill the front-matter), then run `python3 "$AI_DOTFILES/scripts/spec-next.py" <spec>`. Its output names the step, missing sections, questions, gate and rules for this spec; load only that output, the files under its `Load:` and the project context in step 1 (instructions file, module map, cited baselines). Re-run it after each step below — it names the next one. **Fallback:** if the command is missing or exits non-zero, say so and do step 1 in full.
1. **Load context** (full — the fallback, and the project files always) — your agent's instructions file (`CLAUDE.md`, `AGENTS.md`, or `.github/copilot-instructions.md` — pick the one for your agent), [`spec-types.md`](../spec-workflows/spec-types.md), the matching question list ([`cr-questions.md`](../spec-workflows/questions/cr-questions.md) or [`imp-questions.md`](../spec-workflows/questions/imp-questions.md)), project `docs/architecture/module-map.md`, and any `docs/domain/<feature>.md` baselines per [`docs/baseline-citations.md`](../../docs/baseline-citations.md).
2. **Ask ≤10 questions** per [`docs/spec-asking-questions.md`](../../docs/spec-asking-questions.md). Mandatory every round: CR Q1 (Scope) + Q2 (Separability); IMP Q1 (Retrofit scope) + Q2 (Partial-application risk). **With a hand-off block:** its `Q1 Scope` and `Q2 Separability` lines are those answers and its `Settled` lines answer whatever they cover — record them as given and do not ask them again, even where `spec-next` lists them as mandatory; ask only lines marked `unsettled` and questions the hand-off does not cover. Wait for answers.
3. **Create the spec** — run inline per [`writing-specs/references/authoring-steps.md § A`](../skills/writing-specs/references/authoring-steps.md) (CR/IMP) or § D (RES), using the Step 2 answers. Fill through `## Out of Scope`; set `## Design` from Step 5 or `Skipped — <reason>`.
4. **Split check** — run inline per [`authoring-steps.md § B`](../skills/writing-specs/references/authoring-steps.md) using the CR Q2 / IMP Q2 separability answer; record the verdict + cited ID under `## Split Decision`.
5. **Design Decisions, then Visualize.** Design Decisions — if any trigger in [`spec-lifecycle.md § Design Decisions sub-step`](../spec-workflows/spec-lifecycle.md#design-decisions-triggers) applies, read `docs/architecture/profile.md` + ADRs, ask ≤5 from [`design-questions.md § Spec`](../spec-workflows/questions/design-questions.md), and fill `### Decisions` / `### Risks / Trade-offs` / `### Open Questions` (a departure links a proposed ADR); else `### Decisions` reads `Skipped — <reason>`. Visualize — if any trigger in [`spec-lifecycle.md § Visualize sub-step`](../spec-workflows/spec-lifecycle.md#visualize-triggers) applies, hand off to [`visualize-spec.prompt.md`](visualize-spec.prompt.md); else write `Skipped — <reason>` under `## Design`.
6. **Gate** — post per-spec summary (ID + path, FR/AC count, Split Decision, `siblings:` / `depends-on:`, Design Decisions + Visualize status, `domain-refs:` or net-new justification, the `baseline-merge --diff <spec>` output — or the `baseline-impact: none` marker — per [`spec-lifecycle.md` Rule 13](../spec-workflows/spec-lifecycle.md#baseline-deltas), open questions). Wait for explicit approval. Then hand off to [`plan-spec.prompt.md`](plan-spec.prompt.md); Plan advances the first spec with no unmet `depends-on:` first.

## Hard rules

- No `## Tasks` table here — see [`spec-lifecycle.md § Rules #2`](../spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify).
- No skipping the question round, even for trivial CRs — see [`boundaries.md § Never do #2`](../boundaries.md#never-skip-specify).
- No requirements gate without `## Split Decision` filled in this spec + all siblings — see [`spec-lifecycle.md § Rules #9`](../spec-workflows/spec-lifecycle.md#split-check-mandatory).
