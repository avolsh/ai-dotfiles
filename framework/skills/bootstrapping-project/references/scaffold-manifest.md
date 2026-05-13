# Scaffold Manifest

*Last updated: 2026-05-12*

Per-artifact guidance for the [`bootstrapping-project`](../SKILL.md) skill.
Placeholders use `<angle-brackets>` — replace every one before writing.

Templates live in `<system>/templates/`:

- `<system>/templates/system/` — per-tool system templates (rendered into profile dirs by `ai-profile-init`)
- `<system>/templates/workspace/` — workspace scaffold templates (used by `ai-workspace`)
- `<system>/templates/project/` — project scaffold templates (used by `ai-project`)

---

## Required project artifacts

All 10 artifacts are scaffolded into a new project by `ai-project`,
which copies the templates from `<system>/templates/project/`
preserving directory structure.

### 1. `.github/copilot-instructions.md`

Template: `<system>/templates/project/.github/copilot-instructions.md`

Canonical project instructions (~100 lines). Sections: Purpose, Tech Stack,
Codebase Layout, Context Loading, Boundaries, Skill & prompt resolution,
Available skills, Workflows, Build and Run.

**Freestanding — no `@`-imports.** References `<system>/...` for framework
artifacts (skills catalog, prompts, spec-workflows, templates, boundaries)
and the workspace root files for the workspace map (when configured).
The `## Boundaries` section absorbs project-specific rules that previously
lived in `general.md`. The `## Skill & prompt resolution` section
documents the two-scope lookup order for all three tools.

### 2. `AGENTS.md`

Template: `<system>/templates/project/AGENTS.md` (not-a-template marker).

*Generated mechanically from `.github/copilot-instructions.md` by
`.github/scripts/sync-agents.sh`; no hand edits, no `@`-imports — Codex
requires self-contained content.* The generator banner names
`make sync-agents`, so the project Makefile MUST expose `sync-agents`
and `sync-agents-check` targets.

### 3. `CLAUDE.md`

Template: `<system>/templates/project/CLAUDE.md`

Slim. Exactly **one** `@`-import: `@.github/copilot-instructions.md`.
Claude Code resolves the import at session start, pulling in the canonical
project instructions (which themselves include the project Boundaries
section). No `general.md` import — that file no longer exists; its
content is now in `copilot-instructions.md` § Boundaries.

### 4. `.github/scripts/sync-agents.sh`

Template: `<system>/templates/project/.github/scripts/sync-agents.sh`

Verbatim copy of the canonical script. Render into the project under
`.github/scripts/sync-agents.sh`, `chmod +x`, and commit. Regenerates
`AGENTS.md` from `.github/copilot-instructions.md`. Supports `--check`
for drift gates.

> **Known debt:** when the upstream canonical script changes, every
> already-bootstrapped project carries the older copy. v1 accepts manual
> re-sync per project; a future spec automates it.

### 5. `Makefile`

Template: `<system>/templates/project/Makefile`

Must expose at minimum:

- `sync-agents` — calls `./.github/scripts/sync-agents.sh`
- `sync-agents-check` — calls `./.github/scripts/sync-agents.sh --check`

Required because the generated `AGENTS.md` banner says
"Regenerate with: make sync-agents". Drift CI invokes `sync-agents-check`.

### 6. `docs/README.md`

Template: `<system>/templates/project/docs/README.md`

Human entry point. Quick links to module map, active/archived specs,
improvements log, architecture docs.

### 7. `docs/specs/active/README.md` + `docs/specs/archived/README.md`

Templates: `<system>/templates/project/docs/specs/active/README.md` and
`<system>/templates/project/docs/specs/archived/README.md`

Index tables for specs. Active = `specify`/`plan`/`in-progress`. Archived =
`done`. Link to `<system>/spec-workflows/README.md` for the full lifecycle.

### 8. `docs/architecture/module-map.md`

Template: `<system>/templates/project/docs/architecture/module-map.md`

**Required on day one.** The agent-protocol post-task checklist updates it,
so it must exist. Tables: Bounded Contexts, Cross-Cutting Files,
Workflow → Context Mapping. Start minimal — one-line placeholder if no
contexts exist yet.

### 9. `docs/improvements-log.md`

Template: `<system>/templates/project/docs/improvements-log.md`

Append-only log. Entry format: date, spec/task, category, what was found,
what was changed, suggested follow-up. Mandatory timing rule: log
improvements immediately when discovered.

---

## Workspace root artifacts

When the working directory is a **workspace root** (contains multiple
sub-projects), the root itself must also be scaffolded. Run `ai-workspace`
from the workspace root — the script copies all 6 templates from
`<system>/templates/workspace/` preserving directory structure.

| Path | Template | Purpose |
|---|---|---|
| `CLAUDE.md` | `<system>/templates/workspace/CLAUDE.md` | Slim. Single `@.github/copilot-instructions.md` import. Claude Code loads this at session start, giving it awareness of the workspace structure. |
| `AGENTS.md` | `<system>/templates/workspace/AGENTS.md` (not-a-template marker) | Self-contained. Generated mechanically from `.github/copilot-instructions.md` by `.github/scripts/sync-agents.sh`. |
| `.github/copilot-instructions.md` | `<system>/templates/workspace/.github/copilot-instructions.md` | Canonical workspace instructions — project table, routing, shared safety, cross-repo coordination, AI agent framework section. Documents `docs/` as the workspace-wide folder. |
| `.github/scripts/sync-agents.sh` | `<system>/templates/workspace/.github/scripts/sync-agents.sh` | Byte-identical to the project sync-agents script. Regenerates `AGENTS.md` from `.github/copilot-instructions.md`. Must be `chmod +x`. |
| `Makefile` | `<system>/templates/workspace/Makefile` | Framework targets only (`sync-agents`, `sync-agents-check`). No build or test targets at the workspace level. |
| `docs/improvements-log.md` | `<system>/templates/workspace/docs/improvements-log.md` | Workspace-wide append-only process-improvement log. Project-scope improvements live in each project's own `docs/improvements-log.md`. |

All 6 files must exist for the workspace to participate in the framework.
If neither a project nor a workspace root has `CLAUDE.md` / `AGENTS.md`,
agents start sessions with zero project context — the `create-spec`
prompt's Step 1 silently skips, and every subsequent decision is uninformed.

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
3. Run `ai-project` from the project root. The script copies every
   template under `<system>/templates/project/` into cwd preserving
   directory structure (existing files are skipped) and `chmod +x`'s
   `.github/scripts/sync-agents.sh`.
4. Fill `<placeholder>` markers in the scaffolded files.
5. **Run sync-agents to generate AGENTS.md.** `make sync-agents` (or
   `./.github/scripts/sync-agents.sh` directly) writes the banner-tagged
   self-contained `AGENTS.md`.
6. Validate: every link resolves, every referenced skill exists,
   `grep -E '^@' AGENTS.md` returns no matches, `make sync-agents-check`
   exits 0.
7. On approval, commit. Add a row to the workspace root `CLAUDE.md`,
   `AGENTS.md`, and `.github/copilot-instructions.md` if the host has a
   workspace (skip otherwise).

## Update walkthrough

`update-project.prompt.md` was retired. Updates are now manual:

1. Read every required path in the existing project.
2. For each missing path, re-run `ai-project` (idempotent — only missing
   files are added; existing files are never overwritten).
3. For each stale path, propose a minimal patch by diffing against the
   template at `<system>/templates/project/<path>`.
4. After source edits, regenerate `AGENTS.md` via `make sync-agents`.
5. Present diff. On approval, apply.
