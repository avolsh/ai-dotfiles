---
description: "Visualize sub-step — populate the spec's Architecture section with Mermaid diagrams"
---
#skill:writing-specs
#skill:agent-protocol
Visualize sub-step inside Specify — spec stays at `status: specify` throughout. Populate `## Architecture` with Mermaid, then hand back to [`create-spec.prompt.md`](create-spec.prompt.md) for the requirements gate. Lifecycle: [`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md).

## Preconditions
- Spec at `status: specify` with `## Requirements` + `## Acceptance Criteria` drafted, and a trigger from [`spec-workflows/README.md § Visualize`](../spec-workflows/README.md#visualize-sub-step-when-mandatory) applies. No trigger → write `Skipped — <reason>` under `## Architecture` and do not run this prompt.

## Steps
1. **Load context** — the spec, project `docs/architecture/` (system overview, module map), reference schemas in `affected-docs`.
2. **Choose diagram types** — minimum set; ≤30 nodes each. Pipeline / data flow → `flowchart` LR; multi-service async → `sequenceDiagram`; schema / entity → `erDiagram` or `classDiagram`; entity state machine → `stateDiagram-v2`; UI composition → `flowchart` with subgraphs.
3. **Write `## Architecture`** — replace placeholder. Precede each diagram with a one-sentence caption: *what it shows and from whose perspective*. Use Before/After pairs when the spec changes existing flow.
4. **Update + hand back** — keep `status: specify`, update `*Last updated:*` (if diagrams reveal new requirements or scope conflicts, return to Specify and revise FRs/ACs first). Then post a short summary (diagram types used, key design decisions) and return control to [`create-spec.prompt.md`](create-spec.prompt.md) for the requirements gate.

## Hard rules
- Status stays at `specify` — Visualize is not a separate status. Diagrams MUST match approved requirements, not aspiration. One-line captions only — never paraphrase the diagram in prose. Never write `## Tasks` here.
