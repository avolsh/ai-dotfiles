# Splitting Rules

*Last updated: 2026-04-29*

When and how to split a spec into multiple autonomous specs. The check
runs twice: once during **Specify** against FR clusters, and once during
**Plan** as a safety net if decomposition reveals missed signals.

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

| # | Trigger | Signal source |
|---|---|---|
| T1 | ≥2 FR clusters meet the § 1 independent-testability definition | FRs + ACs |
| T2 | FR clusters target different bounded contexts and share no AC | FRs + module map |
| T3 | FR clusters target different repos in `affected-repos` | Front-matter |
| T4 | FR clusters depend on different data entities with no shared schema change | FRs + data model |
| T5 | One FR cluster is blocked by an external dependency while another is not | Separability answer |
| T6 | Human's Separability answer explicitly identifies FRs that can ship and be verified on their own | Separability answer |

## § 3 Plan-stage safety net (discovered later)

Evaluate after task decomposition. If missed at Specify:

| # | Signal | Action |
|---|---|---|
| P1 | >12 tasks produced | Stop. Flip `status` back to `specify`. Re-run § 2. |
| P2 | >2 bounded contexts span the task table with no shared AC | Same as P1 |
| P3 | Plan reveals a task group with zero dependencies on other groups | Same as P1 |

Plan never writes tasks after flipping back; Specify re-runs from
Step 4a of [`create-spec.prompt.md`](../../../prompts/create-spec.prompt.md).

## § 4 Keep-as-one exceptions (must-not-split)

A trigger fire does **not** force a split if any of the following apply.
Record the exception used under `## Split Decision` in the spec.

| # | Exception | Why |
|---|---|---|
| E1 | All ACs share a single data-write path | Splitting forces coordinated deploys, increasing risk |
| E2 | FR clusters share >50% of the FRs (overlap by reference) | Split would be cosmetic, not structural |
| E3 | Rollback requires atomic revert of all FRs | Splitting breaks the rollback contract |
| E4 | One cluster is a trivial extension (≤1 FR, ≤1 file) of another | Not worth the spec overhead |
| E5 | Documentation corpus | All tasks ship documentation files under a single shared index, share a single closure metric, and share a single conformance-pass; splitting forces three-way coordination of artifacts that share no live state. Apply only when the spec ships zero behavioural code change. |

## § 5 How to split

1. Identify the natural seam — usually a port, a use case boundary, or a
   bounded context edge.
2. Each sibling spec MUST be autonomous per § 1 at its own Specify gate.
3. Create one file per sibling in `<project>/docs/specs/active/` with
   the same date prefix and distinct kebab titles.
4. Cross-link in front-matter:

   ```yaml
   siblings:
     - <sibling-spec-id>
   depends-on:
     - <prerequisite-spec-id>    # omit if independent
   ```

5. The first-unblocked sibling advances to Plan first; others stay at
   `specify` until `depends-on:` entries reach `done`.
6. Record the decision in each spec under `## Split Decision`:
   - *Split into: `<sibling-ids>`. This spec owns FRs `<N, M>`.*

## § 6 Examples

A spec that adds a new entity (place-catalog context) AND a new pipeline
step (content-generation context) AND a new UI component (tobevisit-web)
— T2 + T3 fire:

- Split into 3 specs: one per context/repo.
- `depends-on:` chain: entity → pipeline → UI.

A spec that modifies 3 steps in the same pipeline, all writing the same
shared output — E1 applies:

- Keep as one spec. Record: *Kept as one spec — E1 shared data-write path.*

A CR bundling "fetch photos from 3 providers" + "AI vision filter" +
"upload to R2" + "orchestration use case":

- T1 fires (provider adapters, AI filter, storage each independently
  testable with mocks).
- Split into two specs: infrastructure (adapters + storage + domain
  model) and pipeline (use case + step wiring). Infrastructure has no
  `depends-on:`; pipeline `depends-on:` infrastructure.
