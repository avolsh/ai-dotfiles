# Workspace Bootstrap Guide

*Last updated: 2026-05-13*

Authoring guidance for the workspace-root instruction file
(`.github/copilot-instructions.md`) produced by `ai-workspace`. Conceptual
background — framework layout, two-scope model, multi-agent matrix —
lives in [`ai-agent-framework.md`](ai-agent-framework.md). End-to-end
bootstrap workflow (modes, verification, hard rules) lives in
[`bootstrapping-project.md`](bootstrapping-project.md). This guide covers
only what the workspace-bootstrap author fills in or omits.

---

## What stays in the workspace template

A workspace root sits **above** projects and routes work into them. The
slimmed `.github/copilot-instructions.md` retains only load-bearing
workspace-scope content:

- `## Projects` — name → path → one-line purpose. The single source of
  truth for project locations within the workspace. One row per project.
- `## Project routing` — per-project "read first" order and build/test
  commands. Tells the agent how to descend into a specific project when
  a task targets it.
- `## Shared safety` — workspace-scope boundary-equivalent rules
  (external systems, env-secret rule, cross-repo schema-change rule).
  Parallel to project-scope `## Boundaries` in the project template.
- `## Cross-repository coordination` — inter-project contracts: schema
  changes, output-format changes, `affected-repos` discipline.

Everything else (where `docs/` lives at the workspace layer, the
framework-overview prose about `<system>/`, the skills catalog, the
spec-types table) is reachable via
[`ai-agent-framework.md`](ai-agent-framework.md). Do **not** restate
that material in the workspace template.

## Workspace `docs/` layout (authoring rule)

A workspace `docs/` folder is **optional** and only carries content
that spans multiple projects or applies at the workspace layer:

- `docs/specs/active/` and `docs/specs/archived/` — workspace-level
  specs (CR, BUG, IMP) that span multiple projects or apply at the
  workspace layer.
- `docs/improvements-log.md` — workspace-wide process improvements
  log. Project-specific improvements live in each project's own
  `docs/improvements-log.md`.
- `docs/architecture/` — workspace-level architecture (optional).

If the workspace has no cross-project specs or workspace-layer
architecture at bootstrap time, leave the `docs/` subdirectories empty
(the bootstrap creates only what the manifest requires).

## Multi-agent sync (workspace layer)

A workspace root participates in the same three-tool fan-out as a
project: `CLAUDE.md` is a one-line `@`-import of
`.github/copilot-instructions.md`, `AGENTS.md` is a generated
self-contained copy produced by `.github/scripts/sync-agents.sh`, and
GitHub Copilot reads the source file directly. Edit only
`.github/copilot-instructions.md`; run `make sync-agents` to regenerate
`AGENTS.md`; never hand-edit `AGENTS.md`.

The workspace `Makefile` exposes only framework targets (`sync-agents`,
`sync-agents-check`) — workspace roots have no build commands of their
own.

## Anti-patterns

- **Inlining framework prose** — descriptions of `<system>/`, the
  skills catalog, or the spec-types table belong in
  [`ai-agent-framework.md`](ai-agent-framework.md). The workspace
  template points at the framework doc; it does not duplicate it.
- **Duplicating project-scope rules** — coding conventions, tech-stack
  rules, and per-project boundaries live in each project's
  `.github/copilot-instructions.md`. The workspace file routes; it does
  not legislate within a project.
- **Cross-repo changes without `affected-repos`** — any spec that
  touches more than one project MUST list every repo in the
  front-matter `affected-repos:` field.
