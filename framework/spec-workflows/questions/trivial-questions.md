# Trivial-lane Standard Questions

*Last updated: 2026-05-14*

During the **combined `specify+plan` gate** for a Trivial-lane spec
(`risk: trivial` or `severity: trivial`), the agent asks exactly **3
questions** from this list. There is no separate Plan-stage round.

The full Trivial-lane definition — eligibility criteria, combined-gate
content shape, status sequence — lives at
[`spec-lifecycle.md § Trivial lane`](../spec-lifecycle.md#trivial-lane).

## How to use

1. Ask **all three** questions in a single round. None is optional.
2. If any answer reveals the change is NOT eligible for the lane (e.g.,
   "actually touches 4 files", "needs a depends-on:", "changes a
   prompt"), STOP. Drop `trivial`, re-run the standard CR / BUG / IMP
   question round on the full track.
3. The validator (`scripts/validate-specs.py`, task T4 of
   IMP-20260514-trivial-lane) double-checks eligibility mechanically
   when the spec lands — the questions exist to catch the obvious
   mismatches before the spec is even drafted.

## Standard questions (ask all 3, single round)

1. **Scope ≤ 2 files.** Which files will the change touch? List every
   `affected-code` and `affected-docs` path. Total MUST be ≤ 2. If you
   need a third file even for a hand-wave — this change is not trivial.

2. **No schema, boundary, or prompt change.** Does the change touch any
   of: front-matter schema, baseline / requirements docs under
   `docs/requirements/`, type / API contracts, AI prompts under
   `framework/prompts/` or project `.github/copilot/prompts/`,
   `framework/boundaries.md`, or any project's
   `.github/copilot-instructions.md § Boundaries` section? If yes to any
   — drop `trivial`.

3. **One AC sufficient.** Can the change be verified by a single
   acceptance criterion (one Given / When / Then)? If you find yourself
   wanting two ACs to cover different failure modes — this change is
   not trivial.

## Anti-patterns

- **Do not** soften an answer to fit the lane. If the change actually
  touches 3 files, say so and drop `trivial`. The lane saves human time
  on small work, not on misclassified work.
- **Do not** chain two trivial specs back-to-back to dodge a non-trivial
  change. If the work is one indivisible behavior change spanning >2
  files, it is one standard spec, not two.
- **Do not** elect `trivial` for a refactor "while you're in there." If
  the change couples a small intent with a larger rearrangement, those
  are two specs (or one standard spec). See
  [`boundaries.md § Never do #9`](../../boundaries.md) on gold-plating.
- **Do not** apply this lane to RES specs. RES is iterative
  (`specify ⇄ in-progress`); the Trivial lane is one-shot. The two are
  incompatible — see [`spec-types.md § Trivial lane`](../spec-types.md).
