# IMP Standard Questions

*Last updated: 2026-04-29*

During the Specify stage, the agent asks up to **10 questions** from this
list plus any improvement-specific ones. The human answers before
requirements are written.

## How to use

- Pick the questions relevant to this IMP — not all 10 always fire.
- **Q1 (Retrofit scope) and Q2 (Partial-application risk) are mandatory
  on every round.** They preserve the Scope and Separability signals
  required by the Split check in
  [`splitting-rules.md § 2`](../../skills/writing-specs/references/splitting-rules.md).
- Reorder Q3-Q10 freely so the most blocking questions come first.
- Drop questions already answered in the user's prompt or existing docs.
- Keep each question answerable in one short paragraph or table row.

## Standard questions (ask ≤10 per round)

1. **Retrofit-vs-rewrite scope:** Is this a targeted retrofit,
   documentation convention, refactor, or replacement? Which files,
   modules, or workflows are in scope and explicitly out of scope?
   Example: "Is this confined to baseline docs, or should prompts and
   templates change too?"
2. **Partial-application risk:** Can any part ship and be verified on its
   own, or would partial application leave the system in a worse
   convention / runtime state? Which FRs must ship together?
   Example: "Can the new convention land before templates reference it?"
3. **Measurable benefit:** What concrete metric proves the improvement
   worked? Include baseline and target values.
   Example: "Does this reduce duplicate rule sites from 4 to 1?"
4. **Baseline citation impact:** Which `docs/requirements/` baselines or
   REQ-IDs does this change, supersede, or cite? If none, what is the
   one-line justification for omitting `cites-reqs:`?
   Example: "Does this change `REQ-PCE-005`, or is it convention-only?"
5. **Rollback / revert:** How should the change be reverted if it creates
   churn or breaks an established workflow?
   Example: "Revert the prompt change only, or revert the template and
   reference page together?"
6. **Success / failure metric:** What observable result marks success,
   and what result means the improvement failed?
   Example: "Success is all three templates carrying the block; failure
   is any template missing it."
7. **Scope-creep guardrail:** What related cleanup, enforcement, or
   adoption work is out of scope for this IMP?
   Example: "No CI enforcement, no downstream project adoption."
8. **Dependencies / sequencing:** Which specs, docs, migrations, or
   external approvals must complete first? Which task can start first?
   Example: "Must the parent baseline IMP be `done` before Plan?"
9. **Benefit validator:** Who or what validates that the benefit is real:
   grep evidence, test output, performance metric, reviewer approval, or
   production observation?
   Example: "Manual grep evidence is enough for docs-only convention work."
10. **Reversion threshold:** At what cost, complexity, or risk threshold
    should the agent stop and re-Specify instead of continuing?
    Example: "Re-Specify if the plan grows past 8 tasks or adds code."

## Anti-patterns

- **Do not** ask CR feature-design questions unless the improvement
  changes product behaviour.
- **Do not** accept "cleaner" as the measurable benefit; require an
  observable metric.
- **Do not** let a refactor hide a new feature; split it into a CR.
- **Do not** skip Q2 — independent improvement clusters may need
  separate IMP specs unless an exception applies.
