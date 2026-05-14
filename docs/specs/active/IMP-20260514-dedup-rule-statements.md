---
id: IMP-20260514-dedup-rule-statements
type: IMP
date: 2026-05-14
status: specify
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/boundaries.md
  - framework/spec-workflows/spec-lifecycle.md
  - framework/skills/writing-specs/SKILL.md
  - framework/prompts/create-spec.prompt.md
  - framework/prompts/plan-spec.prompt.md
  - framework/prompts/bug-triage.prompt.md
  - framework/prompts/visualize-spec.prompt.md
  - framework/templates/system/claude/CLAUDE.md
  - framework/templates/system/copilot/copilot-instructions.md
  - framework/templates/system/codex/AGENTS.md
affected-code:
  - scripts/generate-system-templates.sh
  - Makefile
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
siblings:
  - IMP-20260514-spec-validator
  - IMP-20260514-framework-subagents
  - IMP-20260514-trivial-lane
  - IMP-20260514-research-lane
depends-on:
  - IMP-20260514-spec-validator
---

# IMP-20260514-dedup-rule-statements

*Last updated: 2026-05-14*

## Summary

- **Goal:** Establish a single canonical location per rule and per system-template body, with every other site linking by anchor; reduce duplicate rule statements to ≤1 canonical + N pointers.
- **Scope:** Rule restatements across `boundaries.md`, `spec-lifecycle.md § Rules`, `writing-specs/SKILL.md` (Hard rules section), and the four `prompts/*.prompt.md` (Hard rules sections); plus the three near-identical `templates/system/{claude,copilot,codex}/` templates (canonical-template generator fold-in).
- **Out of scope:** Changing any rule's semantic intent; weakening, merging, or deleting rules; rewriting yesterday's slim-* compressions; changing rule wording in project-scope `.github/copilot-instructions.md` files.

## Cost Estimate

| Estimate | Value |
|---|---|
| Token range | 120k-200k |
| Human attention | 4 gates (specify + plan + 1-2 task gates + closure); ~15 min/gate; rule edits warrant close review |
| Re-Specify tripwire | A "duplicate" turns out to be semantically distinct on close reading (e.g., two rules use similar prose but cover different conditions); OR canonical-template generator design exceeds 50 LoC |

## Current State

Duplicate rule statements identified by inspection of HEAD:

- **"Never skip Specify"** appears in `boundaries.md § Never do #2`, `spec-lifecycle.md § Rules #1`, `writing-specs/SKILL.md` (implicit in description), `create-spec.prompt.md § Hard rules`.
- **"Never write `## Tasks` while status is `specify`"** appears in `boundaries.md § Never do #3`, `spec-lifecycle.md § Rules #2`, `create-spec.prompt.md § Hard rules`.
- **"Never flip status without human approval"** appears in `boundaries.md § Never do #4`, `spec-lifecycle.md § Rules #3/#4/#5`, `spec-workflow-guide.md`.
- **"Always update `*Last updated:*`"** appears in `boundaries.md § Always do #10`, `spec-lifecycle.md § Rules #6`.
- **"Always update task row status in-place"** appears in `boundaries.md § Always do #11`, `spec-lifecycle.md § Rules #7`.
- **Split-check mandate** appears in `boundaries.md § Always do` (implicit), `spec-lifecycle.md § Rules #9/#11/#12`, `splitting-rules.md § 2`, `create-spec.prompt.md § Steps #4`, `writing-specs/SKILL.md § References`.

Three system templates (`templates/system/{claude/CLAUDE.md, copilot/copilot-instructions.md, codex/AGENTS.md}`) carry near-identical content rendered via single-variable `envsubst` (`$AI_PROFILE`). Maintained by hand today; drift risk on every framework change.

`cites-reqs:` omitted — framework-convention work, no project requirements baselines.

## Proposed Improvement

**Part A — Rule single-source.** For each rule with ≥2 restatements:

1. Choose one canonical home (default: `boundaries.md` for behavioral rules; `spec-lifecycle.md` for lifecycle-specific rules).
2. Add an anchor to the canonical statement (e.g., `#never-skip-specify`).
3. Replace every other restatement with a one-line markdown link pointing to the canonical anchor (concrete path filled at implementation time, e.g. linking to `boundaries.md § Never do #2` via its `#never-skip-specify` anchor).
4. Update `agent-protocol.md`, prompts, and SKILL.md hard-rules sections to use these links.

**Part B — Canonical-template generator.** Replace three near-identical templates with one shared `templates/system/_canonical.md` plus a tiny `scripts/generate-system-templates.sh` that produces the three tool-flavored variants on `make sync-system-templates`. Variants only diverge on the front-matter and the tool-name banner.

**Measurable benefit:** Duplicate rule-statement count drops from current N≥6 to ≤1 canonical + N pointers per rule. Verified by `grep -c "Never skip Specify"`-style spot-checks listed in Closure Evidence. Template line-count drops from 3 × full templates to 1 canonical + small generator (~30 LoC).

## Requirements

- FR-1: Every rule currently restated in ≥2 framework files MUST live as a single canonical statement with an HTML anchor; every other site MUST reference it via a markdown link to that anchor.
- FR-2: A "rule duplicate map" MUST be added under `docs/rule-canonical-map.md` enumerating each rule, its canonical location (with anchor), and every site that links to it.
- FR-3: `scripts/generate-system-templates.sh` MUST produce `templates/system/{claude/CLAUDE.md, copilot/copilot-instructions.md, codex/AGENTS.md}` from a single `templates/system/_canonical.md` source.
- FR-4: `make sync-system-templates` MUST run the generator; running it on a clean tree MUST be a no-op (idempotent).
- FR-5: `make lint-rules` MUST be added that fails when any rule from `docs/rule-canonical-map.md` appears verbatim in a non-canonical file (catches future drift).
- FR-6: No rule's semantic intent MUST change. Closure Evidence MUST present a rule-by-rule before/after summary.
- FR-7: The `validate-specs.py` from `IMP-20260514-spec-validator` MUST continue to pass after the dedup pass (no new findings introduced).

## Acceptance Criteria

### AC-1: Rule canonical map exists and is complete (FR-1, FR-2)

Given `docs/rule-canonical-map.md` at HEAD
When inspected
Then every rule with a current restatement count ≥2 is listed
And each row names a canonical location with an HTML anchor
And each row enumerates every linking site

### AC-2: Restatements replaced by links (FR-1)

Given the framework files at HEAD
When `make lint-rules` runs
Then exit code is zero
And no rule from the canonical map appears verbatim in a non-canonical file

### AC-3: Canonical-template generator produces three variants (FR-3, FR-4)

Given `templates/system/_canonical.md` at HEAD
When `make sync-system-templates` runs on a clean tree
Then `templates/system/{claude/CLAUDE.md, copilot/copilot-instructions.md, codex/AGENTS.md}` are unchanged (idempotent no-op)
And modifying `_canonical.md` and re-running regenerates all three correctly

### AC-4: Lint-rules catches drift (FR-5)

Given a deliberately-introduced rule duplicate (test fixture)
When `make lint-rules` runs
Then exit code is non-zero
And the offending file:line is named in the output

### AC-5: Semantic equivalence preserved (FR-6)

Given the closure gate
When the human reviews the rule-by-rule before/after summary in Closure Evidence
Then every rule's semantic intent is judged equivalent

### AC-6: Validator stays green (FR-7)

Given HEAD after the dedup pass
When `make validate-specs` (from sibling IMP-20260514-spec-validator) runs
Then exit code is zero

## Architecture

Skipped — prose dedup and a template-generation script. No bounded-context change; the canonical-template generator is a leaf-level shell script, not a new framework subsystem.

## Out of Scope

- OS-1: Weakening, merging, or deleting any rule (compression of phrasing only — link-and-anchor mechanics only).
- OS-2: Moving rules between tiers (Always / Ask / Never) — structure is frozen per IMP-20260513-compress-boundaries.
- OS-3: Changing project-scope `.github/copilot-instructions.md` files in tobevisit-content / web / docs (workspace propagation handled in `IMP-20260514-framework-subagents` or follow-up).
- OS-4: Replacing the entire `envsubst` toolchain — the generator is a thin shell wrapper, not a templating rewrite.
- OS-5: Renaming any framework file or moving rules to new files outside the canonical set.

## Split Decision

Kept as one spec. § 1 independent testability: rule-dedup and canonical-template generator share a single closure metric (no semantic regression + `make lint-rules` + `make sync-system-templates` both green); E2 applies (template-generator and rule-dedup share the same theme — "duplicate content" — and a closure-time semantic-equivalence check). Splitting would force coordinated revert if any rule wording change triggered a regenerate of `_canonical.md`.

## Tasks

Pending — Plan stage only.

## Agent instructions

Per `<system>/skills/agent-protocol/SKILL.md`.

## Docs updates required

- `docs/rule-canonical-map.md` — new file (FR-2).
- `docs/ai-agent-framework.md` — add rows for `make lint-rules` and `make sync-system-templates`.
- All four `framework/prompts/*.prompt.md` — replace inline "Hard rules" sections with anchor links.
- `framework/skills/writing-specs/SKILL.md` — replace inline rule restatements with anchor links.
- `framework/spec-workflows/spec-lifecycle.md § Rules` — keep rules that ARE lifecycle-specific canonical here; link out the rest.

## Rollout / migration notes

- Depends on `IMP-20260514-spec-validator` reaching `done` first so the dedup is protected by a green validator gate.
- Each rule-replacement task closes with `make lint-rules` + `make validate-specs` green.
- Template generator lands as an addition first (generator + canonical), THEN the three rendered files are switched to "generated, do not edit" headers in a second task to avoid mid-state where two sources of truth coexist.
