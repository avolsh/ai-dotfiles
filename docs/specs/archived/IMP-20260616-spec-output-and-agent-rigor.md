---
id: IMP-20260616-spec-output-and-agent-rigor
type: IMP
date: 2026-06-16
status: done
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - docs/writing-specs.md
  - docs/spec-format.md
  - docs/spec-templates-guide.md
  - framework/boundaries.md
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
# IMP-20260616-spec-output-and-agent-rigor
*Last updated: 2026-06-16*

> Stability-window waiver (boundaries.md § Ask first #6) granted by owner `avolsh` at the requirements gate, 2026-06-16. No `## Cost Estimate` — this IMP applies FR-4 to itself.

## Summary
- **Goal:** Make Specify produce specs 30–50% shorter, make the Visualize step reuse a Figma design system instead of duplicating UI primitives, and make the agent challenge the author instead of complying by default.
- **Scope:** Extend `writing-specs` (skill + `writing-specs.md`, `spec-format.md`, `spec-templates-guide.md`), the `spec-workflows` templates + `spec-lifecycle.md`, the `plan-spec`/`visualize-spec` prompts, and `boundaries.md`. Guidance/convention only.
- **Out of scope:** New skills, a validator hook, the front-matter schema, rewriting archived specs, behavioural code.

## Current State
Specs are too long to re-read during Specify. Across the **54 canonical archived specs** (roots: `docs/specs/archived/`, `env/ai-dotfiles/docs/specs/archived/`, `src/.../tobevisit-content/docs/specs/archived/`; excluding `README.md`, `_legacy/`, `archived/artifacts/`), measured in **physical lines after front-matter**: body avg **283**, median **192.5**, max **1162**; **48/54** exceed 120 lines, **19/54** exceed 270. Mass concentrates in **Requirements (avg 62.1, max 428)** and **Acceptance/Fix Criteria (avg 58.9, max 298)**. `## Cost Estimate` appears in **34/54**, ~7 fixed lines each.

The framework states qualitative "Writing style", "Compression pass", and "Deduplication" rules in [`docs/writing-specs.md`](../../../docs/writing-specs.md), but: no measurable budget exists (grep confirms); the Compression pass is advisory — no authoring step runs it, no self-review item measures it; templates mandate ~13 H2 sections, several overlapping, plus a Cost Estimate the human rarely uses.

The Visualize sub-step routes UI surfaces to Figma ([`visualize-spec.prompt.md`](../../../framework/prompts/visualize-spec.prompt.md) step 2) but says only "link the frames" — no rule requires reusing design-system variables/components/text styles or forbids duplication, despite the Figma MCP skills (`figma-generate-library`, working-with-design-systems) and tools (`get_libraries`, `search_design_system`).

`boundaries.md` § Escalation covers stopping when *blocked*, but nothing instructs the agent to proactively doubt or challenge an author's instruction that looks wrong or suboptimal — so agents tend to comply by default.

## Proposed Improvement
1. Add a **deterministic length budget** to the writing-style rules (per-section soft caps + a ≤120 physical-line body cap, with a one-line justification escape hatch).
2. Promote the **Compression pass** to a **gated authoring step** that reports a before/after line count; add the matching self-review item.
3. Tighten **FR/AC formatting** (one-line FRs, one Given/When/Then per FR/Fix-Criteria cluster, no prose restating tables); mirror as inline template hints.
4. **Remove `## Cost Estimate` completely** from CR/IMP/BUG templates and every file that mandates/fills/refreshes/summarizes it; do not relocate its fields anywhere.
5. Add a **design-system-first hard rule** to Visualize (discover, reuse, never duplicate; build a library when primitives are missing).
6. Add an **author-challenge rule** to `boundaries.md` (don't treat the author as always right).
7. Produce a **corpus analysis** over all 54 specs as closure evidence (AC-6).

**Measurable benefit:** re-drafting 3 representative archived specs under the new rules yields a body ≥30% shorter (target 30–50%) with no FR or observable verification outcome lost.

## Requirements
> FR-1/-4/-6/-8 exceed the one-line soft cap by design — each defines a multi-file contract (justified per FR-1's escape hatch).

- FR-1: [`docs/writing-specs.md`](../../../docs/writing-specs.md) MUST define a deterministic budget: standard-track spec **body ≤120 physical lines**, measured from the first line after the front-matter close (`---`) to EOF, **counting** blank lines, the H1, and the `*Last updated:*` line, and **excluding** (a) lines inside fenced diagram blocks (```` ```mermaid ````/Figma embeds) under `## Architecture` and (b) the entire `## Closure` section. Per-section soft caps: Summary ≤6; Current State / Problem Statement ≤12; Proposed Improvement ≤12; one line per FR; one Given/When/Then block (≤6 lines) per FR/Fix-Criteria cluster; one line per Out-of-Scope item. Exceeding any cap MUST carry a one-line justification at the top of that section.
- FR-2: [`references/authoring-steps.md § A`](../../../framework/skills/writing-specs/references/authoring-steps.md) MUST include a gated Compression-pass step run before the requirements gate that records before/after line counts; the self-review additions in [`docs/writing-specs.md`](../../../docs/writing-specs.md) MUST include a matching checklist item.
- FR-3: [`docs/spec-format.md`](../../../docs/spec-format.md) MUST require one-line FRs, one Given/When/Then block per FR/Fix-Criteria cluster, and MUST forbid prose restating a table or schema. The CR/IMP/BUG templates MUST carry these caps as inline section hints.
- FR-4: The CR, IMP, and BUG templates MUST NOT contain a `## Cost Estimate` section; every framework file that mandates, fills, refreshes, or summarizes it MUST be cleaned; no file MAY introduce a replacement standard-track artifact, and the Token-range / Human-attention / Re-Specify-tripwire fields MUST NOT be relocated into any other mandatory block.
- FR-5: The reduction MUST be self-demonstrating: this IMP and any spec authored after the change MUST conform to FR-1.
- FR-6: [`visualize-spec.prompt.md`](../../../framework/prompts/visualize-spec.prompt.md) MUST state a hard rule that, before creating any Figma frame, the agent discovers the existing design system (**primary: `get_libraries` + `search_design_system`**; `get_variable_defs` only once a concrete reference node exists), reuses its variables/components/text styles, and MUST NOT hardcode or duplicate them; absent a required shared primitive it MUST be built as a library (`figma-generate-library` / working-with-design-systems). The Architecture caption MUST record the design-system source (library file key).
- FR-7: [`spec-lifecycle.md § Visualize sub-step`](../../../framework/spec-workflows/spec-lifecycle.md#visualize-triggers) MUST link to the FR-6 rule, not restate it.
- FR-8: [`framework/boundaries.md`](../../../framework/boundaries.md) MUST state a rule that the agent does not treat the author as always correct: when an instruction, assumption, or proposed approach appears suboptimal, factually wrong, or has a materially better alternative, the agent MUST surface the doubt, verify checkable claims against the codebase, and propose alternative(s) before complying.

## Acceptance Criteria
### AC-1: Budget is deterministic (FR-1, FR-3)
Given the slim complete at HEAD
When `writing-specs.md` and `spec-format.md` are read
Then they state the ≤120 physical-line body rule with its exact count/exclude clauses, the per-section soft caps, the escape hatch, and the one-G/W/T-per-cluster + no-prose-restating-tables rules.

### AC-2: Compression pass is gated (FR-2)
Given the slim complete at HEAD
When `authoring-steps.md § A` and the `writing-specs.md` self-review list are read
Then a numbered Compression-pass step runs before the requirements gate recording before/after counts, with a matching self-review item.

### AC-3: Cost Estimate removed (FR-4)
Given the slim complete at HEAD
When `grep -rl "Cost Estimate" framework/ docs/` runs (excluding `docs/specs/`)
Then no standard-track template, authoring step, prompt, or guide instructs the author to produce or replace a `## Cost Estimate` artifact.

### AC-4: Reduction is real (FR-5)
Given 3 representative archived specs re-drafted under the new rules
When each re-draft's body is compared to its original
Then each is ≥30% shorter with no FR or observable verification outcome dropped, and this IMP's own body conforms to FR-1 (≤120 physical lines or carries the justification).

### AC-5: Design-system-first rule present (FR-6, FR-7)
Given the slim complete at HEAD
When `visualize-spec.prompt.md` is read
Then it states the discover→reuse→no-duplication rule, names `get_libraries`/`search_design_system` as primary discovery and `figma-generate-library` for missing primitives, requires the library-source caption, and `spec-lifecycle.md` links to it without restating.

### AC-6: Corpus evidence (FR-5)
Given closure
When the implementation evidence is produced
Then it covers all 54 canonical archived specs in the three roots and reports, per corpus, body lines, Requirements lines, Acceptance/Fix-Criteria lines, Cost-Estimate presence, H2-section count, and over-budget counts (>120, >270).

### AC-7: Author-challenge rule present (FR-8)
Given the slim complete at HEAD
When `boundaries.md` is read
Then it states the don't-treat-author-as-always-right rule (surface doubt, verify claims, propose alternatives before complying).

## Design
Skipped — convention/guidance change at the spec-authoring and agent-behaviour layer; no bounded context, schema, or UI surface, and `risk: low` fires no Visualize trigger. (FR-6 governs Figma usage in *other* specs, not this one.)

## Out of Scope
- OS-1: A mechanical spec-validator check for the budget — enforcement is gated self-review, not tooling.
- OS-2: Front-matter schema, and `Cost Estimate` content in already-archived specs.
- OS-3: Merging Summary / Current State / Proposed Improvement — kept per the human decision; only caps tighten.
- OS-4: RES and Trivial lane section sets — untouched beyond inheriting FR-1 caps.
- OS-5: Archived specs are **analysis input only** — not rewritten; only forward-looking guidance changes.

## Split Decision
Keep-as-one. T1 fires (three independently-testable FR clusters: slimming FR-1…FR-5, Figma FR-6…FR-7, author-stance FR-8), but exception **E5 (documentation corpus)** dominates: zero behavioural code, all artifacts are markdown under the framework sharing one closure metric and one conformance pass; the three clusters were bundled by explicit owner decision. Scope-breadth acknowledged.

## Tasks
> **Before starting T1, set `status: in-progress` in the front-matter above.**
>
> P3 note: T4 (Figma) and T5 (author-stance) have no dependency on the slimming chain — the P3 safety-net signal is **acknowledged and overridden** by the owner's E5 keep-as-one decision (§ Split Decision), not flipped back to Specify.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | Define the deterministic length budget + per-section caps + escape hatch (FR-1), the gated Compression-pass step + self-review item (FR-2), and one-line-FR / one-G-W-T-per-cluster / no-prose-restating-tables rules (FR-3); remove Cost-Estimate authoring there. | `docs/writing-specs.md`, `docs/spec-format.md`, `framework/skills/writing-specs/references/authoring-steps.md`, `framework/skills/writing-specs/SKILL.md` | corpus stats (§ Current State); `docs/spec-templates-guide.md` | — | writing-specs, writing-docs | deep | ✅ done |
| T2 | Add the FR-1/FR-3 caps as inline section hints and remove the `## Cost Estimate` section from the CR/IMP/BUG templates (FR-3, FR-4). | `framework/spec-workflows/templates/CR-TEMPLATE.md`, `framework/spec-workflows/templates/IMP-TEMPLATE.md`, `framework/spec-workflows/templates/BUG-TEMPLATE.md` | `docs/writing-specs.md` *(T1)* | T1 | writing-specs, writing-docs | default | ✅ done |
| T3 | Remove every remaining Cost-Estimate mandate/fill/refresh/summarize outside templates and lifecycle (FR-4). | `framework/prompts/plan-spec.prompt.md`, `docs/spec-templates-guide.md` | `docs/spec-format.md` *(T1)* | T1 | writing-docs | fast | ✅ done |
| T4 | Add the Figma design-system-first hard rule (discover→reuse→no-duplication, build library when missing, caption library key) to the Visualize prompt; link it (not restate) from the lifecycle Visualize sub-step; remove Cost-Estimate from the lifecycle (FR-6, FR-7, FR-4). | `framework/prompts/visualize-spec.prompt.md`, `framework/spec-workflows/spec-lifecycle.md` | Figma MCP skills (`figma-generate-library`, working-with-design-systems) | — | writing-specs, writing-docs | default | ✅ done |
| T5 | Add the author-challenge behavioural rule (don't treat the author as always right; surface doubt, verify claims, propose alternatives before complying) to boundaries.md (FR-8). | `framework/boundaries.md` | — | — | writing-docs | default | ✅ done |
| T6 | Produce the corpus analysis over all 54 canonical archived specs and the 3-spec ≥30% redraft demonstration as closure evidence (FR-5, AC-4, AC-6). | `docs/specs/archived/artifacts/IMP-20260616-corpus-analysis.md` *(new)* | all three archived roots; `docs/writing-specs.md` *(T1)* | T1, T2, T3, T4 | writing-specs, writing-docs | deep | ✅ done |

## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.

## Docs updates required
- `docs/writing-specs.md` — budget + gated compression + self-review item.
- `docs/spec-format.md`, `docs/spec-templates-guide.md` — FR/AC caps; remove Cost Estimate references.
- `framework/skills/writing-specs/{SKILL.md,references/authoring-steps.md}` — gated step; drop Cost Estimate authoring/refresh.
- `framework/spec-workflows/templates/{CR,IMP,BUG}-TEMPLATE.md` — inline caps; remove Cost Estimate.
- `framework/spec-workflows/spec-lifecycle.md`, `framework/prompts/plan-spec.prompt.md` — drop Cost Estimate refresh; lifecycle links to the Visualize design-system rule.
- `framework/prompts/visualize-spec.prompt.md` — design-system-first hard rule.
- `framework/boundaries.md` — author-challenge rule.

## Rollout / migration notes
- **Stability-window waiver granted** by owner `avolsh` at the requirements gate (2026-06-16), per boundaries.md § Ask first #6 (freeze until 2026-07-12).
- Documentation/convention only; no code, no data reshaping. Archived specs keep their Cost Estimate sections — the change is forward-looking.
- Run `make sync-agents` / `make sync-system-templates` if any rendered agent file inherits the touched guidance.

## Closure (2026-06-16)

Synchronous closure (risk: medium), owner-approved.

| AC | Status | Evidence |
|---|---|---|
| AC-1 budget + formatting | ✅ | `writing-specs.md` § Length budget (≤120 physical-line rule, caps, escape hatch) + Format/cluster rules; `spec-format.md` FR rule 5/6, AC rule 5 |
| AC-2 gated compression | ✅ | `authoring-steps.md` § A step 12 (runs before requirements gate, records before/after); `writing-specs.md` self-review checklist item |
| AC-3 Cost Estimate removed | ✅ | `grep -rl "Cost Estimate" framework/ docs/` (excl. `docs/specs/`) → clean; removed from 3 templates, authoring-steps, plan-spec.prompt, spec-lifecycle, spec-format, spec-templates-guide |
| AC-4 ≥30% reduction | ✅ | artifact: 3 redrafts at 41% / 54% / 57%, no FR or observable outcome dropped |
| AC-5 design-system-first | ✅ | `visualize-spec.prompt.md` § Hard rules (discover→reuse→build-library, caption library key); `spec-lifecycle.md` links, does not restate |
| AC-6 corpus evidence | ✅ | `artifacts/IMP-20260616-corpus-analysis.md` — all 54 specs, per-corpus body/Requirements/Acceptance/Cost-Estimate/H2/over-budget metrics |
| AC-7 author-challenge | ✅ | `boundaries.md` § Always do #15 "Challenge before complying" |

**Verification:** `make validate-specs` / `lint-rules` / `validate-anchors` all green. FR-8 rule lives in `boundaries.md` (`@`-imported at runtime), so no system-template re-render needed.

**Divergences / flags:**
- **`make links-check` was already red before this spec** — 10 broken links in untouched upstream skills (`modern-javascript-patterns`, `nodejs-backend-patterns` → sibling `advanced-patterns.md` via a wrong `references/` prefix). Pre-existing, out of scope; flagged for a separate Direct-lane fix.
- **Pre-existing `_canonical.md` drift** in the 3 rendered system templates (a research-spec routing row + two pointer lines) surfaced when running `sync-system-templates`; reverted to keep this closure unbundled. Flagged for a separate sync/commit.
