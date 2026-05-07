---
name: bootstrapping-project
description: >
  Scaffolds a new project — or retrofits an existing one — so it complies
  with the AI Agent Framework. Use when onboarding a repo into
  `<workspace>/PROJECTS.md` (when configured) or when framework structure
  needs to be added or refreshed.
---

# Bootstrapping a Project

*Last updated: 2026-05-07*

## When to use

- A new project is being added to `<workspace>/PROJECTS.md` (or stood up on
  a host with no workspace map).
- An existing project has outdated or missing framework artifacts (no
  `.github/copilot/`, no `docs/specs/`, stale instructions).
- The framework (in `<system>`) has been upgraded and projects need to
  catch up.

## Two operating modes

| Mode | Prompt | When |
|---|---|---|
| **Bootstrap** | [`<system>/prompts/bootstrap-project.prompt.md`](../../prompts/bootstrap-project.prompt.md) | New project; no `.github/copilot/` exists yet |
| **Update** | [`<system>/prompts/update-project.prompt.md`](../../prompts/update-project.prompt.md) | Project already has framework artifacts; bring them up to date |

Bootstrap is additive. Update is a diff.

## Scaffold manifest

The minimum artifacts a project must have to participate in the framework.
Full details per artifact:
[`references/scaffold-manifest.md`](references/scaffold-manifest.md).

### Required (bootstrap fails without these)

| Path (relative to `<project>/`) | Purpose |
|---|---|
| `.github/copilot-instructions.md` | Canonical project instructions. **Freestanding — no `@`-imports.** References `<system>/...` for framework, `<workspace>/...` for the workspace map. |
| `AGENTS.md` | **Generated mechanically** from `.github/copilot-instructions.md` by `scripts/sync-agents.sh`. No hand edits. No `@`-imports — Codex requires self-contained content. |
| `CLAUDE.md` | Slim. Exactly two `@`-imports: `@.github/copilot-instructions.md` and `@.github/copilot/instructions/general.md`. |
| `.github/copilot/instructions/general.md` | Per-filetype conventions + project-specific boundaries |
| `scripts/sync-agents.sh` | Project-local copy of the canonical sync-agents script. Regenerates `AGENTS.md` from `.github/copilot-instructions.md`. Must be `chmod +x`. |
| `Makefile` (with `sync-agents` and `sync-agents-check` targets) | Project-local entry points — the generated `AGENTS.md` banner names `make sync-agents`, so the targets must exist. |
| `docs/README.md` | Human doc entry point |
| `docs/specs/active/README.md` | Spec home, overview |
| `docs/specs/archived/README.md` | Archived specs index |
| `docs/architecture/module-map.md` | Bounded contexts → key files → workflow steps |
| `docs/improvements-log.md` | Append-only process-improvement log |

### Recommended (fill in as the project grows)

| Path | Purpose |
|---|---|
| `docs/architecture/system-overview.md` | High-level system diagram and data flow |
| `docs/architecture/code-conventions.md` | Linting, naming, file layout conventions |
| `docs/requirements/README.md` | Per-feature requirements baselines: FRs, invariants, NFRs, out-of-scope items, and current-state authority. See `<system>/skills/writing-specs/references/baseline-citations.md`. |
| `.github/copilot/skills/<skill-name>/SKILL.md` | Project-scope skills |
| `.github/copilot/prompts/<workflow>.prompt.md` | Project-scope workflow prompts |

### Excluded (never committed)

- `.env`, `.env.local`, `.dev.vars`
- Credentials, tokens, service-account JSON
- `.claude/` or other per-user IDE state

## Workflow (summary)

1. **Scan** the project for existing tech stack, build tool, test framework.
2. **Classify** as bootstrap (new) or update (existing).
3. **Render** each required artifact from the templates in
   `references/scaffold-manifest.md`. Fill placeholders from the scan.
   Copy `<system>/templates/scripts/sync-agents.sh` into the project's
   `scripts/sync-agents.sh` and `chmod +x` it.
4. **Generate** `AGENTS.md` mechanically — run `make sync-agents` (which
   invokes the project-local `scripts/sync-agents.sh`). The bootstrap is
   not complete until this step succeeds and `make sync-agents-check`
   exits 0.
5. **Validate** — every link resolves, every referenced skill exists, and
   `grep -E '^@' AGENTS.md` returns no matches (Codex compatibility).
6. **Register** in `<workspace>/PROJECTS.md` with path, purpose, build
   commands. **Conditional** — skip this step if the host has no
   `<workspace>` configured (single-project hosts).
7. **Present** the diff to the human for review. Commit only after approval.

Each step is gated. This is not an autonomous scaffold — every artifact is
shown to the human before it's written.

## Verification step (post-bootstrap)

Before declaring the scaffold complete, scaffold a throwaway project and
confirm:

- Opening Claude Code at the throwaway project root loads `~/.claude/CLAUDE.md`
  (system) **and** the project `CLAUDE.md`, and resolves all `<system>/...`
  references against `~/.claude/`.
- `grep -E '^@' AGENTS.md` returns no matches (AGENTS.md is fully
  self-contained for Codex).
- `make sync-agents-check` exits 0.

## Pre-flight for any bootstrapping session

- [ ] Read `<system>/boundaries.md`
- [ ] Read `<workspace>/PROJECTS.md` (skip if `<workspace>` is not configured)
- [ ] Read this `SKILL.md`
- [ ] Read [`references/scaffold-manifest.md`](references/scaffold-manifest.md)

## Hard rules

- Never overwrite an existing file without showing the diff and getting approval.
- Never commit `.env` or secret material even as a placeholder.
- Never invent build commands — derive them from `package.json`, `Makefile`,
  `Cargo.toml`, or equivalent.
- Never skip `docs/architecture/module-map.md` — the agent-protocol
  post-task checklist requires it, so it must exist on day one.
- If the project's primary language or stack is unclear, stop and ask.

## File naming conventions

| Artifact | Pattern | Example |
|---|---|---|
| Documentation files | `kebab-case.md` | `ai-place-filtering.md` |
| ADRs | `ADR-NNNN-<kebab-case-title>.md` | `ADR-0001-openai-model-selection.md` |
| Specs | `<TYPE>-YYYYMMDD-<kebab-case-title>.md` | `CR-20260227-ai-filtering.md` |
| Skill folders | `<gerund-kebab-case>/` | `writing-specs/`, `running-pipeline-steps/` |

No underscores. No spaces. Lowercase only (except `ADR-`/`CR-`/`BUG-`/`IMP-` prefixes).

## Content boundary

| Content | Location |
|---|---|
| Repo purpose, tech stack, build commands | `.github/copilot-instructions.md` |
| Rule summary (boundaries) | `.github/copilot-instructions.md` + `.github/copilot/instructions/general.md` |
| Per-filetype coding rules | `.github/copilot/instructions/` |
| Deep procedural knowledge | `.github/copilot/skills/` |
| Workflow templates | `.github/copilot/prompts/` |
| Everything else (architecture, schemas, runbooks, specs) | `docs/` |

## Anti-patterns

- **Copy-paste from another project verbatim** — stack-specific bits
  (test runner, barrel conventions, CMS adapters) must be tailored.
- **Autogenerated placeholder prose** — "This project is an amazing
  system that leverages cutting-edge AI..." Keep the artifact literal
  and testable.
- **Bootstrap without module map** — leaves every later session doing
  exploratory reads.
- **Retrofitting across every project at once** — do one project at a
  time so diffs stay reviewable.
