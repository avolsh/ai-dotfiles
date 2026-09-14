---
id: IMP-20260513-slim-project-templates
type: IMP
date: 2026-05-13
status: done
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/templates/project/.github/copilot-instructions.md
  - framework/templates/project/AGENTS.md
  - framework/templates/project/CLAUDE.md
  - framework/templates/project/docs/README.md
  - framework/templates/project/docs/architecture/module-map.md
  - framework/templates/project/docs/improvements-log.md
  - framework/templates/project/docs/specs/active/README.md
  - framework/templates/project/docs/specs/archived/README.md
  - docs/project-bootstrap-guide.md
affected-code: []
skills:
  - writing-specs
  - bootstrapping-project
model-suggestion: default
siblings:
  - IMP-20260513-slim-system-templates
  - IMP-20260513-slim-skill-bodies
  - IMP-20260513-slim-framework-prompts
  - IMP-20260513-slim-spec-templates
  - IMP-20260513-slim-spec-workflows
  - IMP-20260513-compress-boundaries
  - IMP-20260513-slim-workspace-templates
---

# IMP-20260513-slim-project-templates

*Last updated: 2026-05-13*

## Summary

- **Goal:** Slim the project-bootstrap template files under `framework/templates/project/` by mirroring the IMP-A approach: retain the load-bearing workflow trigger map, drop catalog/two-scope/non-Copilot prose, point at `docs/` for human-readable content.
- **Scope:** All files under `framework/templates/project/` — primarily `.github/copilot-instructions.md` (90 lines, auto-loaded after a project is bootstrapped) plus the smaller satellite files (AGENTS.md, CLAUDE.md, the docs/* scaffolding).
- **Out of scope:** `framework/templates/workspace/*` (owned by sibling IMP-H), `framework/templates/system/*` (owned by IMP-A), `framework/templates/project/.github/scripts/sync-agents.sh` (shell script, not a markdown template), `framework/templates/project/Makefile`.
- **Per-file targets (exception to global ≥80% rule):** copilot-instructions.md ≥70% (90 → ≤25; same shape as IMP-A's agent-system template); AGENTS.md ≥50% (16 → ≤8, near-passthrough); CLAUDE.md unchanged (already 1-line passthrough); docs/* scaffolding kept terse but unchanged if not duplicating content already in `docs/ai-agent-framework.md`.
- **"Ask first" boundary touch:** Changing project template files falls under `boundaries.md § Ask first #3` ("Changing spec templates, workflow definitions, or boundaries"). User instruction authoring this IMP is the granted permission.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 100k-200k |
| Human attention | 7 gates (1 specify + 1 plan + 4 task + 1 closure); ~10 min/gate |
| Re-Specify tripwire | copilot-instructions.md cannot reach ≤25 lines while retaining the workflow trigger map + Boundaries section, OR any docs/* scaffolding file is found to duplicate content that must move to `docs/` |

## Current State

`framework/templates/project/` is the scaffold copied by `ai-project` (and equivalent bootstrap commands) into a new project root. The largest and load-bearing file is `.github/copilot-instructions.md` (90 lines): once a project is bootstrapped, this file is auto-loaded by every agent session targeting that project (it is `@`-imported from the project's `CLAUDE.md` for Claude, copied to `AGENTS.md` for Codex, and read directly by Copilot). The template carries: Purpose, Tech Stack, Codebase Layout, Context Loading order, Boundaries (project-scope), Skill & prompt resolution, Available skills (catalog table), Workflows (trigger map), "Note for non-Copilot agents", and Build and Run.

Of these sections, the **workflow trigger map** is the only load-bearing routing layer for the project agent — it maps "create CR" / "bug" / "plan" / etc. to system prompt paths. The Boundaries section is the project-scope counterpart to system `boundaries.md` (per the two-scope model). The Skill & prompt resolution prose, the Available skills catalog, and the "Note for non-Copilot agents" section are all duplicates of content that lives canonically in `docs/ai-agent-framework.md` (per IMP-A).

The satellite template files (`AGENTS.md` 16 lines, `CLAUDE.md` 1 line, `docs/README.md` 23 lines, `docs/architecture/module-map.md` 30 lines, `docs/improvements-log.md` 37 lines, `docs/specs/{active,archived}/README.md` ~10 lines each) are smaller. AGENTS.md is a near-passthrough today; CLAUDE.md is already a 1-line passthrough; the docs/ scaffolding files are short structural prompts.

`cites-reqs:` omitted — framework-convention work.

## Proposed Improvement

`.github/copilot-instructions.md` template slims to ≤25 lines mirroring the IMP-A agent-system-template shape: title placeholder, `*Last updated:*`, the project-scope **Boundaries** section (kept inlined — it is the project-scope counterpart to system `boundaries.md` and must auto-load with the project), the **workflow trigger map** (kept inlined — load-bearing routing per IMP-A FR-3), one-line `Tech Stack` / `Codebase Layout` placeholders, one-line `Build and Run` placeholder, and 1-2 pointer lines to `docs/ai-agent-framework.md` (catalog, skill/prompt resolution, non-Copilot agent notes) and `docs/project-bootstrap-guide.md` (new — captures the prose currently inlined for project-bootstrap authoring guidance).

`AGENTS.md` template becomes a near-passthrough: ≤8 lines (title placeholder + Last-updated + brief note that it is a generated copy of copilot-instructions.md).

`CLAUDE.md` template stays as a 1-line `@.github/copilot-instructions.md` passthrough.

`docs/` scaffolding template files are inspected for duplication with `docs/ai-agent-framework.md` or other framework docs. Any duplicate prose moves; the scaffold files retain only structural placeholders.

**Measurable benefit:**
- `copilot-instructions.md` template 90 → ≤25 lines (≥72%)
- `AGENTS.md` template 16 → ≤8 lines (≥50%)
- `CLAUDE.md` template unchanged (1 line)
- `docs/` scaffolding files: each ≤ today's count; total docs/ scaffolding reduction ≥30% if any duplication is found, else 0%
- **Layer total** (excluding sync-agents.sh and Makefile): 222 → ≤140 lines (~37% reduction)

## Requirements

- FR-1: `framework/templates/project/.github/copilot-instructions.md` MUST be ≤25 lines.
- FR-2: The slimmed copilot-instructions.md template MUST retain: (a) the project-scope `## Boundaries` section in its current shape, (b) the `## Workflows` trigger map (header + user-says-→-prompt rows), and (c) placeholders for Tech Stack, Codebase Layout, Build and Run.
- FR-3: The slimmed copilot-instructions.md template MUST NOT inline: the Skill & prompt resolution prose, the Available skills catalog table, or the "Note for non-Copilot agents" section. These move to `docs/` (canonical at `docs/ai-agent-framework.md`).
- FR-4: `framework/templates/project/AGENTS.md` template MUST be ≤8 lines.
- FR-5: `framework/templates/project/CLAUDE.md` template MUST remain a single `@.github/copilot-instructions.md` passthrough line.
- FR-6: Each docs/ scaffolding file under `framework/templates/project/docs/` MUST be checked for duplication with `docs/ai-agent-framework.md` or other framework docs. Any duplicate prose MUST move to the canonical doc; the scaffold file retains only structural placeholders.
- FR-7: `docs/project-bootstrap-guide.md` MUST be created and MUST hold the project-bootstrap authoring guidance currently inlined in the project copilot-instructions.md template (Skill & prompt resolution, Available skills section authoring tips, non-Copilot agent notes from the template's perspective).

## Acceptance Criteria

### AC-1: copilot-instructions.md template line budget met (FR-1)

Given the slimmed template at HEAD
When `wc -l framework/templates/project/.github/copilot-instructions.md` runs
Then the file is ≤25 lines

### AC-2: Required sections retained (FR-2)

Given the slimmed template at HEAD
When the H2 headers are inspected
Then `## Boundaries` and `## Workflows` are present
And the Workflows table includes user-says-→-prompt rows for "create CR / IMP", "bug", "plan", "visualize"
And placeholders for Tech Stack, Codebase Layout, and Build and Run are present (one line each)

### AC-3: No inlined catalog/resolution/non-Copilot content (FR-3)

Given the slimmed template at HEAD
When `grep -E 'Available skills|Skill & prompt resolution|Note for non-Copilot' framework/templates/project/.github/copilot-instructions.md` runs
Then it returns no matches
And the equivalent content is reachable at `docs/ai-agent-framework.md`

### AC-4: Satellite files meet budget (FR-4, FR-5)

Given the slimmed satellite templates at HEAD
When `wc -l framework/templates/project/AGENTS.md framework/templates/project/CLAUDE.md` runs
Then AGENTS.md ≤8 lines and CLAUDE.md == 1 line

### AC-5: docs/ scaffolding free of duplicates (FR-6)

Given the inspected docs/ scaffolding at HEAD
When every paragraph is compared against `docs/ai-agent-framework.md` and other `docs/*.md` files
Then no paragraph is duplicated
And any prose moved to `docs/` is reachable from the scaffolding via a markdown link

### AC-6: docs/project-bootstrap-guide.md exists (FR-7)

Given the new guide at HEAD
When the file is inspected
Then it carries `*Last updated: 2026-05-13*`, a one-line purpose statement, and the migrated authoring guidance for project-bootstrap

## Design

Skipped — refactor of bootstrap templates; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: `framework/templates/workspace/*` — owned by sibling IMP-H.
- OS-2: `framework/templates/system/*` — owned by sibling IMP-A.
- OS-3: `framework/templates/project/.github/scripts/sync-agents.sh` — shell script; out of scope for markdown-template slim.
- OS-4: `framework/templates/project/Makefile` — build-system template; out of scope.
- OS-5: Already-bootstrapped project files in any consumer repo (e.g., the existing `tobevisit-content/.github/copilot-instructions.md`) — retroactive re-application of the new template is a separate concern.

## Split Decision

Kept as one sibling spec — single template family with parallel internal structure. Per `splitting-rules.md § 2`: no trigger applies.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| G1 | Create `docs/project-bootstrap-guide.md` from authoring guidance currently inlined in the project copilot-instructions template (FR-7). | `docs/project-bootstrap-guide.md` (new) | `framework/templates/project/.github/copilot-instructions.md` *(pre-slim source)*; `docs/ai-agent-framework.md` | — | writing-docs, bootstrapping-project | default | ✅ done |
| G2 | Slim project `copilot-instructions.md` template to ≤25 lines — keep Boundaries + Workflows trigger map + placeholders; drop catalog/resolution/non-Copilot prose (FR-1, FR-2, FR-3). | `framework/templates/project/.github/copilot-instructions.md` | `docs/project-bootstrap-guide.md` *(G1)*; `docs/ai-agent-framework.md`; `framework/templates/system/claude/CLAUDE.md` *(slim shape reference)* | G1 | writing-docs, bootstrapping-project | deep | ✅ done |
| G3 | Slim `framework/templates/project/AGENTS.md` to near-passthrough ≤8 lines (FR-4). | `framework/templates/project/AGENTS.md` | `framework/templates/project/.github/copilot-instructions.md` *(G2)* | G2 | writing-docs | default | ✅ done |
| G4 | Audit project docs/ scaffolding for duplicates with framework `docs/`; relocate any duplicate prose (FR-6). | `framework/templates/project/docs/README.md`, `framework/templates/project/docs/architecture/module-map.md`, `framework/templates/project/docs/improvements-log.md`, `framework/templates/project/docs/specs/active/README.md`, `framework/templates/project/docs/specs/archived/README.md` | `docs/` *(all relevant framework docs for comparison)* | — | writing-docs | default | ✅ done (no duplicates found; 0% reduction) |

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/project-bootstrap-guide.md` — created per FR-7.
- `framework/templates/project/.github/copilot-instructions.md` — slimmed per FR-1/FR-2/FR-3.
- `framework/templates/project/AGENTS.md` — slimmed per FR-4.
- `framework/templates/project/docs/*` — duplicates relocated per FR-6.

## Rollout / migration notes

- Existing projects already bootstrapped from the old template are NOT retroactively updated. Their copilot-instructions.md continues to carry the older shape. Closure notes recommend a follow-up IMP per consumer project if the workspace-level cleanup is desired.
- The slimmed template inherits the "Ask first" boundary touch — the `bootstrapping-project/SKILL.md` should reflect the new shape after this IMP closes.
