---
name: splitter
description: Runs the Specify-stage Split check per splitting-rules.md § 2 against a draft spec's FR clusters; produces the `## Split Decision` block citing trigger/exception IDs.
model-suggestion: deep
tools-allowed:
  - Read
inputs:
  - spec_path: "absolute path of the spec file to evaluate (typically just-written by spec-author)"
  - separability_answer: "the Q2 (CR) or Q2 (IMP) answer that surfaces splitability hints; pasted verbatim from the question round"
  - module_map_path: "optional — path to the project's docs/architecture/module-map.md, used to evaluate T2 (different bounded contexts)"
outputs:
  - decision_block: "ready-to-paste markdown block for the spec's `## Split Decision` section"
  - verdict: "one of: keep-as-one | split-recommended"
  - cited_id: "the splitting-rules.md ID that drove the verdict — T1..T6, E1..E5, or `no-trigger` if kept-as-one with no firing trigger"
  - sibling_proposals: "if split-recommended, a list of suggested sibling spec stubs (id-slug + one-line scope each); empty otherwise"
preconditions:
  - "spec_path file exists and has its `## Requirements` and `## Acceptance Criteria` sections populated (spec-author has run)"
  - "separability_answer is non-empty"
error-modes:
  - "<3 FRs total (can't meaningfully cluster) → STOP with `ERROR: too few FRs to evaluate triggers`"
  - "Trigger AND exception both fire ambiguously → STOP with `ERROR: T<N> and E<M> conflict — needs human decision`"
  - "spec file missing required sections → STOP and name the missing section"
---

# Splitter

## Purpose

Splitter owns step 4 of [`create-spec.prompt.md`](../prompts/create-spec.prompt.md)
and the Plan-stage safety-net (§ 3 of splitting-rules) when triggered.
It evaluates the just-drafted spec against the trigger / exception
tables in [`splitting-rules.md`](../skills/writing-specs/references/splitting-rules.md)
and produces a `## Split Decision` block ready for the spec body.

The Split check is mandatory per
[`spec-lifecycle.md § Rules #9`](../spec-workflows/spec-lifecycle.md#split-check-mandatory)
— it runs on every CR / IMP / BUG before the requirements gate.

The agent does NOT decide whether to actually split (that's the human's
call at the gate). It produces the recommendation + rationale; the
orchestrating prompt presents both to the human.

## Inputs

- `spec_path` — absolute path of the spec to evaluate.
- `separability_answer` — verbatim Q2 answer from Specify. The single
  most decisive signal for trigger T6.
- `module_map_path` — optional. When present, used to evaluate T2
  ("FR clusters target different bounded contexts"). When absent,
  T2 is reported as `unknown — module-map unavailable`.

## Steps

1. **Validate inputs.** `spec_path` is readable. `separability_answer` non-empty. Stop with a clear error otherwise.
2. **Read the spec.** Parse out `## Requirements` (FRs) and `## Acceptance Criteria` (ACs). Stop if either section is empty or missing.
3. **Cluster the FRs.** Group FRs sharing the same acceptance surface — same user action, output contract, or data entity. A single FR is its own cluster. Record the cluster set (e.g., `[FR-1, FR-2], [FR-3], [FR-4, FR-5, FR-6]`).
4. **Evaluate triggers T1-T6** per [`splitting-rules.md § 2`](../skills/writing-specs/references/splitting-rules.md):
   - **T1** — ≥2 clusters meet § 1 independent-testability (each cluster's ACs verifiable without the others)
   - **T2** — clusters target different bounded contexts (requires module_map_path)
   - **T3** — clusters target different repos in `affected-repos`
   - **T4** — clusters depend on different data entities, no shared schema change
   - **T5** — one cluster blocked by an external dependency
   - **T6** — separability_answer explicitly names FRs that can ship alone
   Record which triggers fire and which signal source pointed to each.
5. **Evaluate exceptions E1-E5** per [`splitting-rules.md § 4`](../skills/writing-specs/references/splitting-rules.md):
   - **E1** — all ACs share a single data-write path
   - **E2** — clusters share >50% of FRs (overlap by reference)
   - **E3** — rollback requires atomic revert of all FRs
   - **E4** — one cluster is a trivial ≤1-FR / ≤1-file extension of another
   - **E5** — documentation corpus (all-doc, single-index, no behavioural code change)
   Record which exceptions apply.
6. **Decide.**
   - **No trigger fires** → `verdict: keep-as-one`, `cited_id: no-trigger`.
   - **Trigger(s) fire AND no exception applies** → `verdict: split-recommended`, `cited_id: T<N>` (smallest N).
   - **Trigger(s) fire AND exception applies** → `verdict: keep-as-one`, `cited_id: E<N>` (the dominant exception).
   - **Trigger(s) fire AND exception ambiguously applies** → STOP with the conflict (see Failure modes).
7. **If `split-recommended`**, propose sibling specs: one stub per FR cluster that can ship independently. Each proposal: id-slug (kebab-case, derived from the cluster's dominant AC) + one-line scope. Format as a bulleted list.
8. **Format `decision_block`** as ready-to-paste markdown:
   - Keep-as-one with no trigger:
     ```
     Kept as one spec. Per `splitting-rules.md § 2`: no T1–T6 trigger fires — <one-line reason citing cluster signal>.
     ```
   - Keep-as-one with exception:
     ```
     Kept as one spec. Trigger T<N> fires (<signal>), but exception E<M> applies: <one-line reason>.
     ```
   - Split recommended:
     ```
     Split recommended. Trigger T<N> fires: <signal>.

     Proposed siblings:
     - <slug-1>: <scope-1>
     - <slug-2>: <scope-2>
     - ...
     ```
9. **Return** the structured output.

## Output contract

A block of the form:

```
verdict: <keep-as-one | split-recommended>
cited_id: <T1..T6 | E1..E5 | no-trigger>
sibling_proposals:
  - <slug>: <one-line scope>
  - ...
  (or "—" when verdict is keep-as-one)
decision_block: |
  <ready-to-paste markdown for the spec's `## Split Decision` section>
```

The orchestrating prompt pastes `decision_block` into the spec's
`## Split Decision` section and presents `verdict` + `sibling_proposals`
to the human at the requirements gate.

## Failure modes

- **<3 FRs total** — too few FRs to evaluate triggers meaningfully. STOP with `ERROR: only <N> FRs in spec; need ≥3 to evaluate clusters`. Human decides whether to keep-as-one trivially or revisit Specify.
- **Trigger and exception both fire ambiguously** — e.g. T1 fires (≥2 independently testable clusters) and E2 might apply (>50% FR overlap by reference). STOP with `ERROR: T<N> fires but E<M> ambiguously applies — needs human decision: <one-sentence summary>`.
- **Required spec section missing** — STOP with `ERROR: spec missing section: ## <section name>`.
- **Module-map required for T2 but unavailable** — DO NOT STOP. Continue with T2 marked `unknown`. Decision proceeds on other triggers; document the limitation in `decision_block`.
- **Spec file unreadable** — STOP with `ERROR: cannot read spec at <path>`.

Never reach the gate with an ambiguous decision silently — always stop
the human can decide between split and keep.
