# <project-name>

*Last updated: YYYY-MM-DD*

## Purpose
<one-line description>

## Tech Stack
- Language: <language>
- Database: <database>
- Testing: <test framework>

## Codebase Layout
```
src/
  <key directories>
docs/
  architecture/          -- system design
  specs/                 -- active and archived specs
```

## Context Loading
Read in this order before making changes:
1. The active tool's `<system>` instruction file (e.g., `~/.claude/CLAUDE.md`,
   `~/.copilot/AGENTS.md`, `~/.codex/AGENTS.md`) — framework bootstrap.
2. This file (`.github/copilot-instructions.md`) — project rules.
3. `docs/README.md` — documentation index.
4. Project-specific module map or architecture docs.
5. Target code directory.

## Boundaries

Project-scope rules. System-scope boundaries: `<system>/boundaries.md`.

- Never commit `.env` or secrets.
- Follow existing patterns in the target directory.
- Update `*Last updated:*` date on every modified doc.
- Include tests in the same change as feature logic.
- One task at a time, preflight proof, "The Bottom Line" gate.
- "continue" = next single task only.
- Log each discovered process improvement immediately in `docs/improvements-log.md` (do not defer).

<!-- Add project-specific boundary rules below — e.g., per-language conventions,
     architectural constraints, "ask first" items, "never do" items. -->

## Skill & prompt resolution

All three tools (Claude Code, Copilot, Codex) follow the same two-scope
lookup order when resolving a skill or prompt name:

1. **Project scope first** — `.github/copilot/skills/<name>/SKILL.md` and
   `.github/copilot/prompts/<name>.prompt.md`
2. **System scope (fallback)** — `<system>/skills/<name>/SKILL.md` and
   `<system>/prompts/<name>.prompt.md`

Project scope wins on name collision. Since `CLAUDE.md` `@`-imports this
file and `AGENTS.md` is a generated copy of it, the rule applies
identically to all three tools.

## Available skills

System-scope skills are populated under each tool's home directory by
`ai-switch.sh` (rendered from `ai-dotfiles`). Project-scope skills, if any,
live under `.github/copilot/skills/` and override system entries with the
same name.

| Skill | Path | When to use |
|---|---|---|
| `agent-protocol` | `<system>/skills/agent-protocol/SKILL.md` | Context loading, checklists, output conventions |
<!-- Add project-specific skills below, pointing at <project>/.github/copilot/skills/<name>/SKILL.md -->

## Workflows

| User says | Load prompt | Skills |
|---|---|---|
| "create CR", "new feature" | `<system>/prompts/create-spec.prompt.md` | writing-specs, agent-protocol |
| "create IMP", "improve", "refactor" | `<system>/prompts/create-spec.prompt.md` | writing-specs, agent-protocol |
| "bug", "triage" | `<system>/prompts/bug-triage.prompt.md` | writing-specs |
| "plan", "break into tasks" | `<system>/prompts/plan-spec.prompt.md` | writing-specs, model-selection |

## Note for non-Copilot agents

When you read a `.prompt.md` file and see `#skill:<name>`, load the
corresponding skill file: `<system>/skills/<name>/SKILL.md` (or the
project-scope equivalent at `.github/copilot/skills/<name>/SKILL.md` if
it exists — project wins on name collision).

## Build and Run
- `<build command>`
- `<test command>`
