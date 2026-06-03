---
description: "Visualize sub-step — populate the spec's Architecture section with Mermaid diagrams and/or Figma frames"
---
#skill:writing-specs
Visualize sub-step inside Specify — spec stays at `status: specify` throughout. Populate `## Architecture` with Mermaid (structure/flow/schema) and/or Figma frames (UI surfaces), then hand back to [`create-spec.prompt.md`](create-spec.prompt.md) for the requirements gate. Lifecycle: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md).

## Preconditions
- Spec at `status: specify` with `## Requirements` + `## Acceptance Criteria` drafted, and a trigger from [`spec-lifecycle.md § Visualize sub-step`](../spec-workflows/spec-lifecycle.md#visualize-triggers) applies. No trigger → write `Skipped — <reason>` under `## Architecture` and do not run this prompt.

## Steps
1. **Load context** — the spec, project `docs/architecture/` (system overview, module map), reference schemas in `affected-docs`.
2. **Choose the medium** — minimum set; ≤30 nodes per diagram. Pipeline / data flow → `flowchart` LR; multi-service async → `sequenceDiagram`; schema / entity → `erDiagram` or `classDiagram`; entity state machine → `stateDiagram-v2`. **UI surface (screen / view / component) → Figma, not Mermaid:** link the frames (file key + node IDs) and embed screenshots; use a `flowchart` with subgraphs only for navigation/composition, never for visual design.
3. **Write `## Architecture`** — replace placeholder. Precede each diagram or Figma frame with a one-sentence caption: *what it shows and from whose perspective*. Use Before/After pairs when the spec changes existing flow.
4. **Update + hand back** — keep `status: specify`, update `*Last updated:*` (if diagrams reveal new requirements or scope conflicts, return to Specify and revise FRs/ACs first). Then post a short summary (diagram types used, key design decisions) and return control to [`create-spec.prompt.md`](create-spec.prompt.md) for the requirements gate.

## Hard rules
- Status stays at `specify` (Visualize is a sub-step, not a status — see [`spec-lifecycle.md § Rules #8`](../spec-workflows/spec-lifecycle.md#visualize-not-a-status)). Diagrams and Figma frames MUST match approved requirements, not aspiration. One-line captions only — never paraphrase the diagram or frame in prose. No `## Tasks` table here — see [`spec-lifecycle.md § Rules #2`](../spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify).
