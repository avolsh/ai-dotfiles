# Scaffold Manifest

*Last updated: 2026-04-20*

Per-artifact guidance for the [`bootstrapping-project`](../SKILL.md) skill.
Placeholders use `<angle-brackets>` — replace every one before writing.

For full file templates, see
[`<root>/.github/copilot/templates/`](../../../templates/).

---

## Required artifacts

### 1. `.github/copilot-instructions.md`

Canonical project instructions (~100 lines). Sections: Purpose, Tech Stack,
Codebase Layout, Context Loading, Non-negotiable rules, Boundaries,
Verification by Change Type, Build and Run, Available skills, Workflows.

`AGENTS.md` re-exports via `@.github/copilot-instructions.md`.
`CLAUDE.md` re-exports with `@.github/copilot/instructions/general.md`.

### 2. `.github/copilot/instructions/general.md`

Per-filetype rules auto-injected by Copilot on every request. Keep ≤ 20
bullets. Must include:

- Never commit secrets
- Follow existing patterns
- Update `*Last updated:*` dates
- Include tests with feature logic
- One task at a time, preflight proof
- Log improvements to `docs/improvements-log.md` immediately

### 3. `docs/README.md`

Human entry point. Quick links to module map, active/archived specs,
improvements log, architecture docs.

### 4. `docs/specs/active/README.md` + `docs/specs/archived/README.md`

Index tables for specs. Active = `specify`/`plan`/`in-progress`. Archived =
`done`. Link to `<root>/.github/copilot/spec-workflows/README.md` for
the full lifecycle.

### 5. `docs/architecture/module-map.md`

**Required on day one.** The agent-protocol post-task checklist updates it,
so it must exist. Tables: Bounded contexts, Workflow steps, Cross-cutting
files. Start minimal — one-line placeholder if no contexts exist yet.

### 6. `docs/improvements-log.md`

Append-only log. Entry format: date, context (task/spec), observation,
action taken. Referenced from boundaries and agent-protocol.

---

## Recommended artifacts

| Path | Purpose |
|---|---|
| `docs/architecture/system-overview.md` | High-level diagram and data flow |
| `docs/architecture/code-conventions.md` | Linting, naming, file layout |
| `.github/copilot/skills/<name>/SKILL.md` | Project-scope skills |
| `.github/copilot/prompts/<name>.prompt.md` | Project-scope workflow prompts |

---

## Bootstrap walkthrough

1. Read `package.json` / `Makefile` / `Cargo.toml` → identify stack + build commands.
2. Classify project (web, service, pipeline, library).
3. Render each required artifact; show as a single diff.
4. On approval, commit. Add a row to `<root>/PROJECTS.md`.

## Update walkthrough

1. Read every required path in the existing project.
2. For each missing path, render from guidance above.
3. For each stale path, propose a minimal patch (don't rewrite).
4. Present diff. On approval, apply.
