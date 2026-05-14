# Bootstrapping a Project

*Last updated: 2026-05-14*

How to scaffold a new project (or workspace root) so it complies with the AI Agent Framework: operating modes, workflow, verification, hard rules, file naming, content boundary, and anti-patterns. The artifact manifest (templates per file) lives in [`framework/skills/bootstrapping-project/references/scaffold-manifest.md`](../framework/skills/bootstrapping-project/references/scaffold-manifest.md).

---

## Three operating modes

| Mode | Command | When |
|---|---|---|
| **Bootstrap project** | `ai-project` (in target dir) | New project; no `.github/copilot/` exists yet |
| **Bootstrap workspace** | `ai-workspace` (in target dir) | New workspace root; no `CLAUDE.md`/`AGENTS.md` exists yet |
| **Update** | manual (re-run `ai-project` is idempotent — only missing files are added; existing files require manual review) | Project or workspace already has framework artifacts; bring them up to date |

Bootstrap is additive. Update is currently a manual diff against the
templates under `<system>/templates/{project,workspace}/`.

### Bootstrap workspace mode

A workspace root has no `.git/` requirement, no build commands, and no
project-scope skills — its `Makefile` exposes only framework targets
(`sync-agents`, `sync-agents-check`). Run `ai-workspace` from the target
workspace root to scaffold the 6 required workspace artifacts (see the
manifest's "Workspace root artifacts" table).

A workspace root does **not** create:
`.github/copilot/instructions/`, `docs/specs/`,
`docs/architecture/module-map.md` — those are project-only artifacts.

---

## Workflow

1. **Scan** the project for existing tech stack, build tool, test framework.
2. **Classify** as bootstrap (new) or update (existing).
3. **Scaffold** by running `ai-project` from the project root. The script
   copies every template under `<system>/templates/project/` into cwd
   preserving directory structure (existing files are skipped) and
   `chmod +x`'s `.github/scripts/sync-agents.sh`.
4. **Fill placeholders** in the scaffolded files (`<project-name>`,
   `<language>`, `<build command>`, etc.) from the scan results.
5. **Generate** `AGENTS.md` mechanically — run `make sync-agents` (which
   invokes `.github/scripts/sync-agents.sh`). The bootstrap is not
   complete until this step succeeds and `make sync-agents-check`
   exits 0.
6. **Validate** — every link resolves, every referenced skill exists, and
   `grep -E '^@' AGENTS.md` returns no matches (Codex compatibility).
7. **Register** in the workspace root `CLAUDE.md`, `AGENTS.md`, and
   `.github/copilot-instructions.md` with path, purpose, build commands.
   **Conditional** — skip this step if the host has no `<workspace>`
   configured (single-project hosts).
8. **Present** the diff to the human for review. Commit only after approval.

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
- [ ] Read `<workspace>/CLAUDE.md` (skip if `<workspace>` is not configured)
- [ ] Read `framework/skills/bootstrapping-project/SKILL.md`
- [ ] Read the [scaffold manifest](../framework/skills/bootstrapping-project/references/scaffold-manifest.md)

---

## Hard rules

- Never overwrite an existing file without showing the diff and getting approval.
- Never commit `.env` or secret material even as a placeholder.
- Never invent build commands — derive them from `package.json`, `Makefile`,
  `Cargo.toml`, or equivalent.
- Never skip `docs/architecture/module-map.md` — the agent-protocol
  post-task checklist requires it, so it must exist on day one.
- If the project's primary language or stack is unclear, stop and ask.

## Excluded (never committed)

- `.env`, `.env.local`, `.dev.vars`
- Credentials, tokens, service-account JSON
- `.claude/` or other per-user IDE state

---

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
| Project-scope boundary rules | `.github/copilot-instructions.md` § Boundaries |
| Skill & prompt resolution rule (two-scope) | `.github/copilot-instructions.md` § Skill & prompt resolution |
| Deep procedural knowledge | `.github/copilot/skills/` |
| Workflow templates | `.github/copilot/prompts/` |
| Sync script | `.github/scripts/sync-agents.sh` |
| Everything else (architecture, schemas, runbooks, specs) | `docs/` |

---

## Update walkthrough

`update-project.prompt.md` was retired. Updates are now manual:

1. Read every required path in the existing project.
2. For each missing path, re-run `ai-project` (idempotent — only missing
   files are added; existing files are never overwritten).
3. For each stale path, propose a minimal patch by diffing against the
   template at `<system>/templates/project/<path>`.
4. After source edits, regenerate `AGENTS.md` via `make sync-agents`.
5. Present diff. On approval, apply.

---

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
