---
id: IMP-20260617-rename-architecture-section-to-design
type: IMP
date: 2026-06-17
status: in-progress
owner: alex
risk: medium
affected-repos:
  - ai-dotfiles
  - tobevisit-content
affected-docs:
  - env/ai-dotfiles/framework/spec-workflows/templates/CR-TEMPLATE.md
  - env/ai-dotfiles/framework/spec-workflows/templates/IMP-TEMPLATE.md
  - env/ai-dotfiles/framework/spec-workflows/templates/BUG-TEMPLATE.md
  - env/ai-dotfiles/framework/spec-workflows/templates/RES-TEMPLATE.md
  - env/ai-dotfiles/framework/prompts/*.prompt.md
  - env/ai-dotfiles/framework/skills/writing-specs/references/authoring-steps.md
  - env/ai-dotfiles/docs/spec-templates-guide.md
  - env/ai-dotfiles/docs/spec-format.md
  - env/ai-dotfiles/docs/specs/archived/*.md
affected-code: []
skills:
  - writing-specs
model-suggestion: default
---
# IMP-20260617-rename-architecture-section-to-design
*Last updated: 2026-06-17*
## Summary
- **Goal:** Rename the spec `## Architecture` section to `## Design` everywhere it appears or is referenced.
- **Scope:** Canonical framework templates, workflow prompts, the `writing-specs` skill, framework guide docs, and every existing spec carrying a literal `## Architecture` header (ai-dotfiles archived + workspace archived + `tobevisit-content`). Header rename plus all prose/anchor references; lands atomically.
- **Out of scope:** Generic "architecture" prose in unrelated skills; the Visualize sub-step name; vendored/legacy copies.
## Current State
The spec section that holds design output is named `## Architecture` in all four templates (CR/IMP/BUG/RES) and is referenced by that name across the workflow prompts, the `writing-specs` authoring steps, and the framework guides (`spec-templates-guide.md § Architecture`, `spec-format.md`, `spec-lifecycle.md`, etc.). In practice the Visualize sub-step now fills this section with either Mermaid architecture diagrams **or** Figma/visual-design frames, so "Architecture" undersells what belongs there. The literal `## Architecture` header also appears in ~48 existing specs across three spec corpora.
## Proposed Improvement
Rename the section to `## Design` — a name that covers both technical architecture diagrams and visual design. Apply it to the canonical sources, every reference that points at the section, and the existing spec corpus, so the convention is consistent end to end. Baseline: `grep -rl "^## Architecture"` over in-scope surfaces returns ~48 spec files plus the 4 templates; target: `0`. Rendered agent copies are regenerated from canonical so no drift remains.
## Requirements
- FR-1: The four canonical templates (CR/IMP/BUG/RES) MUST rename the `## Architecture` H2 — including its inline guidance comment — to `## Design`.
- FR-2: Every workflow reference to the section — prompts (`create-spec`, `plan-spec`, `visualize-spec`, `bug-triage`, `research-spec`, `references/figma-file-organization.md`) and the `writing-specs` authoring steps — MUST point at `## Design`, covering step text, "Fill `## Architecture`" instructions, and anchors.
- FR-3: Framework guide docs that reference the section (`spec-templates-guide.md` heading + body, `spec-format.md`, `spec-lifecycle.md`, `writing-specs.md`, `spec-workflow-guide.md`, `writing-docs.md`) MUST use `## Design`, leaving generic-architecture prose untouched.
- FR-4: Every existing spec with a literal `## Architecture` header — ai-dotfiles archived, workspace `docs/specs/archived/`, and `tobevisit-content` specs — MUST have that header renamed to `## Design`.
- FR-5: Rendered agent copies (profiles, `.github/`) MUST be regenerated from canonical via the framework `make sync-*` targets so the drift check passes.
## Acceptance Criteria
### AC-1: No section named Architecture remains (FR-1..FR-4)
Given the in-scope surfaces (canonical framework, framework docs, the three spec corpora)
When `grep -rn "^## Architecture"` is run over them (excluding `upstream/`, `_legacy/`, rendered copies)
Then it returns zero matches, and the same surfaces contain the corresponding `## Design` headers.
### AC-2: No dangling references (FR-2, FR-3)
Given the prompts, `authoring-steps.md`, and guide docs
When grepped for references to the spec "Architecture" section (e.g. `§ Architecture`, "Fill `## Architecture`")
Then none remain; each now names `## Design`, while unrelated "architecture" prose is unchanged.
### AC-3: Renders are clean (FR-5)
Given canonical edits are complete
When the framework sync targets and their drift check run
Then rendered copies match canonical and the check passes.
## Design
<!-- Renamed to `## Design` by this IMP's own FR-1/FR-4 at implementation time. -->
Skipped — mechanical documentation-convention rename; no structural or visual design to model. No Visualize trigger fires.
## Out of Scope
- OS-1: Generic "architecture" wording in unrelated skills (`api-design-principles`, `systematic-debugging`, `cost-optimization`, `nodejs-backend-patterns`) — not the spec section.
- OS-2: `docs/_legacy/` snapshots and `framework/upstream/` vendored third-party content — frozen/vendored.
- OS-3: `tobevisit-web` specs — no `## Architecture` section exists there today; no-op.
- OS-4: Renaming the "Visualize" sub-step, ADR/Decisions conventions, or `spec-format` section numbering semantics — only the section label changes.
## Split Decision
Keep-as-one. T3 fires (clusters span `ai-dotfiles` + `tobevisit-content`), but exception **E5 (documentation corpus)** dominates — zero behavioural code change, one shared closure metric (`grep` returns 0), one shared conformance pass — and **E3** applies (the rename must revert atomically). Splitting would force three-way coordination of artifacts sharing no live state.
## Tasks
> **Before starting Task 1, set status: in-progress in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|-------------|-------|--------------------------|------------|--------|-------|--------|
| 1 | Rename `## Architecture` H2 → `## Design` (incl. inline guidance comment + any "See … § Architecture" prose) in the four canonical templates. (FR-1) | `env/ai-dotfiles/framework/spec-workflows/templates/{CR,IMP,BUG,RES}-TEMPLATE.md` | — | — | writing-specs | fast | ✅ done (2026-06-17) |
| 2 | Update every spec-section reference (`## Design`, `§ Design`, "Fill `## Design`") in the five workflow prompts. (FR-2) | `env/ai-dotfiles/framework/prompts/{create-spec,plan-spec,visualize-spec,bug-triage,research-spec}.prompt.md` | template files (T1) | — | writing-specs | default | ✅ done (2026-06-17) |
| 3 | Update section references in the figma reference + `writing-specs` authoring steps. (FR-2) | `env/ai-dotfiles/framework/prompts/references/figma-file-organization.md`, `env/ai-dotfiles/framework/skills/writing-specs/references/authoring-steps.md` | — | — | writing-specs | fast | ✅ done (2026-06-17) |
| 4 | Rename the `## Architecture` heading + body refs to `## Design` in guide docs, incl. the section-ordering label and any inbound `#…` anchor links; leave generic-architecture prose (e.g. `writing-docs.md` `docs/architecture/`) untouched. (FR-3) | `env/ai-dotfiles/docs/{spec-format,spec-templates-guide,spec-workflow-guide,writing-specs}.md`, `env/ai-dotfiles/framework/spec-workflows/spec-lifecycle.md` | — | — | writing-specs | default | ✅ done (2026-06-17) |
| 5 | Mechanical header swap `^## Architecture` → `## Design` across both ai-dotfiles-side archived corpora (31 files); bodies untouched. (FR-4) | `env/ai-dotfiles/docs/specs/archived/*.md`, `docs/specs/archived/*.md` | — | — | writing-specs | fast | ☐ pending |
| 6 | Mechanical header swap `^## Architecture` → `## Design` across `tobevisit-content` specs (17 files); cross-repo, bodies untouched. (FR-4) | `src/github.com/tobeverse/tobevisit-content/docs/specs/**/*.md` | — | — | writing-specs | fast | ☐ pending |
| 7 | Regenerate rendered copies via `make sync-*`, then verify AC-1 (`grep -rn "^## Architecture"` over in-scope surfaces = 0), AC-2 (no dangling `§ Architecture` refs), AC-3 (drift check passes). Flip `status: done`. (FR-5, AC-1/2/3) | — *(runs `make sync-*` + verification greps; no hand edits)* | all files from T1–T6 | 1, 2, 3, 4, 5, 6 | writing-specs | default | ☐ pending |
## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.
## Docs updates required
- Edit canonical framework sources only; never hand-edit rendered profile/`.github/` copies — regenerate via `make sync-*` (FR-5).
- Treat the existing-spec rename (FR-4) as a pure header swap; do not touch section bodies.
## Rollout / migration notes
- Land all FRs in one change so agents never see templates saying `## Design` while prompts/guides still say `## Architecture`.
- Implementation order: canonical templates + prompts + skill + guides → existing spec corpora → `make sync-*` regenerate → run drift check (AC-3).
- Rollback: atomic revert of the whole change (E3).
