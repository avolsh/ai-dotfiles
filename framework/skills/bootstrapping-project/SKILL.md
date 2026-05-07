---
name: bootstrapping-project
description: >
  Scaffolds a new project — or retrofits an existing one — so it complies
  with the workspace AI Agent Framework. Use when onboarding a repo into
  PROJECTS.md, or when framework structure needs to be added or refreshed.
---

# Bootstrapping a Project

*Last updated: 2026-04-29*

## When to use

- A new project is being added to `PROJECTS.md`.
- An existing project has outdated or missing framework artifacts (no
  `.github/copilot/`, no `docs/specs/`, stale instructions).
- The workspace framework has been upgraded and projects need to catch up.

## Two operating modes

| Mode | Prompt | When |
|---|---|---|
| **Bootstrap** | [`<root>/.github/copilot/prompts/bootstrap-project.prompt.md`](../../prompts/bootstrap-project.prompt.md) | New project; no `.github/copilot/` exists yet |
| **Update** | [`<root>/.github/copilot/prompts/update-project.prompt.md`](../../prompts/update-project.prompt.md) | Project already has framework artifacts; bring them up to date |

Bootstrap is additive. Update is a diff.

## Scaffold manifest

The minimum artifacts a project must have to participate in the framework.
Full details per artifact:
[`references/scaffold-manifest.md`](references/scaffold-manifest.md).

### Required (bootstrap fails without these)

| Path (relative to `<project>/`) | Purpose |
|---|---|
| `.github/copilot-instructions.md` | Canonical project instructions |
| `AGENTS.md` | Thin `@.github/copilot-instructions.md` include |
| `CLAUDE.md` | Thin `@.github/copilot-instructions.md` include (+ per-filetype instructions if any) |
| `.github/copilot/instructions/general.md` | Per-filetype conventions + project-specific boundaries |
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
| `docs/requirements/README.md` | Per-feature requirements baselines: FRs, invariants, NFRs, out-of-scope items, and current-state authority. See `<root>/.github/copilot/skills/writing-specs/references/baseline-citations.md`. |
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
4. **Validate** — every link resolves, every referenced skill exists.
5. **Register** in `<root>/PROJECTS.md` with path, purpose, build commands.
6. **Present** the diff to the human for review. Commit only after approval.

Each step is gated. This is not an autonomous scaffold — every artifact is
shown to the human before it's written.

## Pre-flight for any bootstrapping session

- [ ] Read `<root>/.github/copilot-instructions.md`
- [ ] Read `<root>/.github/copilot/boundaries.md`
- [ ] Read `<root>/PROJECTS.md`
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
