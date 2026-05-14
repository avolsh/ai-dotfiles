# Splitting Specs

*Last updated: 2026-05-14*

Procedure for splitting a spec into autonomous siblings, plus worked examples. The trigger / exception ID tables (§1–§4) used to drive the split decision live in [`framework/skills/writing-specs/references/splitting-rules.md`](../framework/skills/writing-specs/references/splitting-rules.md) — cite those IDs from `## Split Decision`.

---

## When the check runs

Twice per spec lifecycle:

- **Specify stage** — evaluate the §2 must-split triggers against FR
  clusters before the requirements gate. If any trigger fires, propose a
  split and do not proceed to the gate until the human decides.
- **Plan stage** — re-evaluate the §3 safety-net signals after task
  decomposition. If a signal fires, stop, flip `status` back to
  `specify`, and re-run §2.

A trigger fire does not force a split if a §4 keep-as-one exception
applies; record the exception used under `## Split Decision`.

---

## § 5 How to split

1. Identify the natural seam — usually a port, a use case boundary, or a
   bounded context edge.
2. Each sibling spec MUST be autonomous per §1 (in the rules file) at its
   own Specify gate.
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

---

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
