# RES Standard Questions

*Last updated: 2026-05-14*

During the Specify stage of a RES (Research / Spike / POC) spec, the
agent asks exactly **5 questions** from this list. All 5 are mandatory
in the first round; subsequent backflips re-ask only the questions
affected by the new evidence.

The full RES lifecycle and the `## Iteration Log` mandate live at
[`spec-lifecycle.md § RES exception`](../spec-lifecycle.md#res-exception).

## How to use

1. Ask **all 5 questions** in the initial Specify round. None is optional.
2. On `in-progress → specify` backflips, re-ask only the questions whose
   answers the new evidence affects. Q3 (Kill criteria) MUST be re-asked
   on every backflip — it is the loop's stop guarantee.
3. If an answer to Q2 (Smallest experiment) reveals the work needs >2
   files of non-research code, the RES spec is correctly scoped but the
   eventual `outcome: promoted-to-<id>` will need a real CR/IMP — note
   this at the gate.
4. Q4 (Sandbox path) MUST resolve outside every repo's `src/`. The
   default `research/<spec-id>/` lives at the workspace `research/`
   directory.
5. If the user cannot answer Q1 (Hypothesis) in one sentence, stop and
   refine — research without a hypothesis is a survey, not a spike.
   Suggest opening a different spec type (or a documentation task).

## Standard questions (ask all 5, single round, re-ask on backflip per § How to use)

1. **Hypothesis.** State in one sentence what claim is being tested.
   Concrete and falsifiable.
   Example: *"Vector search beats keyword search for place recommendations on the cold-cache request mix (MRR@10 +0.05 or better)."*

2. **Smallest experiment.** What is the minimum-effort setup that would
   either confirm or refute the hypothesis? List inputs, the change to
   apply, and the measurement.
   Example: *"Stand up a Redis instance, mirror 1k recent place lookups, A/B against Mongo for 24h with hit-rate + p99 latency logged."*

3. **Kill criteria.** When do we STOP iterating, regardless of where we
   are? Choose ONE shape: time-box (≤N hours / by date), token-budget
   (≤N tokens of agent context), or iteration-count (≤N backflips).
   Mixing shapes makes the criteria unenforceable.
   Example: *"≤3 backflips OR ≤8 hours of focused work, whichever first."*

4. **Code sandbox path.** Where does throwaway code live? Default
   `research/<spec-id>/`. MUST NOT be inside `src/` of any repo —
   the validator enforces this mechanically.
   Example: *"research/RES-20260520-redis-place-cache/"*

5. **Deliverable shape.** When the loop terminates, what artifact does
   the team get? Pick one or more: a one-page memo (decision-only),
   throwaway code (sandbox), a sibling CR/IMP slug (productionize the
   findings), or a negative-result writeup (for refuted hypotheses).
   Example: *"Memo + benchmarks in research/, plus a CR slug if confirmed."*

## Anti-patterns

- **Do not** start work without an answer to Q1. A hypothesis-less spike
  is a survey; open a different kind of spec.
- **Do not** mix kill-criteria shapes (e.g., "≤8 hours OR ≤3 backflips
  OR ≤200k tokens"). Choose one — combined shapes are slippery and the
  validator can't pick a winner.
- **Do not** place `code-location:` inside `src/`. The lane's sandboxing
  guarantee depends on this. The validator rejects `src/` paths at
  Specify-time.
- **Do not** treat RES as a way to dodge a CR. If you know what you want
  to build, write a CR. RES is for "I don't know yet."
- **Do not** elect `risk: trivial` — the lanes are incompatible. Trivial
  is one-shot, RES is iterative. See
  [`spec-types.md § Trivial lane`](../spec-types.md).
- **Do not** skip the `## Iteration Log` row on a backflip. The validator
  flags backflips without a corresponding entry as drift.
