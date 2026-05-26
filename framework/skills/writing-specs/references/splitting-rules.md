# Splitting Rules

*Last updated: 2026-05-14*

Machine-lookup tables for the spec-split decision: definitions (§1), Specify-stage triggers (§2 T1–T6), Plan-stage
safety net (§3 P1–P3), and keep-as-one exceptions (§4 E1–E5). Cite these IDs from specs under `## Split Decision`.
Procedure and worked examples live in [`docs/splitting-specs.md`](../../../../docs/splitting-specs.md).

The check runs twice: once during **Specify** against FR clusters, and
once during **Plan** as a safety net if decomposition reveals missed
signals.

## § 1 Definitions

- **Independently testable:** an FR cluster whose acceptance criteria can
  be verified without any other cluster's FRs being implemented,
  deployed, or seeded. Stub / mock inputs at the cluster boundary are
  acceptable; shared live state is not.
- **FR cluster:** one or more FRs sharing the same acceptance surface —
  the same user action, output contract, or data entity. A single FR is
  its own cluster.
- **Autonomous spec:** a spec whose ACs can all be signed off without
  waiting for a sibling spec to reach `done`.

## § 2 Specify-stage triggers (must-split)

Evaluate **before** the requirements gate, using FRs, ACs, front-matter
`affected-repos`, and the Separability answer from
[`questions/cr-questions.md`](../../../spec-workflows/questions/cr-questions.md).
If **any** trigger fires, propose a split; do not proceed to the gate
until the human decides.

| #  | Trigger                                                                                          | Signal source       |
|----|--------------------------------------------------------------------------------------------------|---------------------|
| T1 | ≥2 FR clusters meet the § 1 independent-testability definition                                   | FRs + ACs           |
| T2 | FR clusters target different bounded contexts and share no AC                                    | FRs + module map    |
| T3 | FR clusters target different repos in `affected-repos`                                           | Front-matter        |
| T4 | FR clusters depend on different data entities with no shared schema change                       | FRs + data model    |
| T5 | One FR cluster is blocked by an external dependency while another is not                         | Separability answer |
| T6 | Human's Separability answer explicitly identifies FRs that can ship and be verified on their own | Separability answer |

## § 3 Plan-stage safety net (discovered later)

Evaluate after task decomposition. If missed at Specify:

| #  | Signal                                                           | Action                                             |
|----|------------------------------------------------------------------|----------------------------------------------------|
| P1 | >12 tasks produced                                               | Stop. Flip `status` back to `specify`. Re-run § 2. |
| P2 | >2 bounded contexts span the task table with no shared AC        | Same as P1                                         |
| P3 | Plan reveals a task group with zero dependencies on other groups | Same as P1                                         |

Plan never writes tasks after flipping back; Specify re-runs from
Step 4a of [`create-spec.prompt.md`](../../../prompts/create-spec.prompt.md).

## § 4 Keep-as-one exceptions (must-not-split)

A trigger fire does **not** force a split if any of the following apply.
Record the exception used under `## Split Decision` in the spec.

| #  | Exception                                                      | Why                                                                                                                                                                                                                                                                             |
|----|----------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| E1 | All ACs share a single data-write path                         | Splitting forces coordinated deploys, increasing risk                                                                                                                                                                                                                           |
| E2 | FR clusters share >50% of the FRs (overlap by reference)       | Split would be cosmetic, not structural                                                                                                                                                                                                                                         |
| E3 | Rollback requires atomic revert of all FRs                     | Splitting breaks the rollback contract                                                                                                                                                                                                                                          |
| E4 | One cluster is a trivial extension (≤1 FR, ≤1 file) of another | Not worth the spec overhead                                                                                                                                                                                                                                                     |
| E5 | Documentation corpus                                           | All tasks ship documentation files under a single shared index, share a single closure metric, and share a single conformance-pass; splitting forces three-way coordination of artifacts that share no live state. Apply only when the spec ships zero behavioural code change. |
