---
id: IMP-20260616-slim-spec-output-and-figma-design-system
type: IMP
date: 2026-06-16
status: specify
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/writing-specs.md
  - docs/spec-format.md
  - docs/spec-templates-guide.md
  - framework/skills/writing-specs/SKILL.md
  - framework/skills/writing-specs/references/authoring-steps.md
  - framework/spec-workflows/templates/CR-TEMPLATE.md
  - framework/spec-workflows/templates/IMP-TEMPLATE.md
  - framework/spec-workflows/templates/BUG-TEMPLATE.md
  - framework/spec-workflows/spec-lifecycle.md
  - framework/prompts/plan-spec.prompt.md
  - framework/prompts/visualize-spec.prompt.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
---
# IMP-20260616-slim-spec-output-and-figma-design-system
*Last updated: 2026-06-16*

> No `## Cost Estimate` section — this IMP applies FR-5 to itself.

## Summary
- **Goal:** Make the Specify step produce specs that are 30–50% shorter and reuse a Figma design system instead of duplicating UI primitives.
- **Scope:** Extend the existing `writing-specs` skill (`SKILL.md`, `references/authoring-steps.md`), its docs (`writing-specs.md`, `spec-format.md`, `spec-templates-guide.md`), the `spec-workflows` templates + `spec-lifecycle.md`, and the two workflow prompts (`plan-spec`, `visualize-spec`). Convention/guidance only.
- **Out of scope:** New skills, a validator hook, the front-matter schema, and any behavioural code.

## Current State
Generated specs are too long to re-read during Specify. Across 51 archived specs (ai-dotfiles, workspace `docs/`, tobevisit-content), mass concentrates in **Requirements (avg 63 lines, max 428)** and **Acceptance Criteria (avg 59, max 298)**; 17 of 24 content specs exceed 270 lines (one at 1221). The framework already states qualitative "Writing style", "Compression pass", and "Deduplication" rules in [`docs/writing-specs.md`](../../../docs/writing-specs.md), but:
- No measurable length budget exists anywhere (grep confirms).
- The Compression pass is advisory — no authoring step runs it, no self-review item measures it.
- Templates mandate ~13 H2 sections, several overlapping (`Summary`↔`Current State`↔`Proposed Improvement`, already flagged at `writing-specs.md:55`); the `Cost Estimate` section is fixed overhead the human rarely uses.

The Visualize sub-step routes UI surfaces to Figma ([`visualize-spec.prompt.md`](../../../framework/prompts/visualize-spec.prompt.md) step 2) but says only "link the frames." No rule requires reusing design-system variables/components/text styles or forbids duplication, even though the Figma MCP skills (`figma-generate-library`, `figma-use` working-with-design-systems) and tools (`search_design_system`, `get_variable_defs`, `get_libraries`) exist.

## Proposed Improvement
1. Add a **measurable length budget** to the writing-style rules: per-section soft caps + a whole-spec body soft cap, with a one-line justification escape hatch when a spec must exceed it (same pattern the prior `IMP-20260513-slim-*` siblings used for per-file caps).
2. Promote the **Compression pass** from advisory prose to a **gated authoring step**: it runs before the requirements gate and reports a before/after line count; add the matching self-review checklist item.
3. Tighten **FR/AC formatting**: one-line FRs, one Given/When/Then per FR-cluster (not per FR), ban prose restating a table/schema. Mirror the caps as inline hints in the templates.
4. **Remove the mandatory `## Cost Estimate` section** from the standard-track templates and every framework file that mandates or refreshes it.
5. Add a **design-system-first hard rule** to the Visualize sub-step: discover the existing design system first, reuse variables/components/text styles, never duplicate them; when shared primitives are missing, build them as a library (`figma-generate-library` / working-with-design-systems) rather than ad-hoc frames; record the library source in the Architecture caption.

**Measurable benefit:** re-drafting 3 representative archived specs under the new rules yields a body ≥30% shorter (target 30–50%) with no FR/AC loss; the Visualize prompt names design-system reuse as a hard rule.

## Requirements
- FR-1: [`docs/writing-specs.md`](../../../docs/writing-specs.md) MUST define a measurable length budget: per-section soft caps (Summary ≤6 lines; Current State / Problem Statement ≤12; Proposed Improvement ≤12; one line per FR; one Given/When/Then block ≤6 lines per FR-cluster; one line per Out-of-Scope item) and a standard-track whole-spec **body** soft cap of ≤120 lines (excluding front-matter, Architecture diagrams, and Closure). Exceeding any cap MUST require a one-line justification at the top of that section.
- FR-2: The spec-authoring procedure ([`references/authoring-steps.md § A`](../../../framework/skills/writing-specs/references/authoring-steps.md)) MUST include a gated Compression-pass step that runs before the requirements gate and records a before/after line count; the self-review additions in [`docs/writing-specs.md`](../../../docs/writing-specs.md) MUST include a matching checklist item.
- FR-3: The FR/AC formatting rules in [`docs/spec-format.md`](../../../docs/spec-format.md) MUST require one-line FRs, one Given/When/Then block per FR-cluster (not per FR), and MUST forbid prose that restates a table or schema. The CR/IMP templates MUST carry these caps as inline section hints.
- FR-4: The standard-track CR and IMP templates MUST NOT contain a `## Cost Estimate` section; every other framework file that mandates, fills, or refreshes that section (templates, `authoring-steps.md`, `plan-spec.prompt.md`, `spec-lifecycle.md`, `spec-format.md`, `spec-templates-guide.md`) MUST be updated to remove the requirement. No file MAY still instruct an author to produce it on the standard track.
- FR-5: The reduction MUST be self-demonstrating: this IMP and any spec authored after the change MUST conform to the FR-1 budget.
- FR-6: [`framework/prompts/visualize-spec.prompt.md`](../../../framework/prompts/visualize-spec.prompt.md) MUST state a hard rule that, before creating any Figma frame for a UI surface, the agent discovers the existing design system (`search_design_system` / `get_variable_defs` / `get_libraries`), reuses its variables/components/text styles, and MUST NOT hardcode or duplicate them; when a required shared primitive is absent it MUST be built as a design-system library (`figma-generate-library` / working-with-design-systems skills). The Architecture caption MUST record the design-system source (library file key).
- FR-7: [`spec-lifecycle.md § Visualize sub-step`](../../../framework/spec-workflows/spec-lifecycle.md) MUST link to the FR-6 rule rather than restate it (single-source per the framework's canonical-rule convention).

## Acceptance Criteria
### AC-1: Length budget is measurable (FR-1, FR-3)
Given the slim complete at HEAD
When `docs/writing-specs.md` and `docs/spec-format.md` are read
Then they state numeric per-section soft caps, a ≤120-line standard-track body cap, the one-line-justification escape hatch, and the one-G/W/T-per-cluster + no-prose-restating-tables rules.

### AC-2: Compression pass is gated (FR-2)
Given the slim complete at HEAD
When `references/authoring-steps.md § A` and the `writing-specs.md` self-review list are read
Then a numbered Compression-pass step exists that runs before the requirements gate and records before/after line counts, and a matching self-review checklist item exists.

### AC-3: Cost Estimate removed (FR-4)
Given the slim complete at HEAD
When `grep -rl "Cost Estimate" framework/ docs/` runs (excluding `docs/specs/`)
Then no standard-track template, authoring step, prompt, or guide instructs the author to produce a `## Cost Estimate` section.

### AC-4: Reduction is real (FR-5)
Given 3 representative archived specs re-drafted under the new rules
When each re-draft's body line count is compared to its original
Then each is ≥30% shorter with no FR or AC dropped, and this IMP's own body is ≤120 lines.

### AC-5: Design-system-first rule present (FR-6, FR-7)
Given the slim complete at HEAD
When `visualize-spec.prompt.md` is read
Then it states the design-system discovery + reuse + no-duplication hard rule, names `figma-generate-library`/working-with-design-systems for missing primitives, requires the library-source caption, and `spec-lifecycle.md` links to it without restating it.

## Architecture
Skipped — convention/guidance change at the spec-authoring layer; no bounded context, schema, or UI surface. (FR-6 governs Figma usage in *other* specs, not this one.)

## Out of Scope
- OS-1: A mechanical spec-validator check for the budget — chosen enforcement is gated self-review, not tooling.
- OS-2: Front-matter schema and the `Cost Estimate` data itself in already-archived specs — only the going-forward requirement changes.
- OS-3: Merging the Summary / Current State / Proposed Improvement sections — kept as-is per the human decision; only their caps tighten.
- OS-4: The RES and Trivial lanes' section sets — already reduced; untouched beyond inheriting FR-1 caps where applicable.

## Split Decision
Keep-as-one. T1 fires (two independently-testable FR clusters: slimming FR-1…FR-5 and Figma FR-6…FR-7), but exception **E5 (documentation corpus)** dominates: zero behavioural code, all artifacts are markdown under the framework sharing one closure metric and one conformance pass; both clusters extend the same Specify-stage guidance and overlap in `spec-lifecycle.md`. Splitting would force needless coordination.

## Tasks
Pending — Plan stage only.

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- `docs/writing-specs.md` — length budget + gated compression pass + self-review item.
- `docs/spec-format.md`, `docs/spec-templates-guide.md` — FR/AC caps; remove Cost Estimate references.
- `framework/skills/writing-specs/{SKILL.md,references/authoring-steps.md}` — gated step; drop Cost Estimate authoring/refresh.
- `framework/spec-workflows/templates/{CR,IMP,BUG}-TEMPLATE.md` — inline caps; remove Cost Estimate.
- `framework/spec-workflows/spec-lifecycle.md`, `framework/prompts/plan-spec.prompt.md` — drop Cost Estimate refresh; lifecycle links to the Visualize design-system rule.
- `framework/prompts/visualize-spec.prompt.md` — design-system-first hard rule.

## Rollout / migration notes
- Documentation/convention only; no code, no data reshaping. Existing archived specs keep their `Cost Estimate` sections — the requirement change is forward-looking.
- Run `make sync-agents` / `make sync-system-templates` if any rendered agent file inherits the touched guidance.
