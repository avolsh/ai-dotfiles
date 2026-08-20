# Scaffold Manifest

*Last updated: 2026-08-20*

Manifest of artifacts the `bootstrapping-project` skill scaffolds. Walkthroughs, rationale, and rules live in [`docs/bootstrapping-project.md`](../../../../docs/bootstrapping-project.md). Placeholders use `<angle-brackets>` — replace every one before writing.

Templates root: `<system>/templates/`.

- `<system>/templates/system/` — per-tool system templates (rendered into profile dirs by `ai-profile-init`).
- `<system>/templates/workspace/` — workspace scaffold templates (used by `ai-workspace`).
- `<system>/templates/project/` — project scaffold templates (used by `ai-project`).

---

## Required project artifacts (10)

All scaffolded by `ai-project`, which copies templates from `<system>/templates/project/` preserving directory structure. Bootstrap fails without these.

| # | Path (relative to `<project>/`) | Template (relative to `<system>/templates/project/`) | Purpose |
|---|---|---|---|
| 1 | `.github/copilot-instructions.md` | `.github/copilot-instructions.md` | Canonical project instructions (~100 lines). **Freestanding — no `@`-imports.** Sections: Purpose, Tech Stack, Codebase Layout, Context Loading, Boundaries, Skill & prompt resolution, Available skills, Workflows, Build and Run. |
| 2 | `AGENTS.md` | `AGENTS.md` (not-a-template marker) | **Generated mechanically** from `.github/copilot-instructions.md` by `.github/scripts/sync-agents.sh`. No hand edits, no `@`-imports — Codex requires self-contained content. Banner names `make sync-agents`. |
| 3 | `CLAUDE.md` | `CLAUDE.md` | Slim. Exactly **one** `@`-import: `@.github/copilot-instructions.md`. |
| 4 | `.github/scripts/sync-agents.sh` | `.github/scripts/sync-agents.sh` | Verbatim copy of canonical script. `chmod +x`. Regenerates `AGENTS.md` from `.github/copilot-instructions.md`. Supports `--check` for drift gates. |
| 5 | `Makefile` | `Makefile` | Must expose `sync-agents` (calls the script) and `sync-agents-check` (`--check`). Required because the generated `AGENTS.md` banner says "Regenerate with: make sync-agents". |
| 6 | `docs/README.md` | `docs/README.md` | Human entry point. Quick links to module map, active/archived specs, improvements log, architecture docs. |
| 7 | `docs/specs/active/README.md` | `docs/specs/active/README.md` | Index for `specify` / `plan` / `in-progress` specs. |
| 8 | `docs/specs/archived/README.md` | `docs/specs/archived/README.md` | Index for `done` specs. |
| 9 | `docs/architecture/module-map.md` | `docs/architecture/module-map.md` | **Required day one.** Tables: Bounded Contexts, Cross-Cutting Files, Workflow → Context Mapping. Start minimal — one-line placeholder if no contexts exist yet. |
| 10 | `docs/improvements-log.md` | `docs/improvements-log.md` | Append-only log. Format: date, spec/task, category, what was found, what was changed, suggested follow-up. |

**Sync-script debt:** when the upstream canonical script changes, every already-bootstrapped project carries the older copy. Manual re-sync per project until a future spec automates it.

---

## Workspace root artifacts (6)

Scaffolded by `ai-workspace` from `<system>/templates/workspace/`.

| Path (relative to workspace root) | Template (relative to `<system>/templates/workspace/`) | Purpose |
|---|---|---|
| `CLAUDE.md` | `CLAUDE.md` | Slim. Single `@.github/copilot-instructions.md` import. |
| `AGENTS.md` | `AGENTS.md` (not-a-template marker) | Self-contained. Generated mechanically from `.github/copilot-instructions.md`. |
| `.github/copilot-instructions.md` | `.github/copilot-instructions.md` | Canonical workspace instructions — project table, routing, shared safety, cross-repo coordination, AI agent framework section. Documents `docs/` as the workspace-wide folder. |
| `.github/scripts/sync-agents.sh` | `.github/scripts/sync-agents.sh` | Byte-identical to the project script. `chmod +x`. |
| `Makefile` | `Makefile` | Framework targets only (`sync-agents`, `sync-agents-check`). No build/test at the workspace level. |
| `docs/improvements-log.md` | `docs/improvements-log.md` | Workspace-wide append-only log. Project-scope improvements live in each project's own log. |

If neither a project nor a workspace root has `CLAUDE.md` / `AGENTS.md`, agents start sessions with zero project context.

---

## Recommended artifacts (fill in as the project grows)

| Path | Purpose |
|---|---|
| `docs/architecture/system-overview.md` | High-level diagram and data flow |
| `docs/architecture/code-conventions.md` | Linting, naming, file layout |
| `docs/architecture/design-system.md` | Design-system authority for projects with a UI. Carries the **Figma version table** — the single declaration site for every file key, current and frozen. Required before a spec's Visualize sub-step can reference Figma. See [`figma-file-organization.md § 6`](../../../prompts/references/figma-file-organization.md). |
| `docs/domain/README.md` | Per-feature domain baselines (FRs, invariants, NFRs, OS, current-state authority). See [`docs/baseline-citations.md`](../../../../docs/baseline-citations.md). |
| `.github/copilot/instructions/<filetype>.md` | Copilot `applyTo`-filtered per-filetype instructions (`typescript.md`, `tests.md`, `docs.md`). |
| `.github/copilot/skills/<name>/SKILL.md` | Project-scope skills |
| `.github/copilot/prompts/<name>.prompt.md` | Project-scope workflow prompts |
