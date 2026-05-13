---
id: IMP-20260513-slim-workspace-templates
type: IMP
date: 2026-05-13
status: plan
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/templates/workspace/.github/copilot-instructions.md
  - framework/templates/workspace/AGENTS.md
  - framework/templates/workspace/CLAUDE.md
  - framework/templates/workspace/docs/improvements-log.md
  - docs/workspace-bootstrap-guide.md
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
  - IMP-20260513-slim-project-templates
---

# IMP-20260513-slim-workspace-templates

*Last updated: 2026-05-13*

## Summary

- **Goal:** Slim the workspace-bootstrap template files under `framework/templates/workspace/` mirroring the IMP-G approach for project templates — retain the load-bearing workspace concerns (project routing, cross-repo coordination, shared safety), drop the framework-overview prose, point at `docs/` for human-readable content.
- **Scope:** All files under `framework/templates/workspace/` — primarily `.github/copilot-instructions.md` (50 lines, auto-loaded once a workspace is bootstrapped) plus AGENTS.md (17), CLAUDE.md (1), and `docs/improvements-log.md` (38).
- **Out of scope:** `framework/templates/project/*` (owned by sibling IMP-G), `framework/templates/system/*` (owned by IMP-A), `framework/templates/workspace/.github/scripts/sync-agents.sh`, `framework/templates/workspace/Makefile`.
- **Per-file targets (exception to global ≥80% rule):** copilot-instructions.md ≥60% (50 → ≤20); AGENTS.md ≥50% (17 → ≤8, near-passthrough); CLAUDE.md unchanged (1-line passthrough); docs/improvements-log.md ≥45% if its content duplicates the project-template equivalent.
- **"Ask first" boundary touch:** Changing workspace template files falls under `boundaries.md § Ask first #3`. User instruction authoring this IMP is the granted permission.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 50k-100k |
| Human attention | 7 gates (1 specify + 1 plan + 4 task + 1 closure); ~10 min/gate |
| Re-Specify tripwire | copilot-instructions.md cannot reach ≤20 lines while retaining the Projects table, Project routing table, Shared safety section, and Cross-repository coordination section |

## Current State

`framework/templates/workspace/` is the scaffold copied by `ai-workspace` into a new multi-project workspace root. The largest file is `.github/copilot-instructions.md` (50 lines): once a workspace is bootstrapped, this file is auto-loaded by every agent session targeting the workspace root (it is `@`-imported from the workspace's `CLAUDE.md`, copied to `AGENTS.md` for Codex, and read directly by Copilot).

The template carries: a `## Projects` table (project name → path → purpose), a `## Project routing` section telling the agent how to descend into a specific project, a `## Shared safety` section listing workspace-wide external systems and the env-secret rule, a `## Cross-repository coordination` section establishing the schema-change discipline, and a `## AI agent framework` section that describes where `docs/` lives at the workspace layer.

Of these sections, the **Projects table** and **Project routing** are load-bearing workspace concerns — they tell the agent which project to descend into when a task targets a specific project. **Shared safety** and **Cross-repository coordination** carry workspace-scope boundary-equivalent rules and must remain inlined (parallel to how project-scope `## Boundaries` stays in the project template per sibling IMP-G FR-2). The **AI agent framework** section is prose about `docs/` and `<system>/` — duplicate of content reachable via `docs/ai-agent-framework.md`, and moves out.

The satellite template files (AGENTS.md 17 lines, CLAUDE.md 1 line, docs/improvements-log.md 38 lines) are short. AGENTS.md is currently a near-passthrough already; CLAUDE.md is a 1-line passthrough; improvements-log.md is a format-prompt template that may duplicate the equivalent project-scope file.

`cites-reqs:` omitted — framework-convention work.

## Proposed Improvement

`.github/copilot-instructions.md` template slims to ≤20 lines: title placeholder, `*Last updated:*`, **Projects table** (workspace-routing — kept inlined), **Project routing** brief (one-line per project routing pattern — kept inlined), **Shared safety** (workspace-scope boundary-equivalent — kept inlined), **Cross-repository coordination** (kept inlined), and 1-2 pointer lines to `docs/ai-agent-framework.md` (where `docs/` and `<system>/` are explained) and `docs/workspace-bootstrap-guide.md` (new — captures the authoring guidance currently inlined).

`AGENTS.md` template becomes a near-passthrough: ≤8 lines.

`CLAUDE.md` template stays as a 1-line `@.github/copilot-instructions.md` passthrough.

`docs/improvements-log.md` template is checked against the project-scope equivalent (`framework/templates/project/docs/improvements-log.md`, 37 lines). If the two templates carry duplicated structural prose, the workspace template is reduced to a one-line `*Last updated:*` + table-header skeleton; common authoring guidance moves to `docs/improvements-log-format.md` (or to the bootstrap guides).

**Measurable benefit:**
- `copilot-instructions.md` template 50 → ≤20 lines (≥60%)
- `AGENTS.md` template 17 → ≤8 lines (≥53%)
- `CLAUDE.md` template unchanged (1 line)
- `docs/improvements-log.md` template 38 → ≤20 lines (≥47%) if duplication found, else unchanged
- **Layer total** (excluding sync-agents.sh and Makefile): 106 → ≤49 lines (~54% reduction)

## Requirements

- FR-1: `framework/templates/workspace/.github/copilot-instructions.md` MUST be ≤20 lines.
- FR-2: The slimmed workspace template MUST retain: (a) `## Projects` table, (b) `## Project routing` brief, (c) `## Shared safety` section, (d) `## Cross-repository coordination` section.
- FR-3: The slimmed workspace template MUST NOT inline the `## AI agent framework` prose; this content is reachable at `docs/ai-agent-framework.md`.
- FR-4: `framework/templates/workspace/AGENTS.md` template MUST be ≤8 lines.
- FR-5: `framework/templates/workspace/CLAUDE.md` template MUST remain a single `@.github/copilot-instructions.md` passthrough.
- FR-6: `framework/templates/workspace/docs/improvements-log.md` template MUST be checked against the project-scope equivalent; any duplicated structural prose moves to a shared `docs/` page and both template files reference it.
- FR-7: `docs/workspace-bootstrap-guide.md` MUST be created and MUST hold the workspace-bootstrap authoring guidance currently inlined in the workspace copilot-instructions.md template.

## Acceptance Criteria

### AC-1: copilot-instructions.md template line budget met (FR-1)

Given the slimmed template at HEAD
When `wc -l framework/templates/workspace/.github/copilot-instructions.md` runs
Then the file is ≤20 lines

### AC-2: Required sections retained (FR-2)

Given the slimmed template at HEAD
When the H2 headers are inspected
Then `## Projects`, `## Project routing`, `## Shared safety`, and `## Cross-repository coordination` are all present, in that order

### AC-3: AI-agent-framework prose removed (FR-3)

Given the slimmed template at HEAD
When `grep -E 'AI agent framework|docs/ is the workspace-wide folder|The framework itself' framework/templates/workspace/.github/copilot-instructions.md` runs
Then it returns no matches
And the equivalent content is reachable at `docs/ai-agent-framework.md`

### AC-4: Satellite files meet budget (FR-4, FR-5)

Given the slimmed satellite templates at HEAD
When `wc -l framework/templates/workspace/AGENTS.md framework/templates/workspace/CLAUDE.md` runs
Then AGENTS.md ≤8 lines and CLAUDE.md == 1 line

### AC-5: improvements-log.md dedup completed (FR-6)

Given the inspected and slimmed improvements-log.md template at HEAD
When it is compared against `framework/templates/project/docs/improvements-log.md`
Then no paragraph is duplicated
And if any duplicated authoring prose was found, it now lives in `docs/improvements-log-format.md` (or in the bootstrap guides) and both templates link to it

### AC-6: docs/workspace-bootstrap-guide.md exists (FR-7)

Given the new guide at HEAD
When the file is inspected
Then it carries `*Last updated: 2026-05-13*`, a one-line purpose statement, and the migrated authoring guidance for workspace-bootstrap

## Architecture

Skipped — refactor of bootstrap templates; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: `framework/templates/project/*` — owned by sibling IMP-G.
- OS-2: `framework/templates/system/*` — owned by sibling IMP-A.
- OS-3: `framework/templates/workspace/.github/scripts/sync-agents.sh` — shell script; out of scope.
- OS-4: `framework/templates/workspace/Makefile` — build-system template; out of scope.
- OS-5: Already-bootstrapped workspace files in any consumer (e.g., `tobevisit/.github/copilot-instructions.md`) — retroactive re-application is a separate concern.

## Split Decision

Kept as one sibling spec — single template family. Per `splitting-rules.md § 2`: no trigger applies.

## Tasks

> **Before starting Task 1, set `status: in-progress` in the front-matter above.**

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| H1 | Create `docs/workspace-bootstrap-guide.md` from authoring guidance currently inlined in the workspace copilot-instructions template (FR-7). | `docs/workspace-bootstrap-guide.md` (new) | `framework/templates/workspace/.github/copilot-instructions.md` *(pre-slim source)*; `docs/ai-agent-framework.md` | — | writing-docs, bootstrapping-project | default | ⬜ todo |
| H2 | Slim workspace `copilot-instructions.md` template to ≤20 lines — keep Projects + Project routing + Shared safety + Cross-repo coordination; drop AI-agent-framework prose (FR-1, FR-2, FR-3). | `framework/templates/workspace/.github/copilot-instructions.md` | `docs/workspace-bootstrap-guide.md` *(H1)*; `docs/ai-agent-framework.md`; `framework/templates/system/claude/CLAUDE.md` *(slim shape reference)* | H1 | writing-docs, bootstrapping-project | deep | ⬜ todo |
| H3 | Slim `framework/templates/workspace/AGENTS.md` to near-passthrough ≤8 lines (FR-4). | `framework/templates/workspace/AGENTS.md` | `framework/templates/workspace/.github/copilot-instructions.md` *(H2)* | H2 | writing-docs | default | ⬜ todo |
| H4 | Dedup-check workspace `docs/improvements-log.md` against project equivalent; if duplicated, create `docs/improvements-log-format.md` and slim both (FR-6). | `framework/templates/workspace/docs/improvements-log.md`, `framework/templates/project/docs/improvements-log.md`, `docs/improvements-log-format.md` (new if needed) | — | G4 *(cross-sibling sync if project file also touched)* | writing-docs | default | ⬜ todo |

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/workspace-bootstrap-guide.md` — created per FR-7.
- `framework/templates/workspace/.github/copilot-instructions.md` — slimmed per FR-1/FR-2/FR-3.
- `framework/templates/workspace/AGENTS.md` — slimmed per FR-4.
- `framework/templates/workspace/docs/improvements-log.md` — dedup-checked per FR-6.

## Rollout / migration notes

- The existing `tobevisit/.github/copilot-instructions.md` (this workspace's own bootstrap output) is NOT retroactively updated. A follow-up at the workspace level can adopt the new template shape if desired.
- Coordinate with sibling IMP-G (project templates) on the shape of any shared `docs/improvements-log-format.md` if FR-6 finds duplication.
