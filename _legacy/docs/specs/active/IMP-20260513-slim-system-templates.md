---
id: IMP-20260513-slim-system-templates
type: IMP
date: 2026-05-13
status: specify
owner: avolsh
risk: low
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/templates/system/claude/CLAUDE.md
  - framework/templates/system/codex/AGENTS.md
  - framework/templates/system/copilot/copilot-instructions.md
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
---

# IMP-20260513-slim-system-templates

*Last updated: 2026-05-13*

## Summary

- **Goal:** Reduce the system-prompt baseline auto-loaded into every agent session by ≥80% per system-template file.
- **Scope:** `framework/templates/system/{claude,codex,copilot}/*.md` — slim to title, active-profile line, `@boundaries.md` import, and ≤3 pointer lines to `docs/`.
- **Out of scope:** Project-scope `.github/copilot-instructions.md`, workspace-scope `CLAUDE.md`/`AGENTS.md`, `framework/boundaries.md` compression.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 50k-100k |
| Human attention | 3 gates: requirements, plan, closure; ~5 min/gate |
| Re-Specify tripwire | 80% reduction unreachable without dropping `@boundaries.md` or breaking byte-identity sync |

## Current State

The three system templates `framework/templates/system/claude/CLAUDE.md`, `framework/templates/system/codex/AGENTS.md`, and `framework/templates/system/copilot/copilot-instructions.md` are 103 lines each and ~95% byte-identical (only the *Canonical source:* path differs). The shared body inlines: a two-scope instruction model, the spec-workflow lifecycle, the spec-type table, an "Available skills" catalog, a "Workflows (shared prompts)" table, and a "Note for non-Copilot agents" section. The same content is already canonical in `docs/ai-agent-framework.md` (164 lines).

Every Claude/Codex/Copilot session loads its template as system-prompt overhead (~103 lines auto-loaded before user input). Because each agent loads only its own file, the cost is 1× ~103 lines per session — not 3× — but the file content is structural prose that biases the agent to preload related skill bodies from the embedded catalog. `cites-reqs:` omitted — framework-convention work, no project requirements baselines touched.

## Proposed Improvement

Reduce each system template to ≤25 lines containing: title, the existing *rendered by / canonical source* pointer, the `*Active profile:*` line, the `@boundaries.md` import, and 2-3 plain pointer lines to `docs/ai-agent-framework.md` (catalog of skills, prompts, two-scope model, non-Copilot agent notes) and `docs/spec-workflow-guide.md` (lifecycle and gate rules). Drop all inline lifecycle/skills/workflow/non-Copilot-notes content. `make sync-agents` byte-identity gate between the three files continues to pass.

**Measurable benefit:** Per-file line count drops from 103 → ≤20 lines (≥80% reduction). Verified by `wc -l framework/templates/system/{claude,codex,copilot}/*` at HEAD before/after closure.

## Requirements

- FR-1: Each system-template file MUST be ≤25 lines.
- FR-2: Each system template MUST contain only: title, the *rendered by / canonical source* line, the `*Active profile:*` line, the `@boundaries.md` import, and ≤3 plain pointer lines to `docs/ai-agent-framework.md` and `docs/spec-workflow-guide.md`.
- FR-3: Each system template MUST NOT inline the two-scope model table, the "Available skills" table, the "Workflows (shared prompts)" table, the spec-type table, the spec-lifecycle prose, or the "Note for non-Copilot agents" section.
- FR-4: The byte-identity sync gate (`framework/.github/scripts/sync-agents.sh` or equivalent, plus CI gates under `framework/scripts/test/`) MUST continue to enforce parity between the three files modulo the *Canonical source:* path line.
- FR-5: `docs/ai-agent-framework.md` MUST be the authoritative location for every piece of prose removed from system templates; any content not already present there MUST be added before the slim lands.

## Acceptance Criteria

### AC-1: Line budget met (FR-1, FR-2)

Given the three slimmed system templates at HEAD
When `wc -l framework/templates/system/{claude,codex,copilot}/*` runs
Then each file is ≤25 lines
And the measurable benefit is verified: each file is ≤20 lines (≥80% reduction from 103)

### AC-2: No duplicated catalog or workflow content (FR-3)

Given the three slimmed system templates at HEAD
When `grep -E 'Two-scope|Available skills|Workflows .shared prompts.|Note for non-Copilot' framework/templates/system/` runs
Then it returns no matches
And every removed section appears in `docs/ai-agent-framework.md`

### AC-3: Sync gate passes (FR-4)

Given the three slimmed templates committed
When the byte-identity sync gate runs (locally and in CI)
Then it MUST report parity between the three files

### AC-4: docs/ai-agent-framework.md is authoritative (FR-5)

Given a reader follows the pointer from any slimmed template
When they open `docs/ai-agent-framework.md`
Then they MUST find: the two-scope model, the full skills catalog, the workflow/prompts table, the spec-type table, and the non-Copilot agent notes

## Architecture

Skipped — convention/refactor at the system-prompt layer; no bounded-context, schema, or pipeline impact.

## Out of Scope

- OS-1: `framework/boundaries.md` compression (90 lines) — separate IMP candidate.
- OS-2: Project-scope `.github/copilot-instructions.md` files in any project repo — out of `ai-dotfiles` scope.
- OS-3: Workspace-scope `tobevisit/CLAUDE.md` and `tobevisit/.github/copilot-instructions.md` — out of `ai-dotfiles` scope.
- OS-4: Any change to `@`-import resolution semantics across Claude/Codex/Copilot.

## Split Decision

Split into: `IMP-20260513-slim-skill-bodies`, `IMP-20260513-slim-framework-prompts`, `IMP-20260513-slim-spec-templates`. This spec owns FR-1 through FR-5 covering the system-template layer only. Per `splitting-rules.md § 2`: each layer is independently testable (per-layer line-count AC), independently revertable, and the alternative single-IMP plan would exceed 8 tasks. No `splitting-rules.md § 4` exception applies.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/ai-agent-framework.md` — confirm it carries the full two-scope model, skills catalog, workflow/prompts table, spec-type table, and non-Copilot agent notes; backfill any gap as the Plan's first task.

## Rollout / migration notes

- The three slimmed templates remain byte-identical (modulo the *Canonical source:* line) so `ai-profile-init.sh` symlink behavior is unchanged.
- No downstream-project coordination needed — system-scope only.
