# <workspace-name> — workspace root

*Last updated: YYYY-MM-DD*

This is a multi-project workspace. Individual projects have their own
`.github/copilot-instructions.md` with project-specific instructions.

## Projects

| Project | Path | Purpose |
|---|---|---|
| <project-name> | `<path/to/project/>` | <one-line purpose> |
<!-- Add one row per project in the workspace. -->

## Project routing

When a task targets a specific project, `cd` into its directory and read
that project's `.github/copilot-instructions.md` first.

### <project-name>
- Read first: `.github/copilot-instructions.md` → `docs/README.md` → `docs/architecture/module-map.md`
- Commands: `<build/test commands>`

<!-- Add per-project routing subsections as the workspace grows. -->

## Shared safety

- External systems: <list shared external dependencies — APIs, databases, queues>
- Config is env-driven; **never commit `.env` files or keys**
- Cross-repo schema/output changes must be coordinated via a single spec
<!-- Add workspace-wide safety rules below. -->

## Cross-repository coordination

- <Describe inter-project contracts: schema changes, output format changes, etc.>
- Cross-repo changes must list all repos in `affected-repos` front-matter.
<!-- Add coordination rules as cross-project dependencies emerge. -->

## AI agent framework

`docs/` is the workspace-wide folder. It contains:

- `docs/specs/active/` and `docs/specs/archived/` — workspace-level specs (CR, BUG, IMP) that span multiple projects or apply at the workspace layer
- `docs/improvements-log.md` — workspace-wide process improvements log (project-specific improvements live in each project's own `docs/improvements-log.md`)
- `docs/architecture/` — workspace-level architecture (optional)

The framework itself (skills, prompts, spec-workflow templates, system
boundaries) lives in `<system>/`. See `<system>/skills/` for available
agent skills and `<system>/spec-workflows/` for spec lifecycle, types,
and templates.
