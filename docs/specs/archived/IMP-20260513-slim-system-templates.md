---
id: IMP-20260513-slim-system-templates
type: IMP
date: 2026-05-13
status: done
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/templates/system/claude/CLAUDE.md
  - framework/templates/system/codex/AGENTS.md
  - framework/templates/system/copilot/copilot-instructions.md
  - framework/templates/system/_skill-template/SKILL.md
  - docs/ai-agent-framework.md
affected-code:
  - framework/scripts/test/
skills:
  - writing-specs
  - bootstrapping-project
model-suggestion: default
siblings:
  - IMP-20260513-slim-skill-bodies
  - IMP-20260513-slim-framework-prompts
  - IMP-20260513-slim-spec-templates
  - IMP-20260513-slim-spec-workflows
  - IMP-20260513-compress-boundaries
  - IMP-20260513-slim-project-templates
  - IMP-20260513-slim-workspace-templates
---

# IMP-20260513-slim-system-templates

*Last updated: 2026-05-13*

## Summary

- **Goal:** Reduce the system-prompt baseline auto-loaded into every agent session by ≥80% per agent-system-template file, while preserving the load-bearing workflow trigger map; also slim `framework/templates/system/_skill-template/SKILL.md` to match the slimmed-skill shape.
- **Scope:** All four files under `framework/templates/system/` — the three agent-system templates (`claude/CLAUDE.md`, `codex/AGENTS.md`, `copilot/copilot-instructions.md`) and the skill-authoring template (`_skill-template/SKILL.md`).
- **Out of scope:** Project-scope `.github/copilot-instructions.md`, workspace-scope `CLAUDE.md`/`AGENTS.md`, `framework/boundaries.md` compression.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 50k-100k |
| Human attention | 8 gates (1 specify + 1 plan + 5 task + 1 closure); ~5 min/gate |
| Re-Specify tripwire | 80% reduction unreachable on any agent-system template without dropping `@boundaries.md`, the workflow trigger map, or breaking the byte-identity sync gate |

## Current State

`framework/templates/system/` holds four files: the three agent-system templates `claude/CLAUDE.md`, `codex/AGENTS.md`, `copilot/copilot-instructions.md` (each 103 lines, ~95% byte-identical — only the *Canonical source:* path differs), and the skill-authoring template `_skill-template/SKILL.md` (52 lines).

The three agent-system templates inline: a two-scope instruction model, the spec-workflow lifecycle, the spec-type table, an "Available skills" catalog, a "Workflows (shared prompts)" trigger table, and a "Note for non-Copilot agents" section. Most of this content is already canonical in `docs/ai-agent-framework.md` (164 lines) — except the **workflow trigger table**, which is load-bearing: it maps user phrases ("create CR", "bug", "plan") to prompt-file paths and is the only routing layer that tells the agent which workflow prompt to load. Removing it would leave the agent unable to enter the spec workflow when the user types a trigger phrase.

Every Claude/Codex/Copilot session loads its agent-system template as system-prompt overhead (~103 lines auto-loaded before user input). Each agent loads only its own file, so the cost is 1× ~103 lines per session — not 3× — but the file content is structural prose that biases the agent to preload related skill bodies from the embedded catalog. The "Available skills" catalog table is in particular redundant: the harness already advertises skills via their YAML `description` frontmatter on first turn.

`_skill-template/SKILL.md` is not auto-loaded into any agent session; it is a starter file copied during skill authoring (by `skill-creator` or by hand). Its current shape carries multiple sections (`## Before Starting`, `## Procedure`, `## Proactive Triggers`, `## Output Artifacts`, `## Anti-Patterns`, `## Communication`, `## Related Skills`) that exceed the slimmed-skill target shape defined by sibling `IMP-20260513-slim-skill-bodies` (frontmatter + `## When to use` + `## References` only). New skills bootstrapped from this template would inherit a bloated shape inconsistent with the slim.

`cites-reqs:` omitted — framework-convention work, no project requirements baselines touched.

## Proposed Improvement

**Agent-system templates** (`claude/CLAUDE.md`, `codex/AGENTS.md`, `copilot/copilot-instructions.md`) reduce to ≤25 lines containing: title, the existing *rendered by / canonical source* pointer, the `*Active profile:*` line, the `@boundaries.md` import, **the workflow trigger map** (≤8 lines: header + the 5 user-says-→-prompt rows), and 1-2 plain pointer lines to `docs/ai-agent-framework.md` (catalog of skills, two-scope model, non-Copilot agent notes) and `docs/spec-workflow-guide.md` (lifecycle and gate rules). Drop inline lifecycle prose, skills-catalog table, two-scope-model exposition, non-Copilot-notes section, and spec-type table. `make sync-agents` byte-identity gate between the three files continues to pass.

**`_skill-template/SKILL.md`** reduces to the slimmed-skill shape defined by sibling `IMP-20260513-slim-skill-bodies` FR-2: YAML frontmatter + `## When to use` + `## References`. Sections currently present (`## Before Starting`, `## Procedure`, `## Proactive Triggers`, `## Output Artifacts`, `## Anti-Patterns`, `## Communication`, `## Related Skills`) drop; their content moves to `docs/writing-skills.md` (created in this IMP) where it lives as authoring guidance.

**Measurable benefit:**
- Agent-system templates: per-file line count drops 103 → ≤20 lines (≥80% reduction). Verified by `wc -l framework/templates/system/{claude,codex,copilot}/*` at HEAD before/after closure.
- `_skill-template/SKILL.md`: 52 → ≤25 lines (≥51% reduction). The 80% target does not apply — the starter is already free of the catalog/lifecycle prose that bloats agent-system templates; its measurable benefit is **shape conformance with sibling IMP-B**, not raw line reduction. New skills authored from the slimmed starter inherit the correct shape.

## Requirements

- FR-1: Each agent-system template (`claude/CLAUDE.md`, `codex/AGENTS.md`, `copilot/copilot-instructions.md`) MUST be ≤25 lines.
- FR-2: Each agent-system template MUST contain only: title, the *rendered by / canonical source* line, the `*Active profile:*` line, the `@boundaries.md` import, the **workflow trigger map** (header + ≤6 user-says-→-prompt rows), and ≤2 plain pointer lines to `docs/ai-agent-framework.md` and `docs/spec-workflow-guide.md`.
- FR-3: The workflow trigger map MUST be retained in every agent-system template. It MUST map user-phrase triggers (e.g., "create CR", "create IMP", "bug / triage", "plan / break into tasks", "visualize / architecture") to absolute prompt-file paths under `<system>/prompts/`. Removing or relocating the trigger map outside the system prompt is a `Re-Specify` event.
- FR-4: Each agent-system template MUST NOT inline the two-scope model table, the "Available skills" catalog table, the spec-type table, the spec-lifecycle prose, or the "Note for non-Copilot agents" section.
- FR-5: The byte-identity sync gate (`framework/.github/scripts/sync-agents.sh` or equivalent, plus CI gates under `framework/scripts/test/`) MUST continue to enforce parity between the three agent-system templates modulo the *Canonical source:* path line.
- FR-6: `docs/ai-agent-framework.md` MUST be the authoritative location for every piece of prose removed from agent-system templates; any content not already present there MUST be added before the slim lands.
- FR-7: `framework/templates/system/_skill-template/SKILL.md` MUST be ≤25 lines and MUST consist of: YAML frontmatter (preserving the existing `name` and `description` placeholders), `## When to use` (placeholder bullets), and `## References` (placeholder link list). All other sections currently present MUST be removed.
- FR-8: The authoring guidance currently inlined in `_skill-template/SKILL.md` (Before Starting, Procedure, Proactive Triggers, Output Artifacts, Anti-Patterns, Communication, Related Skills) MUST move to `docs/writing-skills.md`.

## Acceptance Criteria

### AC-1: Agent-system templates meet line budget (FR-1, FR-2)

Given the three slimmed agent-system templates at HEAD
When `wc -l framework/templates/system/{claude,codex,copilot}/*` runs
Then each file is ≤25 lines
And the measurable benefit is verified: each file is ≤20 lines (≥80% reduction from 103)

### AC-2: Workflow trigger map preserved (FR-3)

Given the three slimmed agent-system templates at HEAD
When each file is inspected
Then each MUST contain a `User says | Load prompt` table (or equivalent compact mapping) with absolute paths under `<system>/prompts/`
And `grep -l 'create CR\|create IMP\|bug\|plan\|visualize' framework/templates/system/{claude,codex,copilot}/*` MUST return all three files

### AC-3: No duplicated catalog/two-scope/non-Copilot content (FR-4)

Given the three slimmed agent-system templates at HEAD
When `grep -E 'Two-scope|Available skills|Note for non-Copilot' framework/templates/system/{claude,codex,copilot}/*` runs
Then it returns no matches
And every removed section appears in `docs/ai-agent-framework.md`

### AC-4: Sync gate passes (FR-5)

Given the three slimmed agent-system templates committed
When the byte-identity sync gate runs (locally and in CI)
Then it MUST report parity between the three files

### AC-5: docs/ai-agent-framework.md is authoritative (FR-6)

Given a reader follows the pointer from any slimmed agent-system template
When they open `docs/ai-agent-framework.md`
Then they MUST find: the two-scope model, the full skills catalog, the spec-type table, and the non-Copilot agent notes

### AC-6: _skill-template/SKILL.md matches slimmed shape (FR-7, FR-8)

Given the slimmed `_skill-template/SKILL.md` at HEAD
When `wc -l framework/templates/system/_skill-template/SKILL.md` runs
Then the file is ≤25 lines
And the body contains exactly three header sections (frontmatter + `## When to use` + `## References`)
And every removed section's content appears in `docs/writing-skills.md`

## Design

Skipped — convention/refactor at the system-prompt layer; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: `framework/boundaries.md` compression (90 lines) — separate IMP candidate.
- OS-2: Project-scope `.github/copilot-instructions.md` files in any project repo — out of `ai-dotfiles` scope.
- OS-3: Workspace-scope `tobevisit/CLAUDE.md` and `tobevisit/.github/copilot-instructions.md` — out of `ai-dotfiles` scope.
- OS-4: Any change to `@`-import resolution semantics across Claude/Codex/Copilot.

## Split Decision

Split into: `IMP-20260513-slim-skill-bodies`, `IMP-20260513-slim-framework-prompts`, `IMP-20260513-slim-spec-templates`. This spec owns FR-1 through FR-5 covering the system-template layer only. Per `splitting-rules.md § 2`: each layer is independently testable (per-layer line-count AC), independently revertable, and the alternative single-IMP plan would exceed 8 tasks. No `splitting-rules.md § 4` exception applies.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| A1 | Verify/backfill `docs/ai-agent-framework.md` so it is authoritative for the two-scope model, skills catalog, spec-type table, and non-Copilot agent notes (FR-6). | `docs/ai-agent-framework.md` | `framework/templates/system/claude/CLAUDE.md` *(pre-slim source)*; `framework/spec-workflows/spec-types.md` | — | writing-docs | default | ✅ done |
| A2 | Create `docs/writing-skills.md` from authoring guidance currently inlined in `_skill-template/SKILL.md` (FR-8). | `docs/writing-skills.md` (new) | `framework/templates/system/_skill-template/SKILL.md` | — | writing-docs | default | ✅ done |
| A3 | Slim `_skill-template/SKILL.md` to canonical slimmed-skill shape — frontmatter + `## When to use` + `## References` (FR-7). | `framework/templates/system/_skill-template/SKILL.md` | `docs/writing-skills.md` *(A2 output)* | A2 | writing-docs | default | ✅ done |
| A4 | Slim `framework/templates/system/claude/CLAUDE.md` to ≤20 lines — title, `*Active profile:*`, `@boundaries.md`, workflow trigger map (header + 5 rows), 1-2 pointer lines (FR-1, FR-2, FR-3, FR-4). | `framework/templates/system/claude/CLAUDE.md` | `docs/ai-agent-framework.md` *(A1 output)*; `framework/templates/system/claude/CLAUDE.md` *(pre-slim)*; `framework/boundaries.md` | A1 | bootstrapping-project, writing-docs | deep | ✅ done |
| A5 | Mirror A4 into `AGENTS.md` and `copilot-instructions.md`; verify byte-identity sync gate passes (FR-5). | `framework/templates/system/codex/AGENTS.md`, `framework/templates/system/copilot/copilot-instructions.md` | `framework/templates/system/claude/CLAUDE.md` *(A4 output)*; `framework/scripts/test/` *(all 5 gate scripts; sync verification)* | A4 | bootstrapping-project | default | ✅ done |

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/ai-agent-framework.md` — confirm it carries the full two-scope model, skills catalog, spec-type table, and non-Copilot agent notes; backfill any gap as the Plan's first task. Workflow trigger map stays inlined in agent-system templates per FR-3 and is NOT migrated to this doc.
- `docs/writing-skills.md` — new file capturing the authoring guidance currently inlined in `_skill-template/SKILL.md` (Before Starting, Procedure, Proactive Triggers, Output Artifacts, Anti-Patterns, Communication, Related Skills).

## Rollout / migration notes

- The three slimmed agent-system templates remain byte-identical (modulo the *Canonical source:* line) so `ai-profile-init.sh` symlink behavior is unchanged.
- The workflow trigger map remains inlined in agent-system templates — it is the load-bearing routing layer that converts user phrases into prompt-file loads. Moving it to `docs/` would break the workflow entry path.
- The slimmed `_skill-template/SKILL.md` defines the inheritance shape for any new skill bootstrapped after this IMP closes. Existing skills are slimmed under sibling `IMP-20260513-slim-skill-bodies`; no retroactive re-application of the new starter is required.
- No downstream-project coordination needed — system-scope only.
