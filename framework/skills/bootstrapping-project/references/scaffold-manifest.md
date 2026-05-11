# Scaffold Manifest

*Last updated: 2026-05-11*

Per-artifact guidance for the [`bootstrapping-project`](../SKILL.md) skill.
Placeholders use `<angle-brackets>` — replace every one before writing.

For full file templates, see
[`<system>/templates/`](../../../templates/).

---

## Required artifacts

### 1. `.github/copilot-instructions.md`

Canonical project instructions (~100 lines). Sections: Purpose, Tech Stack,
Codebase Layout, Context Loading, Non-negotiable rules, Boundaries,
Verification by Change Type, Build and Run, Available skills, Workflows.

**Freestanding — no `@`-imports.** References `<system>/...` for framework
artifacts (skills catalog, prompts, spec-workflows, templates, boundaries)
and `<workspace>/PROJECTS.md` for the workspace map (when configured).
Do **not** include `@.github/copilot/instructions/general.md` — Codex does
not resolve `@`-imports, and `AGENTS.md` is generated mechanically from this
file, so the import would land as literal text and Codex would silently
skip the project rules.

### 2. `AGENTS.md`

*Generated mechanically from `.github/copilot-instructions.md` by
`scripts/sync-agents.sh`; no hand edits, no `@`-imports — Codex requires
self-contained content.* The generator banner names `make sync-agents`,
so the project Makefile MUST expose `sync-agents` and `sync-agents-check`
targets.

### 3. `CLAUDE.md`

Slim. Two `@`-imports only: `@.github/copilot-instructions.md` and
`@.github/copilot/instructions/general.md`. Claude Code resolves both at
session start; per-filetype rules in `general.md` are loaded into the
Claude session through the second import.

### 4. `.github/copilot/instructions/general.md`

Per-filetype rules auto-injected by Copilot on every request. Keep ≤ 20
bullets. Must include:

- Never commit secrets
- Follow existing patterns
- Update `*Last updated:*` dates
- Include tests with feature logic
- One task at a time, preflight proof
- Log improvements to `docs/improvements-log.md` immediately

### 5. `scripts/sync-agents.sh`

Verbatim copy of the canonical script shipped at
`<system>/templates/scripts/sync-agents.sh`. Render into the project root,
`chmod +x`, and commit. Regenerates `AGENTS.md` from
`.github/copilot-instructions.md`. Supports `--check` for drift gates.

> **Known debt:** when the upstream canonical script changes, every
> already-bootstrapped project carries the older copy. v1 accepts manual
> re-sync per project; a future spec automates it.

### 6. `Makefile`

Must expose at minimum:

- `sync-agents` — calls `./scripts/sync-agents.sh`
- `sync-agents-check` — calls `./scripts/sync-agents.sh --check`

Required because the generated `AGENTS.md` banner says
"Regenerate with: make sync-agents". Drift CI invokes `sync-agents-check`.

### 7. `docs/README.md`

Human entry point. Quick links to module map, active/archived specs,
improvements log, architecture docs.

### 8. `docs/specs/active/README.md` + `docs/specs/archived/README.md`

Index tables for specs. Active = `specify`/`plan`/`in-progress`. Archived =
`done`. Link to `<system>/spec-workflows/README.md` for
the full lifecycle.

### 9. `docs/architecture/module-map.md`

**Required on day one.** The agent-protocol post-task checklist updates it,
so it must exist. Tables: Bounded contexts, Workflow steps, Cross-cutting
files. Start minimal — one-line placeholder if no contexts exist yet.

### 10. `docs/improvements-log.md`

Append-only log. Entry format: date, context (task/spec), observation,
action taken. Referenced from boundaries and agent-protocol.

---

## Workspace root artifacts

When the working directory is a **workspace root** (contains `PROJECTS.md`
or multiple sub-projects), the root itself must also have `CLAUDE.md` and
`AGENTS.md`. These serve a different purpose than project-level files:

| Path | Purpose |
|---|---|
| `CLAUDE.md` | Slim. `@`-imports to workspace-level instructions (if any). Claude Code loads this at session start, giving it awareness of the workspace structure. |
| `AGENTS.md` | Self-contained. Lists all projects in the workspace, their paths, purposes, and cross-project conventions. Codex reads this for workspace-wide context. |

Both files must always exist. If neither a project nor a workspace root has
`CLAUDE.md` / `AGENTS.md`, agents start sessions with zero project context
— the `create-spec` prompt's Step 1 silently skips, and every subsequent
decision is uninformed.

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
3. Render each required artifact; show as a single diff. Copy
   `<system>/templates/scripts/sync-agents.sh` into `scripts/sync-agents.sh`
   and `chmod +x` it.
4. **Run sync-agents.sh to generate AGENTS.md.** `make sync-agents` (or
   `./scripts/sync-agents.sh` directly) writes the banner-tagged self-contained
   `AGENTS.md`.
5. Validate: every link resolves, every referenced skill exists,
   `grep -E '^@' AGENTS.md` returns no matches, `make sync-agents-check`
   exits 0.
6. On approval, commit. Add a row to `<workspace>/PROJECTS.md` if the host
   has a workspace map (skip otherwise).

## Update walkthrough

1. Read every required path in the existing project.
2. For each missing path, render from guidance above.
3. For each stale path, propose a minimal patch (don't rewrite).
4. After source edits, regenerate AGENTS.md via `make sync-agents`.
5. Present diff. On approval, apply.
